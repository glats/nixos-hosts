{ lib, stdenvNoCC, gentle-ai-src }:

stdenvNoCC.mkDerivation {
  pname = "gentle-ai-assets-vanilla";
  version = gentle-ai-src.rev or "unstable";

  src = gentle-ai-src;

  installPhase = ''
    mkdir -p $out/share/gentle-ai

    # Copy AGENTS.md from repository root
    if [ -f $src/AGENTS.md ]; then
      cp $src/AGENTS.md $out/share/gentle-ai/
    fi

    # Copy OpenCode assets (including ALL plugins/)
    if [ -d $src/internal/assets/opencode ]; then
      mkdir -p $out/share/gentle-ai/opencode
      cp -r $src/internal/assets/opencode/* $out/share/gentle-ai/opencode/
    fi

    # Copy skills from internal/assets/skills/
    if [ -d $src/internal/assets/skills ]; then
      mkdir -p $out/share/gentle-ai/skills
      cp -r $src/internal/assets/skills/* $out/share/gentle-ai/skills/
    fi

    # Copy skills from repository root (if any)
    if [ -d $src/skills ]; then
      mkdir -p $out/share/gentle-ai/skills
      cp -r $src/skills/* $out/share/gentle-ai/skills/ 2>/dev/null || true
    fi

    # Copy agent-specific configs (claude, cursor, windsurf, etc.)
    for dir in claude cursor windsurf gemini codex kimi qwen kiro; do
      if [ -d $src/internal/assets/$dir ]; then
        mkdir -p $out/share/gentle-ai/$dir
        cp -r $src/internal/assets/$dir/* $out/share/gentle-ai/$dir/
      fi
    done
  '';

  meta = with lib; {
    description = "Gentle AI configuration assets — pure upstream (vanilla)";
    homepage = "https://github.com/Gentleman-Programming/gentle-ai";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
