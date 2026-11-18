{ pkgs }:
with pkgs;
[
  gcc
  gnumake
  cmake
  meson
  ninja
  autoconf
  automake
  libtool
  pkg-config

  go_1_27
  nodejs
  nodejs_22
  bun

  android-tools

  neovim

  codex
  openfang

  godot_4-mono

  dotnet-sdk_8
]
