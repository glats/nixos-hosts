{ inputs, self }:
final: prev:
let
  system = final.stdenv.hostPlatform.system;
in
{
  mise = prev.mise.overrideAttrs (old: {
    doCheck = false;
  });

  sdl3 = prev.sdl3.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      (prev.fetchpatch {
        name = "sdl3-cocoa-clipboard-mimetype.patch";
        url = "https://github.com/libsdl-org/SDL/commit/f17fc121aaa7814d5686f9d18ba6edf0b9c06a15.patch?full_index=1";
        hash = "sha256-YMn1QghbYrvIKYghoYFiPCMXt/NMGMr1URO6801ggd8=";
      })
    ];
  });

  freerdp = prev.freerdp.overrideAttrs (old: {
    buildInputs = builtins.map (
      dependency: if (dependency.pname or "") == "sdl3" then final.sdl3 else dependency
    ) old.buildInputs;
    cmakeFlags = old.cmakeFlags ++ [
      "-DWITH_VIDEOTOOLBOX=ON"
    ];
    patches = (old.patches or [ ]) ++ [
      (prev.fetchpatch {
        name = "freerdp-sdl-macos-window-free-display-query.patch";
        url = "https://github.com/FreeRDP/FreeRDP/commit/dc5c7eeef2bb92f1b8cd767d278ec1c99a6534d2.patch?full_index=1";
        excludes = [ "client/SDL/SDL3/CMakeLists.txt" ];
        hash = "sha256-DQtyqMWp9LqPX3ZamArPHCxRBdXdk9zBwyIUxTNwgNE=";
      })
      ../patches/freerdp/sdl-macos-cmake.patch
      ../patches/freerdp/sdl-workarea-maximize.patch
    ];
  });

  shell-gpt = prev.shell-gpt.overridePythonAttrs (old: {
    dependencies = builtins.filter (d: d.pname != "litellm") old.dependencies;
  });

  wstunnel-relay = final.callPackage ../pkgs/wstunnel-relay { };

  rtk = prev.rtk.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ../patches/rtk/sigpipe-default.patch ];
  });

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
    opencode
    leaf
    herdr
    claude-code
    ;
}
