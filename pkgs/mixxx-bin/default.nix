{
  lib,
  stdenvNoCC,
  fetchurl,
  undmg,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "mixxx";
  version = "2.5.6";

  src = fetchurl {
    url = "https://downloads.mixxx.org/releases/${finalAttrs.version}/mixxx-${finalAttrs.version}-macosarm.dmg";
    hash = "sha256-9yTNiwBIpglj8RaUrL/7JDionBz3MhF1WawwMfhIbic=";
  };

  nativeBuildInputs = [ undmg ];
  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;
  dontFixup = true; # Preserve the upstream app bundle and code signatures.

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications"
    cp -R Mixxx.app "$out/Applications/"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    /usr/bin/codesign --verify --deep --strict "$out/Applications/Mixxx.app"
    runHook postInstallCheck
  '';

  meta = {
    description = "Digital DJ mixing software";
    homepage = "https://mixxx.org";
    license = lib.licenses.gpl2Plus;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "aarch64-darwin" ];
  };
})
