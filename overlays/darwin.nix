# Darwin-specific overlay
# Provides packages needed by home-darwin modules and darwin system config
{ inputs, self }:
final: _prev:
let
  system = final.stdenv.hostPlatform.system;
in
{
  # Ghostty from flake input (macOS terminal emulator)
  ghostty = inputs.ghostty.packages.${system}.default;

  # Cross-platform packages from flake outputs
  inherit (self.packages.${system})
    gentle-ai
    engram
    gentle-ai-assets-vanilla
    gentle-ai-assets
    engram-assets-vanilla
    engram-assets
    secret-guard-assets
    opencode-npm-packages
    ;
}
