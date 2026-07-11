# Rog-specific Home Manager overlays on top of omarchy-nix.
#
# hypr/ subfiles added in PR3 (Hyprland per-host configs).
# This file is a scaffold imported by omarchy.nix.
{ config, lib, pkgs, ... }:

{
  imports = [
    ./hypr/monitors.nix
    ./hypr/input.nix
    ./hypr/env.nix
  ];
}
