{
  lib,
  stdenv,
  engram-src,
}:

stdenv.mkDerivation {
  pname = "engram-assets-vanilla";
  version = engram-src.rev or "unstable";

  src = engram-src;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    mkdir -p $out/share/engram/opencode-v2/plugins
    install -m 0644 ${./engram-v2.ts} $out/share/engram/opencode-v2/plugins/engram.ts
  '';

  meta = with lib; {
    description = "Engram OpenCode V2 plugin assets — pure upstream (vanilla)";
    homepage = "https://github.com/Gentleman-Programming/engram";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
