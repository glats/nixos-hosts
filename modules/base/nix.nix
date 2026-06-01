{ ... }:

{
  nix.gc = {
    automatic = false;
    dates = "weekly";
    randomizedDelaySec = "1h";
  };

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };
}

# ZRAM swap - enable separately per host, not globally
# zramSwap.enable = true;
