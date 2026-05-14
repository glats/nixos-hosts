{ lib, stdenvNoCC, fetchurl }:

stdenvNoCC.mkDerivation rec {
  pname = "engram";
  version = "1.15.11";

  src = fetchurl {
    url = "https://github.com/Gentleman-Programming/engram/releases/download/v${version}/engram_${version}_linux_amd64.tar.gz";
    sha256 = "sha256-4dfBL0t6ULArhY1qxHqkCT6wh6UaM+9IBcbawI/9Zk0=";
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
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
  };
}
