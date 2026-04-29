{ lib, stdenv, engram-src }:

stdenv.mkDerivation {
  pname = "engram-assets-vanilla";
  version = engram-src.rev or "unstable";

  src = engram-src;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    mkdir -p $out/share/engram/opencode/plugins

    # Copy the OpenCode plugin from upstream
    if [ -f $src/plugin/opencode/engram.ts ]; then
      cp $src/plugin/opencode/engram.ts $out/share/engram/opencode/plugins/engram.ts
    else
      echo "ERROR: Source file $src/plugin/opencode/engram.ts not found in engram-src"
      echo "Please verify the engram-src input points to a valid repository with the plugin at this path."
      exit 1
    fi
  '';

  meta = with lib; {
    description = "Engram OpenCode plugin — pure upstream (vanilla)";
    homepage = "https://github.com/Gentleman-Programming/engram";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
