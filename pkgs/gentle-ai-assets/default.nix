{
  lib,
  stdenvNoCC,
  gentle-ai-src,
  gentle-ai,
  git,
  callPackage,
}:

let
  rendered = callPackage ./render.nix {
    inherit gentle-ai-src;
    vendorHash = gentle-ai.vendorHash;
  };
in
stdenvNoCC.mkDerivation {
  pname = "gentle-ai-assets";
  version = "4.1.1";

  src = gentle-ai-src;

  installPhase = ''
    mkdir -p $out/share/gentle-ai
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

    # Overlay fully rendered runtime prompts, never contributor AGENTS.md or
    # template fragments. The vendored exporter is not shipped as a command.
    chmod -R u+w $out/share/gentle-ai
    cp -r ${rendered}/share/gentle-ai/. $out/share/gentle-ai/
    # The exact tagged V2 relay owns role binding/lifetime/refusal hooks.
    mkdir -p $out/share/gentle-ai/opencode/plugins
    install -m 0644 $src/internal/assets/opencode/plugins-v2/opencode-review-transport.ts \
      $out/share/gentle-ai/opencode/plugins/opencode-review-transport.ts
    install -m 0644 ${./v2-plugins/skill-registry.ts} $out/share/gentle-ai/opencode/plugins/skill-registry.ts
    substituteInPlace $out/share/gentle-ai/opencode/plugins/opencode-review-transport.ts \
      --replace-fail 'Command: "gentle-ai"' 'Command: "${gentle-ai}/bin/gentle-ai"'
  '';

  meta = with lib; {
    description = "Gentle AI configuration assets";
    homepage = "https://github.com/Gentleman-Programming/gentle-ai";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
