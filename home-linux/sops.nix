{ ... }:

{
  imports = [ ../shared/sops.nix ];

  # NOTE: openfang secrets were removed from the unified secrets file.
  # To re-enable openfang, add these keys back to secrets/user/api_keys.yaml
  # and set home.openfang.enable = true in your host config.
}
