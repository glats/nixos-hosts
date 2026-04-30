{ config, ... }:

{
  # Home-manager sops config - uses user key for user-specific secrets
  sops.defaultSopsFile = ../../secrets/user/api_keys.yaml;
  sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
}
