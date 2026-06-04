# Home Manager OpenCode configuration for Linux
# Delegates to shared/opencode.nix for all logic
{ ... }:

{
  imports = [
    ../shared/opencode.nix
  ];
}
