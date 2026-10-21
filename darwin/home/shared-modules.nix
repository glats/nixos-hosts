{ inputs }:
[
  ./theme.nix
  ./ghostty.nix
  ./superfile.nix
  ./git.nix
  ./gpg.nix
  ./ssh.nix

  ./packages.nix
  ./flameshot.nix
  ./neovim.nix
  ./shell.nix
  ./tmux.nix
  inputs.omarchy-nix.homeManagerModules.btop
  ./vscode.nix

  ./remote-desktop.nix
  ./edge-tunnel-app.nix
  ../../shared/shell-aliases.nix
  ../../shared/leaf.nix
  ../../shared/leaf-theme.nix
  ../../shared/opencode.nix
  ../../shared/opencode-profile.nix
  ../../shared/herdr.nix
  ../../shared/claude-code.nix
  ../../shared/claude-code-profile.nix
  ../../shared/shell-gpt.nix
  { home.shell-gpt.enable = true; }
  ./sops.nix
  ../../shared/github-mcp-wrapper.nix
  ../../shared/gh-default-account.nix
  inputs.sops-nix.homeManagerModules.sops
]
