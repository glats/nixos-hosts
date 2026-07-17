{ lib
, stdenvNoCC
}:

stdenvNoCC.mkDerivation {
  pname = "local-ai-assets";
  version = "unstable";

  src = ./../../shared/assets/skills;

  dontUnpack = true;

  installPhase = ''
    mkdir -p $out/share/local-ai/skills
    cp -r $src/. $out/share/local-ai/skills/
  '';

  meta = with lib; {
    description = "Locally maintained Gentle AI skills (nix-verify, opencode-session-recovery, git-feature-flow)";
    homepage = "https://github.com/glats/.nixos";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
