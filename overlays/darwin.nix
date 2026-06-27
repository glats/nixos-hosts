# Darwin-specific overlay
# Provides packages needed by home-darwin modules and darwin system config
{ inputs, self }:
final: prev:
let
  system = final.stdenv.hostPlatform.system;
in
{
  # mise: test `preserve_metadata_dir_layer_keeps_special_permission_bits` fails on
  # macOS because APFS in the sandboxed build environment doesn't preserve setuid
  # bits from tarball extraction (expects 0o4755, gets 0o755).
  mise = prev.mise.overrideAttrs (old: {
    doCheck = false;
  });

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
    opencode
    ;
}
