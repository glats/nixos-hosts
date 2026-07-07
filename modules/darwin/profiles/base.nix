# Profile: Darwin base system configuration.
# Pure import aggregator -- mirrors modules/profiles/base.nix.
# Contains ONLY an imports list with zero inline configuration.
# Consumed by darwin/default.nix.
{
  imports = [
    ../system/nix.nix
    ../system/cachix.nix
    ../system/homebrew.nix
    ../system/settings.nix
    ../system/mise.nix
    ../services/wsdd.nix
  ];
}
