{ lib, ... }:

{
  imports = [
    ./ai-assets.nix
  ];

  # Gentle AI shared ecosystem enabled when any tool uses it
  home.ai-assets.enable = true;

  home.opencode = {
    enable = true;

    # Default provider tier; override per-host in the host's default.nix.
    # mkDefault so per-host plain assignments win without mkForce.
    activeProviderName = lib.mkDefault "opencode-go-full";

  };
}
