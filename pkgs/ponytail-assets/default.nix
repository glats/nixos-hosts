{ lib
, stdenvNoCC
, ponytail-src
,
}:

stdenvNoCC.mkDerivation {
  pname = "ponytail-assets";
  version = ponytail-src.rev or "unstable";

  src = ponytail-src;

  installPhase = ''
    mkdir -p $out/share/ponytail
    [ -d $src/skills ] && mkdir -p $out/share/ponytail/skills && cp -r $src/skills/* $out/share/ponytail/skills/
    [ -d $src/.opencode/command ] && mkdir -p $out/share/ponytail/commands && cp -r $src/.opencode/command/* $out/share/ponytail/commands/
  '';

  meta = with lib; {
    description = "Ponytail YAGNI enforcement skills and commands";
    homepage = "https://github.com/DietrichGebert/ponytail";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
