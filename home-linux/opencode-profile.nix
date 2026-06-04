# Home Manager OpenCode profile for Linux
# Delegates to shared/opencode-profile.nix for all logic
{ ... }:

{
  imports = [
    ../shared/opencode-profile.nix
  ];
}
