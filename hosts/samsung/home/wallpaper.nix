{
  lib,
  pkgs,
  ...
}:

{
  dconf.settings."org/mate/desktop/background" = {
    picture-filename = lib.mkForce "${pkgs.mate-backgrounds}/share/backgrounds/mate/desktop/Ubuntu-Mate-Dark-no-logo.png";
    picture-options = lib.mkForce "zoom";
  };
}
