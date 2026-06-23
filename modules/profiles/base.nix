{
  imports = [
    # Base (transversal modules)
    ../base/cachix.nix
    ../base/dconf.nix
    ../base/home-manager.nix
    ../base/logind.nix
    ../base/nh.nix
    ../base/nix.nix
    ../base/packages.nix
    ../base/polkit.nix
    ../base/shutdown-fix.nix
    ../base/sops.nix
    ../base/users.nix
    ../base/zsh.nix

    # Networking
    ../networking/avahi.nix
    ../networking/firewall.nix
    ../networking/openssh.nix

    # Boot shared config
    ../features/boot.nix
  ];
}
