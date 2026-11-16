{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  c = import ../theme.nix;
  lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister";
  duti = lib.getExe pkgs.duti;
  appDirectory = "${config.home.homeDirectory}/${config.targets.darwin.copyApps.directory}";
  instantSpaceSwitcherBundle = "${appDirectory}/InstantSpaceSwitcher.app";
  # "#rrggbb" -> [r g b] in 0..1, the form Skim's colour defaults accept.
  rgb =
    hex:
    map (i: lib.fromHexString (builtins.substring i 2 hex) / 255.0) [
      1
      3
      5
    ];
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};

  # Spotify 1.3.9 dropped its per-binary entitlements and relies on every
  # binary sharing its Team ID. An ad-hoc signature has none, so the hardened
  # runtime refuses to load the CEF framework unless library validation is off.
  spotifyEntitlements = pkgs.writeText "spotify-entitlements.plist" (
    lib.generators.toPlist { escape = true; } {
      "com.apple.security.cs.allow-jit" = true;
      "com.apple.security.cs.allow-unsigned-executable-memory" = true;
      "com.apple.security.cs.disable-library-validation" = true;
    }
  );
  spotifyHelpers = map (kind: "Contents/Frameworks/Spotify Helper${kind}.app") [
    ""
    " (GPU)"
    " (Plugin)"
    " (Renderer)"
  ];

  spotify =
    (pkgs.spotify-spotx.override {
      # nixpkgs' older Darwin package uses an unavailable archive snapshot.
      # SpotX-Bash supports the current vendor release.
      spotify =
        if lib.versionAtLeast pkgs.spotify.version "1.3.9.2055" then
          pkgs.spotify
        else
          pkgs.spotify.overrideAttrs {
            version = "1.3.9.2055";
            src = pkgs.fetchurl {
              url = "https://download.scdn.co/SpotifyARM64.dmg";
              hash = "sha256-jI7EwpwtN/bS+i2NrVBuAsZR+/Vu8mw0/hvv21FEZ+0=";
            };
          };
      spotxArgs = [ "--blockupdates" ];
    }).overrideAttrs
      (old: {
        postFixup = old.postFixup + ''
          ${lib.getExe pkgs.rcodesign} sign \
            --entitlements-xml-file ${spotifyEntitlements} \
            ${
              lib.concatMapStringsSep " " (
                helper: "--entitlements-xml-file ${lib.escapeShellArg "${helper}:${spotifyEntitlements}"}"
              ) spotifyHelpers
            } \
            "$out/Applications/Spotify.app"
        '';
      });
in
{
  imports = [ inputs.spicetify-nix.homeManagerModules.spicetify ];

  home.packages = [
    pkgs.qbittorrent
    pkgs.mixxx-bin
    pkgs.openfader
    pkgs.serato-dj-lite
    # DJ library tooling: Soulseek batch fetch, transcode checks, tagging, key detection
    pkgs.slsk-batchdl
    pkgs.spek
    pkgs.sox
    pkgs.flac
    pkgs.mp3val
    pkgs.ffmpeg
    pkgs.keyfinder-cli
    pkgs.instant-space-switcher
    # Every PDF, LaTeX included (VimTeX drives it; see nvim/latex.nix).
    pkgs.skimpdf
  ];

  # Spotify's download URL is unversioned, so the pinned DMG cannot be fetched
  # again once Spotify ships a release. Keeping it in the closure lets nixpkgs
  # updates rebuild the app without a version bump.
  home.extraDependencies = [ spotify.src ];

  # Spicetify patches the SpotX build in postInstall; SpotX's postFixup then
  # re-signs the bundle, so both patches stay sealed.
  programs.spicetify = {
    enable = true;
    spotifyPackage = spotify;
    theme = spicePkgs.themes.default;
    customColorScheme = lib.mapAttrs (_: lib.removePrefix "#") {
      text = c.fg;
      subtext = c.grey2;
      main = c.bg0;
      sidebar = c.bg_dim;
      player = c.bg_dim;
      card = c.bg1;
      shadow = c.bg_dim;
      selected-row = c.fg;
      button = c.orange;
      button-active = c.orange;
      button-disabled = c.bg5;
      tab-active = c.bg3;
      notification = c.bg3;
      notification-error = c.red;
      misc = c.grey0;
    };
    enabledExtensions = with spicePkgs.extensions; [
      shuffle # Fisher-Yates instead of Spotify's weighted shuffle
      keyboardShortcut # vim-style j/k, g/G and link hints
      hidePodcasts
      fullAppDisplay
    ];
  };

  targets.darwin.defaults."net.sourceforge.skim-app.skim" = {
    # Nix updates the bundle; Sparkle must not.
    SUEnableAutomaticChecks = false;
    SUAutomaticallyUpdate = false;
    SKLastVersionLaunched = "9999"; # no release-notes window after each bump
    # Reload any PDF rewritten on disk (build scripts, agents, terminal
    # latexmk); Skim waits for %%EOF, so half-written files never load.
    # VimTeX still reverts after each compile: a second read of the same
    # file that keeps the position. Reload is read when a document opens.
    SKAutoCheckFileUpdate = true;
    SKAutoReloadFileUpdate = true;
    # Pages show as printed. Dark-mode inversion is app-wide (it would tint
    # LaTeX output too) and forces #ffffff text, so only the frame is themed.
    SKInvertColorsInDarkMode = false;
    SKDarkBackgroundColor = rgb c.bg0; # around the pages, tiles included
    SKInterpolationQuality = 2; # smooth scaled images (default: none)
    # The right half of the built-in display, beside Ghostty's window (see
    # terminal.nix). Skim rewrites it when its window moves.
    "NSWindow Frame SKMainWindow" = "758 0 754 950 0 0 1512 950 ";
    # New PDFs open as tabs, so a second document stays in that half.
    AppleWindowTabbingMode = "always";
    SKLeftSidePaneWidth = 0.0;
    SKRightSidePaneWidth = 0.0;
    SKOpenContentsPaneOnlyForTOC = false;
    SKShowStatusBar = false;
    SKRememberLastPageViewed = true;
    SKMaximumDocumentPageHistoryCount = 200; # documents whose page is kept; default 50
    SKNeverChangeZoomFromLinks = true;
    SKDefaultPDFDisplaySettings = {
      autoScales = true;
      scaleFactor = 1.0;
      displayMode = 1; # single page, continuous
      displayDirection = 0;
      displaysAsBook = false;
      displaysPageBreaks = true;
      displaysRTL = false;
      displayBox = 1; # crop box
    };
  };

  targets.darwin.defaults."com.interversehq.InstantSpaceSwitcher" = {
    gestureSpeed = 2000;
    hideMenuBarIcon = true;
    swipeOverride = true;
  };

  home.activation.setupLaunchAgents = lib.hm.dag.entryAfter [ "copyApps" "setDarwinDefaults" ] (
    lib.mkDefault ""
  );

  home.activation.defaultApps = lib.hm.dag.entryAfter [ "copyApps" ] ''
    run ${lsregister} -R -f ${lib.escapeShellArg appDirectory}
    # macOS asks once to confirm a new default browser.
    if [[ "$(${duti} -d https 2>/dev/null)" != com.brave.Browser ]]; then
      run ${duti} -s com.brave.Browser http
      run ${duti} -s com.brave.Browser https
      run ${duti} -s com.brave.Browser public.html all
    fi
    # Skim claims PDF only at Alternate rank, so Preview would keep it.
    if [[ "$(${duti} -x pdf 2>/dev/null | /usr/bin/sed -n 3p)" != net.sourceforge.skim-app.skim ]]; then
      run ${duti} -s net.sourceforge.skim-app.skim com.adobe.pdf all
    fi
  '';

  # Spotify's cache has no limit of its own (it had reached 7 GB) and no
  # setting in the app; this prefs key, in MB, is the only switch. Spotify
  # rewrites the file on exit, so a change made while it runs lands next switch.
  home.activation.spotifyCacheLimit = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    prefs="$HOME/Library/Application Support/Spotify/prefs"
    if [[ -f "$prefs" ]] && ! /usr/bin/grep -qxF 'storage.size=1024' "$prefs"; then
      run /usr/bin/sed -i "" -e '/^storage\.size=/d' -e '$a\
    storage.size=1024' "$prefs"
    fi
  '';

  launchd.agents.instant-space-switcher = {
    enable = true;
    config = {
      ProgramArguments = [
        "/usr/bin/open"
        "-g"
        "-a"
        instantSpaceSwitcherBundle
      ];
      RunAtLoad = true;
    };
  };
}
