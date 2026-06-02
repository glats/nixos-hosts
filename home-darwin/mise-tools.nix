{ lib
, pkgs
, javaVersion
, ...
}:
{
  # Activation hook to ensure mise-managed global tool versions are declared and installed (Nix mise)
  home.activation.miseEnsureTools = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    set -e
    MISE_BIN="${pkgs.mise}/bin/mise"
    if [ ! -x "$MISE_BIN" ]; then
      echo "[mise] binary not found at $MISE_BIN" >&2
      exit 0
    fi

    echo "[mise] configuring global tool versions..."
    # Idempotent settings
    $MISE_BIN set MISE_NODE_COREPACK=true || true
    $MISE_BIN settings add idiomatic_version_file_enable_tools "[]" || true

    # Declare global versions (idempotent; 'use --global' updates .tool-versions)
    $MISE_BIN use --global node@lts
    $MISE_BIN use --global bun@latest
    $MISE_BIN use --global go@latest
    $MISE_BIN use --global java@${javaVersion}

    # Install any missing tools
    if ! $MISE_BIN install; then
      echo "[mise] tool installation failed" >&2
    fi

    $MISE_BIN reshim || true
    echo "[mise] tools ready: node bun go java"
  '';
}
