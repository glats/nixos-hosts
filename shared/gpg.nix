{
  config,
  lib,
  pkgs,
  ...
}:

let
  importKey = name: fingerprintPath: keyPath: ''
    for ((i = 0; i < 50; i++)); do
      [ -f "${fingerprintPath}" ] && [ -f "${keyPath}" ] && break
      sleep 0.2
    done
    if [ -f "${fingerprintPath}" ] && [ -f "${keyPath}" ]; then
      FINGERPRINT="$(cat "${fingerprintPath}" | tr -d '\n')"
      if [ -n "$FINGERPRINT" ] && ! ${pkgs.gnupg}/bin/gpg --list-secret-keys "$FINGERPRINT" >/dev/null 2>&1; then
        ${pkgs.gnupg}/bin/gpg --batch --import "${keyPath}"
      fi
    fi
  '';
in
{
  home.activation.importGpgKeys = lib.hm.dag.entryAfter [ "writeBoundary" "sops-nix" ] (
    importKey "work" config.sops.secrets."github/work_gpg_fingerprint".path
      config.sops.secrets."github/work_gpg_key".path
    +
      importKey "personal" config.sops.secrets."github/personal_gpg_fingerprint".path
        config.sops.secrets."github/personal_gpg_key".path
  );
}
