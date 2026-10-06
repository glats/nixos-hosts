{
  lib,
  stdenvNoCC,
  gentle-ai-src,
  gentle-ai,
  git,
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
    # Drop V1 plugin assets while keeping its command directory, which V2
    # still consumes as a source for commands.
    if [ -d $out/share/gentle-ai/opencode/plugins ]; then
      chmod -R u+w $out/share/gentle-ai/opencode/plugins
      rm -rf $out/share/gentle-ai/opencode/plugins
    fi

    # V2 plugins use the pinned native Plugin.define contract.
    mkdir -p $out/share/gentle-ai/opencode-v2/plugins
    for plugin in ${./v2-plugins}/*.ts; do
      install -m 0644 "$plugin" $out/share/gentle-ai/opencode-v2/plugins/
    done
    substituteInPlace $out/share/gentle-ai/opencode-v2/plugins/opencode-review-transport.ts \
      --replace-fail 'const GO_COMMAND = "gentle-ai"' 'const GO_COMMAND = "${gentle-ai}/bin/gentle-ai"' \
      --replace-fail 'const GIT_BIN = ""' 'const GIT_BIN = "${git}/bin"'
  '';

  meta = with lib; {
    description = "Gentle AI configuration assets";
    homepage = "https://github.com/Gentleman-Programming/gentle-ai";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
