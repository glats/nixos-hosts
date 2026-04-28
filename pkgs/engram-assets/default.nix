{ lib, stdenvNoCC, vanilla, engram }:

stdenvNoCC.mkDerivation {
  pname = "engram-assets";
  version = vanilla.version or "unstable";

  # No src needed — we build on top of vanilla
  dontUnpack = true;

  buildPhase = ''
    echo "Layering engram assets on top of vanilla..."
  '';

  installPhase = ''
    # Work in a temp directory to avoid permission issues
    TEMP_DIR=$(mktemp -d)
    chmod 755 "$TEMP_DIR"

    # Copy vanilla's CONTENTS (share/engram/*) to temp
    for item in ${vanilla}/share/engram/*; do
      # Copy and make writable
      cp -r "$item" "$TEMP_DIR/"
      chmod -R u+w "$TEMP_DIR/$(basename "$item")"
    done

    # Substitute ENGRAM_BIN default with nix store path
    if [ -f "$TEMP_DIR/opencode/plugins/engram.ts" ]; then
      substituteInPlace "$TEMP_DIR/opencode/plugins/engram.ts" \
        --replace "ENGRAM_BIN ?? Bun.which(\"engram\") ?? \"/usr/local/bin/engram\"" \
                  "ENGRAM_BIN ?? \"${engram}/bin/engram\""
    fi

    # Move to final destination
    mkdir -p $out/share/engram
    cp -r "$TEMP_DIR/"* $out/share/engram/

    rm -rf "$TEMP_DIR"
  '';

  meta = with lib; {
    description = "Engram OpenCode plugin with ENGRAM_BIN overlay";
    homepage = "https://github.com/Gentleman-Programming/engram";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
