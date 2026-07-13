{ ... }:

{
  imports = [
    ./gentle-ai-common.nix
  ];

  home.gentle-ai.enable = true;

  home.claude-code.enable = true;
}
