{ lib
, stdenvNoCC
, fetchurl
,
}:

let
  version = "1.15.13";

  system = stdenvNoCC.hostPlatform.system;
  isLinux = lib.hasSuffix "linux" system;
  isDarwin = lib.hasSuffix "darwin" system;

  platformSrc =
    if isLinux then
      {
        url = "https://github.com/Gentleman-Programming/engram/releases/download/v${version}/engram_${version}_linux_amd64.tar.gz";
        sha256 = "sha256-z1gGO+QPVY57c8SOLDI7xcCSr9QdF0XHOn5VN2kbo8A=";
      }
    else if isDarwin then
      {
        url = "https://github.com/Gentleman-Programming/engram/releases/download/v${version}/engram_${version}_darwin_amd64.tar.gz";
        sha256 = "sha256-HbqIC61MUJf01qESy/LdrEaTkdyJNk2NMKGm1/A89o0=";
      }
    else
      throw "Unsupported system: ${system}";
in
stdenvNoCC.mkDerivation {
  pname = "engram";
  inherit version;

  src = fetchurl {
    inherit (platformSrc) url sha256;
  };

  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out/bin
    cp engram $out/bin/
    chmod +x $out/bin/engram
  '';

  meta = with lib; {
    description = "Persistent memory system for AI coding agents";
    homepage = "https://github.com/Gentleman-Programming/engram";
    license = licenses.mit;
    platforms = [
      "x86_64-linux"
      "x86_64-darwin"
    ];
    maintainers = [ ];
  };
}
