{ inputs, ... }:

{
  imports = [ inputs.nix-colors.homeManagerModules.default ];

  colorScheme = import ../../shared/palette.nix;
}
