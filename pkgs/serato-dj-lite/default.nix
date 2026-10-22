{
  lib,
  stdenvNoCC,
  requireFile,
  xar,
  libarchive,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "serato-dj-lite";
  version = "5.0.0";

  src = requireFile {
    name = "serato-dj-lite-${finalAttrs.version}.pkg";
    hash = "sha256-mdaHYD6G2taLiixkIEm529OjOBp4GT3EkomChs7hWKw=";
    url = "https://serato.com/dj/lite/downloads";
    message = ''
      Download Serato DJ Lite ${finalAttrs.version} for macOS from https://serato.com/dj/lite/downloads, then run:
        nix store prefetch-file --name serato-dj-lite-${finalAttrs.version}.pkg "file://$HOME/Downloads/Serato%20DJ%20Lite%20${finalAttrs.version}.pkg"
    '';
  };

  nativeBuildInputs = [xar libarchive];
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
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    platforms = lib.platforms.darwin;
  };
})
