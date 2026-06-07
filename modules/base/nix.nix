{ ... }:

{
  nix.gc = {
    automatic = false;
    dates = "weekly";
    randomizedDelaySec = "1h";
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
  };
}
