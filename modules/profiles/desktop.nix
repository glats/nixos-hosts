{
  imports = [
    ./base.nix

    # Desktop
    ../desktop/fonts.nix
    ../desktop/i18n.nix
    ../desktop/kmscon.nix

    # Hardware (keyring service)
    ../hardware/keyring.nix
  ];
}
