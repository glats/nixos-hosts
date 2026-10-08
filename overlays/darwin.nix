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

  # Backport SDL #16077: Cocoa clipboard reads must use the pasteboard's
  # available MIME type. SDL 3.4.10 predates the fix released in 3.4.14.
  sdl3 = prev.sdl3.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      (prev.fetchpatch {
        name = "sdl3-cocoa-clipboard-mimetype.patch";
        url = "https://github.com/libsdl-org/SDL/commit/f17fc121aaa7814d5686f9d18ba6edf0b9c06a15.patch?full_index=1";
        hash = "sha256-YMn1QghbYrvIKYghoYFiPCMXt/NMGMr1URO6801ggd8=";
      })
    ];
  });

  # Enable VideoToolbox hardware H.264 decode on macOS.
  # Without this, all decode is software (OpenH264), causing frame
  # timing jitter and flickering in sdl-freerdp.
  freerdp = prev.freerdp.overrideAttrs (old: {
    buildInputs = builtins.map (
      dependency: if (dependency.pname or "") == "sdl3" then final.sdl3 else dependency
    ) old.buildInputs;
    cmakeFlags = old.cmakeFlags ++ [
      "-DWITH_VIDEOTOOLBOX=ON"
    ];
    # Backport FreeRDP PR #13564: query SDL displays without creating a probe
    # window per monitor. On macOS each probe window enters a native fullscreen
    # Space (~650 ms per display), which made the session window hop across
    # displays. The CMake hunk is excluded upstream-side and replaced by a local
    # adapter for 3.30.0. Drop both once nixpkgs freerdp includes PR #13564;
    # re-check at each nixpkgs bump.
    patches = (old.patches or [ ]) ++ [
      (prev.fetchpatch {
        name = "freerdp-sdl-macos-window-free-display-query.patch";
        url = "https://github.com/FreeRDP/FreeRDP/commit/dc5c7eeef2bb92f1b8cd767d278ec1c99a6534d2.patch?full_index=1";
        excludes = [ "client/SDL/SDL3/CMakeLists.txt" ];
        hash = "sha256-DQtyqMWp9LqPX3ZamArPHCxRBdXdk9zBwyIUxTNwgNE=";
      })
      ../patches/freerdp/sdl-macos-cmake.patch
    ];
  });

  # shell-gpt 1.5.x hard-depends on litellm → tokenizers → datasets → pyarrow →
  # arrow-cpp, and arrow-cpp 23.0.0 is marked broken on x86_64-darwin.
  # litellm is only imported lazily when USE_LITELLM=true (default false),
  # so dropping it keeps sgpt working with OpenAI-compatible endpoints (nvidia NIM).
  shell-gpt = prev.shell-gpt.overridePythonAttrs (old: {
    dependencies = builtins.filter (d: d.pname != "litellm") old.dependencies;
  });

  wstunnel-relay = final.callPackage ../pkgs/wstunnel-relay { };

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
    opencode-npm-packages-v2
    browsermcp-v2
    opencode-v2
    leaf
    claude-code
    ;
}
