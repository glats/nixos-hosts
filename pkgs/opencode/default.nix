{ lib
, stdenvNoCC
, fetchurl
, unzip
,
}:

stdenvNoCC.mkDerivation rec {
  pname = "opencode";
  version = "1.14.33";

  src = fetchurl {
    url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-darwin-x64.zip";
    hash = "sha256-VsJSsL0gpDDos9OeMXY69xdUDQehSWP7NkIfOr3+f4Y=";
  };

  nativeBuildInputs = [ unzip ];

  sourceRoot = ".";

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp opencode $out/bin/
    chmod +x $out/bin/opencode
    runHook postInstall
  '';

  meta = with lib; {
    description = "AI coding agent TUI";
    homepage = "https://opencode.ai";
    platforms = [ "x86_64-darwin" ];
  };
}
