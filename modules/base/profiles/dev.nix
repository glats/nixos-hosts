# Development profile
# Build toolchains, language runtimes, and editor/AI tools.
# Used by hosts where the user actively develops software.
{ pkgs }:
with pkgs;
[
  # Native toolchain
  gcc
  gnumake
  cmake
  meson
  ninja
  autoconf
  automake
  libtool
  pkg-config

  # Language runtimes
  go
  nodejs
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
