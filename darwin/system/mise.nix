{ primaryUser, javaVersion, ... }:
{
  # After linking, ensure global tools are declared and installed (node, bun, go, java)
  system.activationScripts.miseGlobalTools.text = ''
    set -e
    if ! command -v mise >/dev/null 2>&1; then
      echo "[mise-global] mise not found; skipping tool install" >&2
      exit 0
    fi
    echo "[mise-global] declaring global versions"
    mise use --global node@lts || true
    mise use --global bun@latest || true
    mise use --global go@latest || true
    mise use --global java@${javaVersion} || true
    echo "[mise-global] installing tools if missing"
    mise install || true
    mise reshim || true
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
