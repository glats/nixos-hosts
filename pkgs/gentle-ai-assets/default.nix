{ lib, stdenvNoCC, gentle-ai-src, writeText, extraSkills ? null }:

let
  # Nuestras reglas locales que se agregarán al principio
  localPersonaRules = writeText "local-persona-rules" ''
## Global Rules (ALWAYS FOLLOW)

### Code Language Policy - ENGLISH ONLY

**All code must ALWAYS be in English. NO EXCEPTIONS.**

- Variable names: englishOnly
- Function names: useEnglishCamelCase()
- Class names: EnglishPascalCase
- Comments: // Always in English
- Documentation: Written in English
- Commit messages: english format (feat:, fix:, docs:)
- Log messages: English text
- Error strings: "Error message in English"
- Configuration descriptions: English descriptions
- File names: use-english-names.md
- ANY text inside code: ENGLISH

**NO SPANISH IN CODE.**
**NO MIXED LANGUAGES.**
**NO EMOJIS IN CODE OR OUTPUT.**

Even if user writes "crear función", output: `function createUser()` not `function crearUsuario()`.

### No Emojis Policy

**NEVER use emojis.** This includes:
- No emojis in code
- No emojis in output
- No emojis in documentation
- No emojis in comments
- No emojis in file names
- No emojis in commit messages
- No emojis in responses to user

Use text indicators only: "WARNING:", "INFO:", "ERROR:", "SUCCESS:", not ⚠️ 🔥 ❌ ✅

---

'';
in

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

    # Copiar assets embebidos de OpenCode (excepto PERSONA.md que se combina después)
    if [ -d $src/internal/assets/opencode ]; then
      mkdir -p $out/share/gentle-ai/opencode
      # Copiar todo excepto persona-gentleman.md
      for file in $src/internal/assets/opencode/*; do
        if [ "$(basename "$file")" != "persona-gentleman.md" ]; then
          cp -r "$file" $out/share/gentle-ai/opencode/
        fi
      done
    fi

    # Combinar PERSONA.md: reglas locales + upstream
    mkdir -p $out/share/gentle-ai/opencode
    if [ -f $src/internal/assets/opencode/persona-gentleman.md ]; then
      # Prependear reglas locales al PERSONA.md del upstream
      cat ${localPersonaRules} $src/internal/assets/opencode/persona-gentleman.md > $out/share/gentle-ai/opencode/persona-gentleman.md
    else
      # Si no existe upstream, usar solo reglas locales
      cp ${localPersonaRules} $out/share/gentle-ai/opencode/persona-gentleman.md
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

    # Copiar skills extra locales (ej: caveman)
    if [ -n "${extraSkills}" ] && [ -d ${extraSkills} ]; then
      mkdir -p $out/share/gentle-ai/skills
      cp -r ${extraSkills}/* $out/share/gentle-ai/skills/ 2>/dev/null || true
    fi
  '';

  meta = with lib; {
    description = "Gentle AI configuration assets for various AI coding agents (with local rule overrides)";
    homepage = "https://github.com/Gentleman-Programming/gentle-ai";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
