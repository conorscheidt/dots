# Zathura (GTK4, MuPDF backend) as a native macOS app bundle. The real Mach-O
# lives inside Zathura.app so the Dock, menu bar and LaunchServices see one
# app; Finder "open" Apple Events reach it through GTK's application:openFiles:.
{
  lib,
  stdenv,
  writeText,
  zathuraPkgs,
  wrapGAppsHook4,
  gtk4,
  gsettings-desktop-schemas,
  file,
}: let
  scope = zathuraPkgs.overrideScope (_: prev: {
    zathura_core = prev.zathura_core.overrideAttrs (finalAttrs: old: {
      # NixOS/nixpkgs#574439 (fix pending in #568046): meson's
      # auto_features=enabled turns the X11/Wayland test suites into hard
      # requirements on darwin, where their xvfb-run/weston inputs are absent.
      mesonFlags =
        old.mesonFlags
        ++ [
          (lib.mesonEnable "tests-x11" finalAttrs.doCheck)
          (lib.mesonEnable "tests-wayland" finalAttrs.doCheck)
        ];
      # One document per process: a second Finder open spawns a new instance
      # instead of failing silently in the running one.
      patches = (old.patches or []) ++ [./darwin-open-in-new-instance.patch];
    });
  });
  core = scope.zathura_core;
  infoPlist = writeText "Info.plist" (lib.generators.toPlist {escape = true;} {
    CFBundleDevelopmentRegion = "en";
    CFBundleDisplayName = "Zathura";
    CFBundleExecutable = "zathura";
    CFBundleIconFile = "AppIcon";
    CFBundleIdentifier = "com.pwmt.zathura";
    CFBundleInfoDictionaryVersion = "6.0";
    CFBundleName = "Zathura";
    CFBundlePackageType = "APPL";
    CFBundleShortVersionString = core.version;
    CFBundleVersion = core.version;
    LSApplicationCategoryType = "public.app-category.productivity";
    LSMinimumSystemVersion = "13.0";
    NSHighResolutionCapable = true;
    CFBundleDocumentTypes = [
      {
        CFBundleTypeName = "PDF Document";
        CFBundleTypeRole = "Viewer";
        CFBundleTypeIconFile = "AppIcon";
        LSHandlerRank = "Owner";
        LSItemContentTypes = ["com.adobe.pdf"];
      }
    ];
  });
in
  stdenv.mkDerivation {
    pname = "zathura-app";
    inherit (core) version;
    dontUnpack = true;
    dontWrapGApps = true; # wrapped by hand below, inside the bundle
    nativeBuildInputs = [wrapGAppsHook4];
    buildInputs = [gtk4 gsettings-desktop-schemas];
    env.GDK_PIXBUF_MODULE_FILE = core.env.GDK_PIXBUF_MODULE_FILE;

    installPhase = ''
      runHook preInstall
      contents=$out/Applications/Zathura.app/Contents
      install -Dm755 ${core.bin}/bin/.zathura-wrapped $contents/MacOS/zathura-bin
      install -Dm644 ${infoPlist} $contents/Info.plist
      install -Dm644 ${./AppIcon.icns} $contents/Resources/AppIcon.icns
      printf 'APPL????' > $contents/PkgInfo
      mkdir -p $out/bin $out/share
      ln -s ${core.man}/share/man $out/share/man
      for d in fish zsh bash-completion locale; do
        if [ -e ${core}/share/$d ]; then ln -s ${core}/share/$d $out/share/$d; fi
      done
      runHook postInstall
    '';

    postFixup = ''
      contents=$out/Applications/Zathura.app/Contents
      # --inherit-argv0: the open-in-new-instance patch re-executes argv[0].
      makeWrapper $contents/MacOS/zathura-bin $contents/MacOS/zathura \
        "''${gappsWrapperArgs[@]}" \
        --inherit-argv0 \
        --set ZATHURA_PLUGINS_PATH ${scope.zathura_pdf_mupdf}/lib/zathura \
        --prefix PATH : ${lib.makeBinPath [file]}
      ln -s $contents/MacOS/zathura $out/bin/zathura
    '';

    meta = {
      inherit (core.meta) homepage license;
      description = "Zathura PDF reader as a native macOS app";
      platforms = lib.platforms.darwin;
      mainProgram = "zathura";
    };
  }
