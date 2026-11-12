{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "dolt";
  version = "2.6.0";

  src = fetchurl {
    url = "https://github.com/dolthub/dolt/releases/download/v${finalAttrs.version}/dolt-linux-amd64.tar.gz";
    hash = "sha256-qNTC4ulLhf01ksuAdIBE+EbM/QPSWlNu0fdUuvfaZAE=";
  };

  sourceRoot = "dolt-linux-amd64";

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 bin/dolt $out/bin/dolt
    runHook postInstall
  '';

  meta = with lib; {
    description = "Dolt SQL database with Git-style versioning (pinned release binary)";
    homepage = "https://github.com/dolthub/dolt";
    license = licenses.asl20;
    mainProgram = "dolt";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
  };
})
