# GUI apps from Nix. Home Manager copies home.packages apps into
# ~/Applications/Home Manager Apps (targets.darwin.copyApps), so Spotlight and
# Raycast index real bundles and nothing is ever launched from /nix/store.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  c = import ../theme.nix;
  hex = lib.removePrefix "#";
  spice = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister";
  duti = lib.getExe pkgs.duti;

  # Same treatment for apps added imperatively with `nix profile add`: mirror
  # ~/.nix-profile/Applications into a directory this script owns exclusively,
  # so additions, upgrades, rollbacks and removals all show up in launchers.
  syncProfileApps = pkgs.writeShellScript "sync-nix-profile-apps" ''
    src="$HOME/.nix-profile/Applications"
    dst="$HOME/Applications/Nix Profile Apps"
    [ -d "$src" ] || src=$(mktemp -d)
    mkdir -p "$dst"
    ${lib.getExe pkgs.rsync} --recursive --checksum --perms --links \
      --copy-unsafe-links --specials --delete --chmod=+w "$src/" "$dst/"
    ${lsregister} -R -f "$dst"
  '';
in {
  imports = [inputs.spicetify-nix.homeManagerModules.spicetify];

  home.packages = with pkgs; [
    slack
    betterdisplay
    qbittorrent
    mpv # configuration stays user-owned in ~/.config/mpv (its scripts write state there)
  ];

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
      WatchPaths = ["/Users/conor/.local/state/nix/profiles"];
      RunAtLoad = true;
      ThrottleInterval = 5;
    };
  };

  programs.spicetify = {
    enable = true;
    theme = spice.themes.dribbblish;
    colorScheme = "custom";
    customColorScheme = {
      text = hex c.fg;
      subtext = hex c.grey2;
      main = hex c.bg0;
      sidebar = hex c.bg1;
      player = hex c.bg0;
      card = hex c.bg1;
      shadow = hex c.bg_dim;
      selected-row = hex c.bg3;
      button = hex c.orange;
      button-active = hex c.aqua;
      button-disabled = hex c.grey0;
      tab-active = hex c.bg3;
      notification = hex c.bg3;
      notification-error = hex c.red;
      misc = hex c.grey1;
    };
    enabledExtensions = with spice.extensions; [
      adblockify
      hidePodcasts
      shuffle
      keyboardShortcut
      fullAppDisplay
    ];
  };
}
