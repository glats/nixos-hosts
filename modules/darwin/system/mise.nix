{ primaryUser, javaVersion, ... }:
{
  # Homebrew + mise activation responsibilities separated from darwin/default.nix
  # Ensures directories exist so Homebrew can link mise fish activation file (even if fish isn't used)
  system.activationScripts.ensureHomebrewMiseDirs.text = ''
    set -e
    if command -v brew >/dev/null 2>&1; then
      BREW_PREFIX="$(brew --prefix || echo /usr/local)"
      FISH_VENDOR="$BREW_PREFIX/share/fish/vendor_conf.d"
      if [ ! -d "$FISH_VENDOR" ]; then
        mkdir -p "$FISH_VENDOR" || true
      fi
      case "$BREW_PREFIX" in
        /usr/local)
          chown ${primaryUser}:staff "$BREW_PREFIX/share/fish" 2>/dev/null || true
          chown ${primaryUser}:staff "$FISH_VENDOR" 2>/dev/null || true
        ;;
      esac
      chmod u+rwx "$FISH_VENDOR" 2>/dev/null || true
    fi
  '';

  # Force linking of mise if installation succeeded but link step failed previously
  system.activationScripts.linkMise.text = ''
    set -e
    if command -v brew >/dev/null 2>&1; then
      if brew list --formula | grep -q '^mise$'; then
        if ! command -v mise >/dev/null 2>&1; then
          echo "[activation] attempting brew link mise" >&2
          brew link --overwrite --force mise || true
        fi
      fi
    fi
  '';

  # After linking, ensure global tools are declared and installed (node, bun, go, java)
  system.activationScripts.miseGlobalTools.text = ''
    set -e
    # Resolve mise binary explicitly (PATH may not yet include /usr/local/bin)
    MISE_BIN="$(command -v mise || true)"
    if [ -z "$MISE_BIN" ]; then
      for CAND in /usr/local/bin/mise /opt/homebrew/bin/mise; do
        [ -x "$CAND" ] && MISE_BIN="$CAND" && break
      done
    fi
    if [ -z "$MISE_BIN" ]; then
      echo "[mise-global] mise not found; skipping tool install" >&2
      exit 0
    fi
    echo "[mise-global] declaring global versions"
    $MISE_BIN use --global node@lts || true
    $MISE_BIN use --global bun@latest || true
    $MISE_BIN use --global go@latest || true
    $MISE_BIN use --global java@${javaVersion} || true
    echo "[mise-global] installing tools if missing"
    $MISE_BIN install || true
    $MISE_BIN reshim || true
    echo "[mise-global] done"
  '';

  # Recreate JAVA_HOME integration for JDK installed via mise
  system.activationScripts.miseJavaHome.text = ''
    set -e
    JAVA_VERSION="${javaVersion}"
    USER_HOME="/Users/${primaryUser}"
    SRC_CONTENTS="$USER_HOME/.local/share/mise/installs/java/$JAVA_VERSION/Contents"
    DEST_DIR="/Library/Java/JavaVirtualMachines/$JAVA_VERSION.jdk"
    if [ -d "$SRC_CONTENTS" ]; then
      mkdir -p "$DEST_DIR"
      if [ -e "$DEST_DIR/Contents" ]; then
        TARGET=$(readlink "$DEST_DIR/Contents" || true)
        if [ "$TARGET" != "$SRC_CONTENTS" ]; then
          rm -rf "$DEST_DIR/Contents"
          ln -s "$SRC_CONTENTS" "$DEST_DIR/Contents"
        fi
      else
        ln -s "$SRC_CONTENTS" "$DEST_DIR/Contents"
      fi
      echo "[mise-java] JAVA_HOME bundle linked at $DEST_DIR"
    else
      echo "[mise-java] Source not found at $SRC_CONTENTS (run: mise use --global java@$JAVA_VERSION && mise install)" >&2
    fi
  '';
}
