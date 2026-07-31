{
  # Secrets shared by all hosts
  sops.defaultSopsFile = ../../../secrets/shared/passwords.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;

  imports = [
    ../../../shared/github-tokens.nix
  ];

  sops.secrets."glats_hashed_password" = {
    neededForUsers = true;
  };

  sops.secrets."github/personal_pat" = {
    owner = "glats";
    group = "users";
  };

  sops.secrets."github/work_pat" = {
    owner = "glats";
    group = "users";
  };
}
