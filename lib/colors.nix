# Shared color helper functions used by NixOS and Home Manager modules.
#
# Usage:
#   let
#     colors = import ../lib/colors.nix { inherit lib; };
#   in
#   {
#     # ...
#     color = "rgb(${colors.hexToRgb config.colorScheme.palette.base00})";
#   }
{
  lib,
}:
let
  hexToRgb =
    hex:
    let
      r = lib.fromHexString (builtins.substring 0 2 hex);
      g = lib.fromHexString (builtins.substring 2 2 hex);
      b = lib.fromHexString (builtins.substring 4 2 hex);
    in
    "${toString r},${toString g},${toString b}";

  doubleHex =
    hex:
    lib.concatStrings (
      lib.concatMap (c: [
        c
        c
      ]) (lib.stringToCharacters hex)
    );

  byteDoubleHex =
    hex:
    let
      r = lib.substring 0 2 hex;
      g = lib.substring 2 2 hex;
      b = lib.substring 4 2 hex;
    in
    "${r}${r}${g}${g}${b}${b}";
in
{
  inherit hexToRgb doubleHex byteDoubleHex;
}
