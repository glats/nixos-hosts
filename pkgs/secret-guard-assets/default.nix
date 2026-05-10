{ lib, stdenvNoCC, writeText }:

stdenvNoCC.mkDerivation {
  pname = "secret-guard-assets";
  version = "1.0.0";

  dontUnpack = true;

  buildPhase = ''
    echo "Building secret-guard assets..."
  '';

  installPhase = ''
    mkdir -p $out/share/secret-guard/opencode/plugins
    cp ${./share/secret-guard/opencode/plugins/secret-guard.ts} $out/share/secret-guard/opencode/plugins/secret-guard.ts
    chmod u+w $out/share/secret-guard/opencode/plugins/secret-guard.ts
  '';

  meta = with lib; {
    description = "Secret Guard OpenCode plugin for preventing secret exposure";
    platforms = platforms.all;
  };
}
