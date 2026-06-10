{
  lib,
  stdenvNoCC,
  vanilla,
  extraSkills ? null,
  extraCommands ? null,
}:

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

    # Overlay local commands on top of vanilla commands
    # extraCommands defaults to null (no local command overrides)
    if ${
      lib.optionalString (extraCommands != null) ''
        for cmd_file in ${extraCommands}/*; do
          cmd_name=$(basename "$cmd_file")
          # Remove existing if present (read-only from vanilla copy)
          rm -f "$TEMP_DIR/opencode/commands/$cmd_name" 2>/dev/null || true
          # Copy new version
          cp "$cmd_file" "$TEMP_DIR/opencode/commands/"
          chmod u+w "$TEMP_DIR/opencode/commands/$cmd_name"
        done
      ''
    } true; then
      :
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
