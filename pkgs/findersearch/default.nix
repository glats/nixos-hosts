{
  lib,
  stdenvNoCC,
  fetchurl,
  _7zz,
}:

stdenvNoCC.mkDerivation rec {
  pname = "findersearch";
  version = "0.4.9";

  src = fetchurl {
    url = "https://github.com/zeusinsight/FinderSearch/releases/download/v${version}/FinderSearch-${version}-AppleSilicon.dmg";
    sha256 = "72254ba1d3ffeb7268a67a5b487d33092703903aa4799780a207ff8b6b9b7491";
  };

  nativeBuildInputs = [ _7zz ];
  unpackPhase = ''
    runHook preUnpack
    7zz x -sns- "$src"
    runHook postUnpack
  '';
  dontBuild = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications"
    cp -R FinderSearch.app "$out/Applications/"
    runHook postInstall
  '';

  meta = {
    description = "Native macOS file browser with fuzzy filename search";
    homepage = "https://github.com/zeusinsight/FinderSearch";
    license = lib.licenses.mit;
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
