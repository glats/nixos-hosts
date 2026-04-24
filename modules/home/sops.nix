{ ... }:

{
  # Home-manager sops config - usa la misma key que el sistema
  sops.defaultSopsFile = ../../secrets/secrets.yaml;
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
}