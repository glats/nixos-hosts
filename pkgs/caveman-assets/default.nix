{
  lib,
  stdenvNoCC,
  caveman-src,
}:

stdenvNoCC.mkDerivation {
  pname = "caveman-assets";
  version = caveman-src.rev or "unstable";

  src = caveman-src;

  installPhase = ''
    mkdir -p $out/share/caveman
    [ -d $src/skills ] && mkdir -p $out/share/caveman/skills && cp -r $src/skills/* $out/share/caveman/skills/
    # cavecrew and caveman-explore drive caveman's own subagents, which are not
    # installed; they would steer delegation away from Gentle AI roles.
    chmod -R u+w $out/share/caveman/skills
    rm -rf $out/share/caveman/skills/cavecrew $out/share/caveman/skills/caveman-explore
    [ -d $src/commands ] && mkdir -p $out/share/caveman/commands && cp -r $src/commands/* $out/share/caveman/commands/
  '';

  meta = with lib; {
    description = "Caveman ultra-compressed communication skills and commands";
    homepage = "https://github.com/JuliusBrussee/caveman";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
