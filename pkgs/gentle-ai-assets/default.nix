{ lib
, stdenvNoCC
, vanilla
, extraCommands ? null
, extraAssets ? null
, extraAssetsShared ? null
,
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

    # Local skills are now handled by extraAssetsShared (shared/assets/skills/).
    # The extraAssetsShared cp -r at the bottom of this install phase places
    # them into TEMP_DIR/skills/ alongside the vanilla skills.

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

    # Overlay local extra assets (arbitrary file overrides at any depth).
    # extraAssets directory structure MUST mirror $out/share/gentle-ai/ —
    # any file path present in extraAssets overwrites the vanilla copy.
    if ${
      lib.optionalString (extraAssets != null) ''
        if [ -d "${extraAssets}" ]; then
          cp -r ${extraAssets}/. $TEMP_DIR/
        fi
      ''
    } true; then
      :
    fi

    # Layer tool-agnostic shared assets on top.
    # Same mechanism as extraAssets but from a tool-neutral directory.
    # Uses explicit loop with chmod to handle read-only vanilla files.
    if ${
      lib.optionalString (extraAssetsShared != null) ''
        if [ -d "${extraAssetsShared}" ]; then
          for item in ${extraAssetsShared}/*; do
            item_name=$(basename "$item")
            if [ -d "$item" ]; then
              # For directories (e.g. skills/), make destination writable first
              chmod -R u+w "$TEMP_DIR/$item_name" 2>/dev/null || true
              # Copy each sub-item individually to merge
              for sub in "$item"/*; do
                sub_name=$(basename "$sub")
                rm -rf "$TEMP_DIR/$item_name/$sub_name" 2>/dev/null || true
                cp -r "$sub" "$TEMP_DIR/$item_name/"
                chmod -R u+w "$TEMP_DIR/$item_name/$sub_name"
              done
            else
              # For files (e.g. review-gate.md), just copy
              cp "$item" "$TEMP_DIR/"
              chmod u+w "$TEMP_DIR/$item_name"
            fi
          done
        fi
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
