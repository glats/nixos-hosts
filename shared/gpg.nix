# Shared GPG key import logic used by both Linux and Darwin Home Manager
# configurations. Extracted from home-linux/gpg.nix and home-darwin/gpg.nix
# (byte-identical in both files).
#
# Does NOT set home.packages -- the calling platform module is responsible
# for choosing the appropriate pinentry package.
#
# Depends on shared/sops.nix for secret paths:
#   - github/work_gpg_fingerprint
#   - github/work_gpg_key
#   - github/personal_gpg_fingerprint
#   - github/personal_gpg_key
{ config, lib, pkgs, ... }:

let
  # Import a GPG key from sops secrets into the keyring if not already present.
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
  home.activation.importGpgKeys = lib.hm.dag.entryAfter [ "writeBoundary" ]
    (importKey "work"
      config.sops.secrets."github/work_gpg_fingerprint".path
      config.sops.secrets."github/work_gpg_key".path
    + importKey "personal"
      config.sops.secrets."github/personal_gpg_fingerprint".path
      config.sops.secrets."github/personal_gpg_key".path
    );
}
