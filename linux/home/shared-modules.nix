# Canonical list of shared Home Manager modules for Linux hosts.
#
# Both `flake.nix` (`linuxHomeModules`) and `modules/base/home-manager.nix`
# (`home-manager.users.glats.imports`) import this list as the single source
# of truth. Host-conditional modules (conky-rog, conky-thinkcentre, openfang)
# are NOT included here and are appended by each caller with the appropriate
# host check.
#
# Previously this list was duplicated in two files with a silent drift:
# `flake.nix` included `openfang.nix` unconditionally, while
# `modules/base/home-manager.nix` only loaded it for the `rog` host.
# Centralizing the list here eliminates the divergence.
{ inputs }:
[
  ./base.nix
  ./shell.nix
  ./theme.nix
  # btop theme + settings owned by omarchy-nix (homeManagerModules.btop).
  # Imports nix-colors.homeManagerModules.default internally; the local
  # theme.nix must be listed before this entry so colorScheme.palette is set.
  inputs.omarchy-nix.homeManagerModules.btop
  ./tmux.nix
  ./neovim.nix
  ./git.nix
  ./gpg.nix
  ./gh.nix
  ./ghostty.nix
  ./superfile.nix
  ./kitty.nix
  ./alacritty.nix
  ../../shared/shell-aliases.nix
  ../../shared/leaf.nix
  ../../shared/leaf-theme.nix
  ../../shared/opencode.nix
  ../../shared/opencode-profile.nix
  ../../shared/claude-code.nix
  ../../shared/claude-code-profile.nix
  ./ssh.nix
  ./fontconfig.nix
  ../../shared/sops.nix
  inputs.sops-nix.homeManagerModules.sops
]
