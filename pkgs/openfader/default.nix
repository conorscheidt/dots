{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "openfader";
  version = "0.2.12";

  src = fetchurl {
    url = "https://github.com/OpenRsG/OpenFadeR/releases/download/v${finalAttrs.version}/OpenFadeR-${finalAttrs.version}-macos-arm64.zip";
    hash = "sha256-yWHm5xVLuUTmKhT9Mfx1gEA5ApVQ4caU3cwrzdQVqFM=";
  };

  nativeBuildInputs = [ unzip ];
  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications"
    cp -R OpenFadeR.app "$out/Applications/"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    /usr/bin/codesign --verify --deep --strict "$out/Applications/OpenFadeR.app"
    runHook postInstallCheck
  '';

  meta = {
    description = "DJ software written in Rust with a Slint interface";
    homepage = "https://github.com/OpenRsG/OpenFadeR";
    license = lib.licenses.agpl3Only;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "aarch64-darwin" ];
  };
})
