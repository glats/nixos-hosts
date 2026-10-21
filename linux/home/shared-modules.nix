{ inputs }:
[
  ./base.nix
  ./shell.nix
  ./theme.nix
  inputs.omarchy-nix.homeManagerModules.btop
  ./tmux.nix
  ./neovim.nix
  ./git.nix
  ./gpg.nix
  ./gh.nix
  ../../shared/gh-default-account.nix
  ./glab.nix
  ./ghostty.nix
  ./superfile.nix
  ./kitty.nix
  ./alacritty.nix
  ../../shared/shell-aliases.nix
  ../../shared/leaf.nix
  ../../shared/leaf-theme.nix
  ./groq-dictation.nix
  ../../shared/opencode.nix
  ../../shared/opencode-profile.nix
  ./opencode-mcps-extra.nix
  ../../shared/herdr.nix
  ../../shared/vscode.nix
  ../../shared/claude-code.nix
  ../../shared/claude-code-profile.nix
  ../../shared/codex.nix
  { home.codex.enable = true; }
  ../../shared/shell-gpt.nix
  { home.shell-gpt.enable = true; }
  ./ssh.nix
  ./fontconfig.nix
  ../../shared/sops.nix
  ../../shared/github-mcp-wrapper.nix
  inputs.sops-nix.homeManagerModules.sops
]
