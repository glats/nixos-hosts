{ config, ... }:

{
  programs.git = {
    enable = true;
    settings = {
      credential.helper = "store --file=${config.sops.secrets.git-credentials.path}";
    };
  };

  sops.secrets.git-credentials = {
    mode = "0600";
  };
}
