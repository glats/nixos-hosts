{
  lib,
  pkgs,
  primaryUser,
  javaVersion,
  ...
}:
{
  # Declare tools in the primary user's mise state, not root's activation state.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    set -e
    MISE="sudo -H -u ${primaryUser} ${pkgs.mise}/bin/mise"

    echo "[mise-global] declaring global versions"
    $MISE use --global node@lts
    $MISE use --global bun@latest
    $MISE use --global go@latest
    $MISE use --global java@${javaVersion}
    echo "[mise-global] installing tools if missing"
    $MISE install
    $MISE reshim

    # Recreate JAVA_HOME integration for the JDK installed by mise.
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
      echo "[mise-java] Source not found at $SRC_CONTENTS" >&2
      exit 1
    fi

    echo "[mise-global] done"
  '';
}
