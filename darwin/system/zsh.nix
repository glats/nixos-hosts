{ lib, ... }:

{
  programs.zsh.promptInit = lib.mkForce "";
  programs.zsh.enableCompletion = lib.mkForce false;
  programs.zsh.enableBashCompletion = lib.mkForce false;
}
