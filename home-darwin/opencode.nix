# Home Manager OpenCode configuration for macOS
# Delegates to shared/opencode.nix for all logic
{ ... }:

{
  imports = [
    ../shared/opencode.nix
  ];
}
