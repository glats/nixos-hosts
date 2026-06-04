# Home Manager theme configuration for macOS
# Only palette - no GTK/QT/dconf (Linux-only)
{ inputs, ... }:

{
  imports = [ inputs.nix-colors.homeManagerModules.default ];

  colorScheme = import ../shared/palette.nix;
}
