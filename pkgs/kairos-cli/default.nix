{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "kairos-cli";
  version = "0.65.2";

  src = fetchurl {
    url = "https://entity-api.falabella.ai/api/v1/cli/${finalAttrs.version}/kairos-cli-darwin-arm64";
    hash = "sha256-gCpXy2QuAyAlFJUAbArCEEyE3yDNHY2zLS/wK0RhIBQ=";
  };

  dontUnpack = true;
  dontStrip = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/kairos
    runHook postInstall
  '';

  meta = {
    description = "Falabella Kairos CLI for corporate LLM gateway access";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "kairos";
    platforms = [ "aarch64-darwin" ];
  };
})
