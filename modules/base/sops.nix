{
  # Secrets shared by all hosts
  sops.defaultSopsFile = ../../secrets/system/passwords.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;

  sops.secrets."glats_hashed_password" = {
    neededForUsers = true;
  };

  sops.secrets."github/pat" = {
    owner = "glats";
    group = "users";
    mode = "0400";
  };
}
