# CLI extras profile — tools already provided by omarchy-nix on t14.
# Imported only by MATE suite hosts (rog, thinkcentre) via mate.nix.
# t14 (suite = "gnome") never pulls this in; omarchy-nix ships these
# packages from its own closure.
{ pkgs }:
with pkgs;
[
  fzf
  curl
  wget
  unzip
  fastfetch
  btop
  coreutils
  lazygit
  lazydocker
  jq
  ghostty
]
