{ ... }:

{
  sops.defaultSopsFile = ../../secrets/secrets.yaml;
  sops.age.keyFile = "/home/glats/.config/sops/age/keys.txt";

  sops.secrets."opencode/fireworks_api_key" = {
    mode = "0600";
  };

  sops.secrets."opencode/deepinfra_api_key" = {
    mode = "0600";
  };

  sops.secrets."opencode/anthropic_api_key" = {
    mode = "0600";
  };
}
