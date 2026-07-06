{ config, lib, pkgs, ... }:

let
  # Import both GPG keys from sops into keyring if not already present
  importKey = name: fingerprintPath: keyPath: ''
    if [ -f "${fingerprintPath}" ] && [ -f "${keyPath}" ]; then
      FINGERPRINT="$(cat "${fingerprintPath}" | tr -d '\n')"
      if [ -n "$FINGERPRINT" ] && ! ${pkgs.gnupg}/bin/gpg --list-secret-keys "$FINGERPRINT" >/dev/null 2>&1; then
        ${pkgs.gnupg}/bin/gpg --batch --import "${keyPath}"
      fi
    fi
  '';
in
{
  home.packages = with pkgs; [
    gnupg
    pinentry-curses
  ];

  home.activation.importGpgKeys = lib.hm.dag.entryAfter [ "writeBoundary" ]
    (importKey "jcuzmar"
      config.sops.secrets."github/gpg_jcuzmar_fingerprint".path
      config.sops.secrets."github/gpg_jcuzmar_key".path
    + importKey "glats"
      config.sops.secrets."github/gpg_glats_fingerprint".path
      config.sops.secrets."github/gpg_glats_key".path
    );
}
