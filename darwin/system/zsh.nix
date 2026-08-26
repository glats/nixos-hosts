# Neutralize nix-darwin's default zsh interactive setup.
#
# Home Manager (prezto) owns the prompt and completion for interactive shells.
# Without these overrides every shell pays twice:
#   - promptInit defaults to `prompt suse` (second prompt system vs prezto)
#   - enableCompletion defaults to true -> compinit #1 + bashcompinit, then
#     prezto's completion pmodule runs compinit #2 (~0.6s combined)
#
# NOTE: keep programs.zsh.enabled (default true) so /etc/zshenv stays and
# nix-homebrew keeps injecting `brew shellenv` via interactiveShellInit.
{ lib, ... }:

{
  programs.zsh.promptInit = lib.mkForce "";
  programs.zsh.enableCompletion = lib.mkForce false;
  programs.zsh.enableBashCompletion = lib.mkForce false;
}
