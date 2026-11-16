{
  config,
  lib,
  pkgs,
  ...
}:
let
  bundleId = "local.viator.mpv";
  appDirectory = "${config.home.homeDirectory}/${config.targets.darwin.copyApps.directory}";
  app = lib.escapeShellArg "${appDirectory}/mpv.app";
  lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister";
  duti = lib.getExe pkgs.duti;

  # The local OSC replaces uosc's visible elements.
  uosc = pkgs.mpvScripts.uosc.overrideAttrs (prev: {
    patches = [ ./uosc-fork.patch ];
    # Its fonts go into ~~/fonts instead: font directories would make the
    # wrapper switch the OSD from CoreText to a private fontconfig.
    passthru = prev.passthru // {
      fontDirectories = [ ];
    };
  });

  thumbfast = pkgs.mpvScripts.thumbfast.overrideAttrs {
    patches = [ ./thumbfast-dovi.patch ];
  };

  # LaunchServices also sees the unwrapped store app. Give the Finder app its
  # own ID so document associations always select the wrapper with scripts.
  mpv =
    (pkgs.mpv.override {
      scripts = [
        uosc
        thumbfast
        pkgs.mpvScripts.autoload
      ];
    }).overrideAttrs
      (old: {
        buildCommand = old.buildCommand + ''
          bundle="$out/Applications/mpv.app"
          cp -RL "$bundle" "$TMPDIR/mpv.app"
          chmod -R u+w "$TMPDIR/mpv.app"
          find "$TMPDIR/mpv.app/Contents/MacOS" -name .gitkeep -delete
          /usr/bin/plutil -replace CFBundleIdentifier -string ${bundleId} "$TMPDIR/mpv.app/Contents/Info.plist"
          /usr/bin/codesign --force --sign - "$TMPDIR/mpv.app"
          rm -r "$bundle"
          mv "$TMPDIR/mpv.app" "$bundle"
        '';
      });

  phosphor = pkgs.fetchzip {
    url = "https://registry.npmjs.org/@phosphor-icons/web/-/web-2.1.2.tgz";
    hash = "sha256-iaNtM6lLYY3Shtbk712DWqayGIi/iofoASCysZqm3Kc=";
  };

  # Copied so the 44 MiB icon package stays out of the closure.
  fonts = pkgs.runCommand "mpv-fonts" { } ''
    install -Dm644 -t "$out" ${phosphor}/src/{regular,bold,fill}/*.ttf ${uosc}/share/fonts/*/*
  '';

  shaders = pkgs.symlinkJoin {
    name = "mpv-shaders";
    paths = [
      pkgs.anime4k
      ./shaders
      (pkgs.linkFarm "mpv-upstream-shaders" {
        "ravu-zoom-ar-r3.hook" = pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/bjin/mpv-prescalers/3f24e7c53085854d122bb5d6629d1d503ba29e35/ravu-zoom-ar-r3.hook";
          hash = "sha256-6ww3RK82FcmSgab/dNEnalzHUnowoL1UmErrQ9DLLuo=";
        };
        "CfL_Prediction.glsl" = pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/Artoriuz/glsl-chroma-from-luma-prediction/066dff964b83aa34e893de25d590874bf8c8e94f/CfL_Prediction.glsl";
          hash = "sha256-+dEtONS6tNnbJmtZgsgfrcqQc5YhLiL9iywcovMXtxY=";
        };
      })
    ];
  };
in
{
  programs.mpv = {
    enable = true;
    package = mpv;
  };

  home.activation.mpvFileAssociations = lib.hm.dag.entryAfter [ "copyApps" ] ''
    run ${lsregister} -f ${app}
    for ext in mkv mp4 m4v mov webm avi; do
      if [[ "$(${duti} -x "$ext" 2>/dev/null | /usr/bin/sed -n 2p)" != ${app} ]]; then
        run ${duti} -s ${bundleId} ".$ext" all
      fi
    done
  '';

  # Directories are linked whole, so nothing unmanaged loads from them.
  # user.conf (OpenSubtitles credentials) and playback state stay mutable.
  xdg.configFile = {
    "mpv/mpv.conf".source = ./mpv.conf;
    "mpv/input.conf".source = ./input.conf;
    "mpv/script-opts".source = ./script-opts;
    "mpv/scripts".source = ./scripts;
    "mpv/lib".source = ./lib;
    "mpv/fonts".source = fonts;
    "mpv/shaders".source = shaders;
  };
}
