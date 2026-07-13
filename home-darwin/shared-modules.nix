# Canonical list of shared Home Manager modules for Darwin hosts.
#
# Both `flake.nix` (`darwinHomeModules`) and `home-darwin/default.nix`
# import this list as the single source of truth. Conditional modules
# (e.g. `spotlight-index.nix`) and Darwin-local auxiliary modules
# (e.g. `opencode/mcps-extra.nix`) are NOT included here and are
# appended by `default.nix` with the appropriate condition.
#
# Mirrors `home-linux/shared-modules.nix` to keep the two platforms
# aligned structurally.
{ inputs }:
[
  ./theme.nix
  ./ghostty.nix
  ./leaf-theme.nix
  ./git.nix
  ./gpg.nix
  ./ssh.nix
  ./mise-tools.nix
  ./packages.nix
  ./neovim.nix
  ./shell.nix
  ./tmux.nix
  # btop theme + settings owned by omarchy-nix (homeManagerModules.btop).
  # Reads config.colorScheme.palette (nix-colors provided by theme.nix below);
  # theme.nix must be listed before this entry so colorScheme.palette is set.
  inputs.omarchy-nix.homeManagerModules.btop
  ./vscode.nix
  #./windsurf.nix
  ./remote-desktop.nix
  ../shared/shell-aliases.nix
  ../shared/opencode.nix
  ../shared/opencode-profile.nix
  ../shared/claude-code.nix
  ../shared/claude-code-profile.nix
  ./sops.nix
  ./github-mcp-server-wrapper.nix
  inputs.sops-nix.homeManagerModules.sops
]
