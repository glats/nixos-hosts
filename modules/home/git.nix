{ config, ... }:

{
  programs.git = {
    enable = true;
    # Explicitly set signing format to silence home-manager warning (legacy default)
    signing.format = "openpgp";
    settings = {
      credential.helper = "store --file=${config.sops.secrets.git-credentials.path}";
    };
  };

  sops.secrets.git-credentials = {
    mode = "0600";
  };
}
