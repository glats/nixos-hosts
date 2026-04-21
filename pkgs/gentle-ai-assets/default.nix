{ lib, stdenvNoCC, gentle-ai-src }:

stdenvNoCC.mkDerivation {
  pname = "gentle-ai-assets";
  version = gentle-ai-src.rev or "unstable";

  src = gentle-ai-src;

  installPhase = ''
    mkdir -p $out/share/gentle-ai

    # Copiar AGENTS.md principal
    if [ -f $src/AGENTS.md ]; then
      cp $src/AGENTS.md $out/share/gentle-ai/
    fi

    # Copiar assets embebidos de OpenCode
    if [ -d $src/internal/assets/opencode ]; then
      mkdir -p $out/share/gentle-ai/opencode
      cp -r $src/internal/assets/opencode/* $out/share/gentle-ai/opencode/
    fi

    # Copiar skills
    if [ -d $src/internal/assets/skills ]; then
      mkdir -p $out/share/gentle-ai/skills
      cp -r $src/internal/assets/skills/* $out/share/gentle-ai/skills/
    fi

    # Copiar configuraciones para otros agentes (opcional)
    for dir in claude cursor windsurf gemini codex kimi qwen kiro; do
      if [ -d $src/internal/assets/$dir ]; then
        mkdir -p $out/share/gentle-ai/$dir
        cp -r $src/internal/assets/$dir/* $out/share/gentle-ai/$dir/
      fi
    done

    # Copiar skills de la raíz (los nuevos/agregados por usuarios)
    if [ -d $src/skills ]; then
      cp -r $src/skills/* $out/share/gentle-ai/skills/ 2>/dev/null || true
    fi
  '';

  meta = with lib; {
    description = "Gentle AI configuration assets for various AI coding agents";
    homepage = "https://github.com/Gentleman-Programming/gentle-ai";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
