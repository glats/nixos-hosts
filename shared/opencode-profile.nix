{ lib, ... }:

{
  imports = [
    ./ai-assets.nix
  ];

  home.ai-assets.enable = true;

  home.opencode = {
    enable = true;

    activeProviderName = lib.mkDefault "ollama-full";

  };
}
