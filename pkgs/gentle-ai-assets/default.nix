{
  lib,
  stdenvNoCC,
  gentle-ai-src,
}:

stdenvNoCC.mkDerivation {
  pname = "gentle-ai-assets";
  version = gentle-ai-src.rev or "unstable";

  src = gentle-ai-src;

  installPhase = ''
    mkdir -p $out/share/gentle-ai
    [ -f $src/AGENTS.md ] && cp $src/AGENTS.md $out/share/gentle-ai/
    for dir in opencode skills claude cursor windsurf gemini codex kimi qwen kiro; do
      if [ -d $src/internal/assets/$dir ]; then
        mkdir -p $out/share/gentle-ai/$dir
        cp -r $src/internal/assets/$dir/* $out/share/gentle-ai/$dir/
      fi
    done
    # root-level skills (if any exist alongside internal/assets/skills)
    if [ -d $src/skills ]; then
      mkdir -p $out/share/gentle-ai/skills
      cp -r $src/skills/* $out/share/gentle-ai/skills/ 2>/dev/null || true
    fi
    # Local override: worktree-root fix for the skill-registry startup plugin
    # (pairs with the postPatch in pkgs/gentle-ai). TODO(upstream): drop once
    # gentle-ai-src carries the fix. The cp loop mirrors the read-only store
    # mode (0555) for directories, so grant u+w before replacing the file.
    chmod u+w $out/share/gentle-ai/opencode/plugins
    install -m 0644 ${./skill-registry-worktree-root.ts} $out/share/gentle-ai/opencode/plugins/skill-registry.ts

    # V2 plugins use the pinned native Plugin.define contract. Keep them in a
    # separate tree so V1 assets remain byte-identical.
    mkdir -p $out/share/gentle-ai/opencode-v2/plugins
    for plugin in ${./v2-plugins}/*.ts; do
      install -m 0644 "$plugin" $out/share/gentle-ai/opencode-v2/plugins/
    done
  '';

  meta = with lib; {
    description = "Gentle AI configuration assets";
    homepage = "https://github.com/Gentleman-Programming/gentle-ai";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
