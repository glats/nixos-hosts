{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  zlib,
  stdenv,
}:

let
  version = "1.29.3";

  system = stdenvNoCC.hostPlatform.system;
  isLinux = lib.hasSuffix "linux" system;

  platformSrc =
    {
      x86_64-linux = {
        url = "https://github.com/RivoLink/leaf/releases/download/${version}/leaf-linux-x86_64";
        sha256 = "sha256-QDfL5pokggkhrVbyxDWVxSVj7Ff/zoDpuc9T0uLEDPc=";
      };
      x86_64-darwin = {
        url = "https://github.com/RivoLink/leaf/releases/download/${version}/leaf-macos-x86_64";
        sha256 = "sha256-CZ3qwWBBvMQXTXtRmPXM0bhQX3LvWXr8vJwV+uasIOc=";
      };
      aarch64-darwin = {
        url = "https://github.com/RivoLink/leaf/releases/download/${version}/leaf-macos-arm64";
        sha256 = "sha256-bfffpwqXMVz/ArIMvsPt1PQOohiNAu4ClIISv/Uq4a8=";
      };
    }
    .${system} or (throw "Unsupported system: ${system}");
in
stdenvNoCC.mkDerivation {
  pname = "leaf";
  inherit version;

  src = fetchurl {
    inherit (platformSrc) url sha256;
  };

  dontUnpack = true;

  nativeBuildInputs = lib.optionals isLinux [ autoPatchelfHook ];

  buildInputs = lib.optionals isLinux [
    zlib
    stdenv.cc.cc.lib
  ];

  dontStrip = true;

  installPhase = ''
    mkdir -p $out/bin
    install -m755 $src $out/bin/leaf
  '';

  meta = with lib; {
    description = "Terminal Markdown previewer — GUI-like experience";
    homepage = "https://github.com/RivoLink/leaf";
    license = licenses.mit;
    sourceProvenance = [ binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    mainProgram = "leaf";
  };
}
