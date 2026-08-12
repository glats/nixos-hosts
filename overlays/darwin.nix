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

  # Enable VideoToolbox hardware H.264 decode on macOS.
  # Without this, all decode is software (OpenH264), causing frame
  # timing jitter and flickering in sdl-freerdp.
  freerdp = prev.freerdp.overrideAttrs (old: {
    cmakeFlags = old.cmakeFlags ++ [
      "-DWITH_VIDEOTOOLBOX=ON"
    ];
  });

  # shell-gpt 1.5.x hard-depends on litellm → tokenizers → datasets → pyarrow →
  # arrow-cpp, and arrow-cpp 23.0.0 is marked broken on x86_64-darwin.
  # litellm is only imported lazily when USE_LITELLM=true (default false),
  # so dropping it keeps sgpt working with OpenAI-compatible endpoints (nvidia NIM).
  shell-gpt = prev.shell-gpt.overridePythonAttrs (old: {
    dependencies = builtins.filter (d: d.pname != "litellm") old.dependencies;
  });

  # Cross-platform packages from flake outputs
  inherit (self.packages.${system})
    nixos-scripts
    gentle-ai
    engram
    gentle-ai-assets
    caveman-assets
    ponytail-assets
    local-ai-assets
    engram-assets-vanilla
    engram-assets
    secret-guard-assets
    opencode-npm-packages
    opencode
    leaf
    claude-code
    ;
}
