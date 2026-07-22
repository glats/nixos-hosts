{ pkgs, lib, ... }:
let
  syncScript = pkgs.writeShellScript "hm-apps-spotlight-sync" ''
      set -euo pipefail

      # Portable realpath resolver: try realpath, readlink -f, python3, perl, fallback
      resolve_realpath() {
        local p="$1"
        if command -v realpath >/dev/null 2>&1; then
          realpath "$p"
        elif command -v readlink >/dev/null 2>&1 && readlink -f / >/dev/null 2>&1; then
          readlink -f "$p"
        elif command -v python3 >/dev/null 2>&1; then
          python3 -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "$p"
        elif command -v perl >/dev/null 2>&1; then
          perl -MCwd -e 'print Cwd::abs_path(shift)' "$p"
        else
          # fallback: return input (may be relative)
          echo "$p"
        fi
      }

    # Candidate locations for Home Manager / Nix apps (expanded inline to avoid
    # Nix string interpolation constructs in the embedded shell script)
      HM_APPS=""
      for c in "$HOME/Applications/Home Manager Apps" "$HOME/.nix-profile/Applications"; do
        if [ -d "$c" ]; then
          HM_APPS="$c"
          break
        fi
      done

      if [ -z "$HM_APPS" ]; then
        # nothing to do
        exit 0
      fi

      DEST="$HOME/Applications/Nix-Apps"

      # Work in a temp dir and swap atomically to avoid inconsistent state
      tmpdir="$(mktemp -d "$DEST".tmp.XXXX)"
      trap 'rm -rf "$tmpdir"' EXIT

      shopt -s nullglob 2>/dev/null || true
      for src in "$HM_APPS"/*.app; do
        [ -e "$src" ] || continue
        appname="$(basename "$src")"
        target="$tmpdir/$appname"

        mkdir -p "$target/Contents"

        # Copy Info.plist (Spotlight reads it)
        if [ -f "$src/Contents/Info.plist" ]; then
          cp -f "$src/Contents/Info.plist" "$target/Contents/Info.plist"
        fi

        # Copy icons (.icns)
        if [ -d "$src/Contents/Resources" ]; then
          mkdir -p "$target/Contents/Resources"
          find "$src/Contents/Resources" -maxdepth 1 -type f -name '*.icns' -print0 \
            | xargs -0 -I{} cp -f "{}" "$target/Contents/Resources/" 2>/dev/null || true
        fi

        # Symlink other entries resolving to absolute paths so wrappers don't break
        shopt -s nullglob 2>/dev/null || true
        for item in "$src/Contents"/*; do
          base="$(basename "$item")"
          case "$base" in
            Info.plist|Resources) continue ;;
            MacOS)
              # Create a real MacOS directory and symlink individual executables
              mkdir -p "$target/Contents/MacOS"
              shopt -s nullglob 2>/dev/null || true
              for exe in "$src/Contents/MacOS"/*; do
                exebase="$(basename "$exe")"
                resolved_exe="$(resolve_realpath "$exe")"
                ln -sfn "$resolved_exe" "$target/Contents/MacOS/$exebase"
              done
              ;;
          esac
          if [ "$base" != "MacOS" ]; then
            mkdir -p "$(dirname "$target/Contents/$base")"
            resolved="$(resolve_realpath "$item")"
            ln -sfn "$resolved" "$target/Contents/$base"
          fi
        done
      done

      # Atomic swap into place with safe removal: move removed apps to a trash
      # directory and log changes. Keep a DEST.old backup and cleanup old trash.
      logdir="$HOME/.local/share"
      logfile="$logdir/hm-apps-sync.log"
      mkdir -p "$logdir"

      if [ -e "$DEST" ] || [ -L "$DEST" ]; then
        # Prepare trash folder for removed apps
        mkdir -p "$DEST/.trash"
        timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
        trash_dir="$DEST/.trash/$timestamp"
        mkdir -p "$trash_dir"

        # Move apps that exist in old DEST but not in new tmpdir into trash
        shopt -s nullglob 2>/dev/null || true
        for app in "$DEST"/*.app; do
          [ -e "$app" ] || continue
          name="$(basename "$app")"
          if [ ! -e "$tmpdir/$name" ]; then
            mv -f "$app" "$trash_dir/" && echo "$(date -u) moved $app -> $trash_dir/" >> "$logfile" || true
          fi
        done

        # Backup old DEST in case of unexpected issues
        mv -f "$DEST" "$DEST".old || rm -rf "$DEST".old || true
      fi

      # Move new tree into place atomically
      mv -f "$tmpdir" "$DEST"

      # Cleanup old trash entries older than 7 days
      if [ -d "$DEST/.trash" ]; then
        find "$DEST/.trash" -mindepth 1 -maxdepth 1 -type d -mtime +7 -exec rm -rf {} \; 2>/dev/null || true
      fi

      # Remove the old backup (we keep it only for the duration of this run)
      rm -rf "$DEST".old || true
      trap - EXIT

      # Remove visible Home Manager Apps symlink from ~/Applications if present
      if [ -L "$HOME/Applications/Home Manager Apps" ]; then
        rm -f "$HOME/Applications/Home Manager Apps" || true
      fi

      # Trigger Spotlight indexing on the new folder
      if command -v mdimport >/dev/null 2>&1; then
        mdimport -r "$DEST" >/dev/null 2>&1 || true
        mdimport "$DEST" >/dev/null 2>&1 || true
      fi
  '';
in
{
  home.activation.hmAppsSpotlightIndex = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    ${syncScript}
  '';
}
