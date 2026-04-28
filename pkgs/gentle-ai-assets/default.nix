{ lib, stdenvNoCC, writeText, vanilla, extraSkills ? null }:

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
  version = vanilla.version or "unstable";

  # No src needed — we build on top of vanilla
  dontUnpack = true;

  buildPhase = ''
    echo "Layering gentle-ai assets on top of vanilla..."
  '';

  installPhase = ''
    # Work in a temp directory to avoid permission issues
    TEMP_DIR=$(mktemp -d)
    chmod 755 "$TEMP_DIR"

    # Copy vanilla's CONTENTS (share/gentle-ai/*) to temp
    for item in ${vanilla}/share/gentle-ai/*; do
      # Copy and make writable
      cp -r "$item" "$TEMP_DIR/"
      chmod -R u+w "$TEMP_DIR/$(basename "$item")"
    done

    # Prepend local persona rules to persona-gentleman.md
    if [ -f "$TEMP_DIR/opencode/persona-gentleman.md" ]; then
      cat ${localPersonaRules} "$TEMP_DIR/opencode/persona-gentleman.md" > "$TEMP_DIR/opencode/persona-gentleman.md.new"
      mv "$TEMP_DIR/opencode/persona-gentleman.md.new" "$TEMP_DIR/opencode/persona-gentleman.md"
    fi

    # Overlay local skills on top of vanilla skills
    if [ -n "${extraSkills}" ] && [ -d "${extraSkills}" ]; then
      for skill_dir in ${extraSkills}/*; do
        skill_name=$(basename "$skill_dir")
        # Remove existing if present (read-only from vanilla copy)
        rm -rf "$TEMP_DIR/skills/$skill_name" 2>/dev/null || true
        # Copy new version
        cp -r "$skill_dir" "$TEMP_DIR/skills/"
        chmod -R u+w "$TEMP_DIR/skills/$skill_name"
      done
    fi

    # Move to final destination
    mkdir -p $out/share/gentle-ai
    cp -r "$TEMP_DIR/"* $out/share/gentle-ai/

    rm -rf "$TEMP_DIR"
  '';

  meta = with lib; {
    description = "Gentle AI configuration assets with local rule overrides";
    homepage = "https://github.com/Gentleman-Programming/gentle-ai";
    license = licenses.mit;
    platforms = platforms.all;
  };
}