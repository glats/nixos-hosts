# Development profile
# Build toolchains, language runtimes, and editor/AI tools.
# Used by hosts where the user actively develops software.
#
# `gnumake` and `nodejs` are gated with `lib.mkIf (cfg != "gnome")`
# because omarchy-nix already provides them on t14 (suite = "gnome").
{ pkgs
, config
, lib
, ...
}:
let
  cfg = config.my.desktop.suite;
  nonGnome = p: lib.mkIf (cfg != "gnome") p;
in
with pkgs;
[
  # Native toolchain
  gcc
  (nonGnome gnumake)
  cmake
  meson
  ninja
  autoconf
  automake
  libtool
  pkg-config

  # Language runtimes
  go
  (nonGnome nodejs)
  nodejs_22
  bun

  # Editors and IDEs
  neovim

  # AI tooling
  codex
  opencode
  openfang

  # Game/graphics engine (mono variant for C# support)
  godot_4-mono

  # .NET SDK 8
  dotnet-sdk_8
]
