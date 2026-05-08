{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation rec {
  pname = "openfang";
  version = "0.6.4";

  src = fetchurl {
    url = "https://github.com/RightNow-AI/openfang/releases/download/v${version}/openfang-x86_64-unknown-linux-gnu.tar.gz";
    sha256 = "sha256-sjEkPosSTgKKOLN8LYysqwYhzxhsBSScm3aiy2zmnfM=";
  };

  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out/bin
    cp openfang $out/bin/
    chmod +x $out/bin/openfang
  '';

  meta = with lib; {
    description = "Local-first AI coding agent with enterprise features";
    homepage = "https://github.com/RightNow-AI/openfang";
    license = licenses.asl20;
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
  };
}
