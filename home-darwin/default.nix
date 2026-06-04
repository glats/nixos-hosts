# Home Manager configuration for macOS
# Aggregates all home-darwin modules
{
  pkgs,
  lib,
  primaryUser,
  ...
}:
let
  # Toggle: set to false to disable Spotlight indexing for HM apps
  hmSpotlightIndexEnable = true;
  baseConfig = {
    imports = [
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
      ./vscode.nix
      ./windsurf.nix
      ./opencode.nix # Provides option definitions and activation scripts
      ./opencode-profile.nix # Provides plugin/TUI enablement settings
      ./sops.nix
      ./github-mcp-server-wrapper.nix
    ]
    ++ lib.optionals hmSpotlightIndexEnable [
      ./spotlight-index.nix
    ];

    # Minimal home fragment; tmux is configured in ./tmux.nix
    home.username = primaryUser;
    # Ensure the home directory option is set so home-manager can resolve paths
    home.homeDirectory = "/Users/${primaryUser}";
    home.stateVersion = "25.05";
    home.sessionVariables = {
      VISUAL = lib.mkForce "nvim -u NONE";
    };

    # Disable man page generation — triggers boost::too_few_args in Nix 2.31
    # (home-manager uses builtins.derivation for options.json without proper store context)
    manual.manpages.enable = false;

    # Silenciar warning de version mismatch entre home-manager y nixpkgs
    home.enableNixpkgsReleaseCheck = false;

    # create .hushlogin file to suppress login messages
    home.file.".hushlogin".text = "";
  };
in
baseConfig
