# Copy app bundles out of the store so Spotlight and Raycast can index them.
{
  config,
  lib,
  pkgs,
  ...
}: let
  lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister";
  duti = lib.getExe pkgs.duti;

  # The pinned nixpkgs has 2.0; keep the tested release until it catches up.
  instantSpaceSwitcher = pkgs.instant-space-switcher.overrideAttrs {
    version = "3.1";
    src = pkgs.fetchurl {
      url = "https://github.com/jurplel/InstantSpaceSwitcher/releases/download/v3.1/InstantSpaceSwitcher-3.1.dmg";
      hash = "sha256-rsy241SZcA1Ot/cdfRKwrFnRtCfLMV8nW6HfA9nJ5eo=";
    };
  };
  instantSpaceSwitcherBundle = "${config.home.homeDirectory}/${config.targets.darwin.copyApps.directory}/InstantSpaceSwitcher.app";

  # Mirror profile apps separately; only this directory is pruned by rsync.
  syncProfileApps = pkgs.writeShellScript "sync-nix-profile-apps" ''
    set -eu
    src="$HOME/.nix-profile/Applications"
    dst="$HOME/Applications/Nix Profile Apps"
    if [ ! -d "$src" ]; then
      src=$(mktemp -d)
      trap 'rmdir "$src"' EXIT
    fi
    mkdir -p "$dst"
    ${lib.getExe pkgs.rsync} --recursive --checksum --perms --links \
      --copy-unsafe-links --specials --delete --chmod=+w "$src/" "$dst/"
    ${lsregister} -R -f "$dst"
  '';
in {
  home.packages = with pkgs; [
    slack
    betterdisplay
    qbittorrent
    mpv # configuration stays user-owned in ~/.config/mpv (its scripts write state there)
    instantSpaceSwitcher
    (callPackage ../../pkgs/serato-dj-lite {})
  ];

  targets.darwin.defaults."com.interversehq.InstantSpaceSwitcher" = {
    gestureSpeed = 2000; # Instant
    swipeOverride = true;
  };

  # Install the app and preferences before starting graphical login agents.
  home.activation.setupLaunchAgents = lib.hm.dag.entryAfter ["copyApps" "setDarwinDefaults"] (lib.mkDefault "");

  # LaunchServices opens the stable copied bundle and preserves its app identity.
  # Leave the app's own "Launch at login" off; Home Manager owns startup.
  launchd.agents.instant-space-switcher = {
    enable = true;
    config = {
      ProgramArguments = ["/usr/bin/open" "-g" "-a" instantSpaceSwitcherBundle];
      RunAtLoad = true;
    };
  };

  # Make LaunchServices see the freshly copied bundles, then claim video files
  # for mpv (only when another app currently owns them).
  home.activation.defaultApps = lib.hm.dag.entryAfter ["copyApps"] ''
    run ${lsregister} -R -f ${lib.escapeShellArg "${config.home.homeDirectory}/${config.targets.darwin.copyApps.directory}"}
    for ext in mkv mp4 m4v mov webm avi; do
      if [[ "$(${duti} -x "$ext" 2>/dev/null | /usr/bin/sed -n 3p)" != io.mpv ]]; then
        run ${duti} -s io.mpv ".$ext" all
      fi
    done
  '';

  launchd.agents.nix-profile-apps = {
    enable = true;
    config = {
      ProgramArguments = ["${syncProfileApps}"];
      WatchPaths = ["${config.xdg.stateHome}/nix/profiles" "${config.home.homeDirectory}/.nix-profile"];
      RunAtLoad = true;
      ThrottleInterval = 5;
    };
  };
}
