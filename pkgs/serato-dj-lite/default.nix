{
  lib,
  stdenvNoCC,
  requireFile,
  xar,
  libarchive,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "serato-dj-lite";
  version = "5.1.0";

  src = requireFile {
    name = "serato-dj-lite-${finalAttrs.version}.pkg";
    hash = "sha256-5u5Lpnr/cFG68a2PRY0ms032KpmSJH/rSDJ/ge/9Q14=";
    url = "https://serato.com/dj/lite/downloads";
    message = ''
      Download Serato DJ Lite ${finalAttrs.version} for macOS from https://serato.com/dj/lite/downloads, then run:
        nix store prefetch-file --name serato-dj-lite-${finalAttrs.version}.pkg "file://$HOME/Downloads/Serato%20DJ%20Lite%20${finalAttrs.version}.pkg"
    '';
  };

  nativeBuildInputs = [
    xar
    libarchive
  ];
  unpackPhase = ''
    runHook preUnpack
    xar -xf "$src"
    bsdtar -xf Component.pkg/Payload
    runHook postUnpack
  '';

  dontPatch = true;
  dontConfigure = true;
  dontBuild = true;
  dontFixup = true; # Preserve the vendor's code signature.

  # Fixed-output, so the store path depends only on this hash: nixpkgs updates
  # never rebuild it, and the installer is needed once per version. Unrooted,
  # the installer itself is soon garbage-collected.
  outputHashMode = "nar";
  outputHash = "sha256-0+cFxq8C1B49jGOgoDowubXmFoC0FBtnHAUqpx1HLss=";

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications"
    mv "Serato DJ Lite.app" "$out/Applications/"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    /usr/bin/codesign --verify --deep --strict "$out/Applications/Serato DJ Lite.app"
  '';

  meta = {
    description = "DJ software for supported controllers";
    homepage = "https://serato.com/dj/lite";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = lib.platforms.darwin;
  };
})
