{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  zlib,
  stdenv,
}:

let
  version = "1.29.2";

  system = stdenvNoCC.hostPlatform.system;
  isLinux = lib.hasSuffix "linux" system;

  platformSrc =
    {
      x86_64-linux = {
        url = "https://github.com/RivoLink/leaf/releases/download/${version}/leaf-linux-x86_64";
        sha256 = "sha256-7jHjmljISAU2hfQwKpTPlC+P02yNL119d72sVEF8bac=";
      };
      x86_64-darwin = {
        url = "https://github.com/RivoLink/leaf/releases/download/${version}/leaf-macos-x86_64";
        sha256 = "sha256-i+GmFBvP71Cnpd+v9BatfpiWrthgsROgU5f3x1b8jb0=";
      };
      aarch64-darwin = {
        url = "https://github.com/RivoLink/leaf/releases/download/${version}/leaf-macos-arm64";
        sha256 = "sha256-lAsPy7V+j6+rDCrooZzubO/t4eYfcqdqLZNVOuUD2Fo=";
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
