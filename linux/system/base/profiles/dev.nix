# Development profile
# Build toolchains, language runtimes, and editor/AI tools.
# Used by hosts where the user actively develops software.
#
# Note: gnumake and nodejs are now ungated. t14 evaluates them from
# BOTH nixos-hosts and omarchy-nix; the Nix store deduplicates the
# derivations (same /nix/store path), so there is no runtime cost.
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

  # Android platform tools (adb, fastboot)
  # systemd 258+ handles uaccess udev rules automatically — no groups needed
  android-tools

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
