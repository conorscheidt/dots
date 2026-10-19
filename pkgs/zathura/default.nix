# GTK3 Zathura matches the macOS tap's verified trackpad/momentum behavior.
# The GTK4 port intercepts scroll events without preserving native momentum
# (pwmt/zathura#888); its generic GTK inertia also differs from AppKit.
{
  lib,
  stdenv,
  writeText,
  callPackage,
  wrapGAppsHook3,
  gtk3,
  gsettings-desktop-schemas,
  file,
}: let
  # Recipes from nixpkgs 35d4d899932bf76482b54888fbaa201cfb093e31,
  # using this flake's current dependencies. Versions match homebrew-zathura.
  girara = callPackage ./gtk3/girara.nix {};
  core = callPackage ./gtk3/core.nix {inherit girara;};
  plugin = callPackage ./gtk3/pdf-mupdf.nix {
    inherit girara;
    zathura_core = core;
  };
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
    nativeBuildInputs = [wrapGAppsHook3];
    buildInputs = [gtk3 gsettings-desktop-schemas];

    installPhase = ''
      runHook preInstall
      contents=$out/Applications/Zathura.app/Contents
      install -Dm755 ${core.bin}/bin/zathura $contents/MacOS/zathura-bin
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
      # Plugin discovery comes from the wrapper, as for other Nix GTK apps.
      makeWrapper $contents/MacOS/zathura-bin $contents/MacOS/zathura \
        "''${gappsWrapperArgs[@]}" \
        --inherit-argv0 \
        --set ZATHURA_PLUGINS_PATH ${plugin}/lib/zathura \
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
