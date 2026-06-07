{
  pkgs,
  inputs,
  ...
}:
let
  # Build the upstream nvim config as a Nix store path so ~/.config/nvim
  # is reproducible, content-addressed, and never touches the network at
  # activation time. Replaces the previous activation-script that did a
  # git clone + pull against github.com/j1cs/nvim.
  nvim-config = pkgs.stdenvNoCC.mkDerivation {
    pname = "nvim-config";
    version = "unstable";
    src = inputs.nvim-config;
    dontBuild = true;
    installPhase = ''
      cp -r . $out
    '';
  };
in
{
  programs.neovim = {
    enable = true;
    defaultEditor = false;
    vimAlias = true; # provide `vim` command
    viAlias = true; # provide `vi` command

    # Pin legacy behavior to silence warnings for stateVersion < 26.05
    withRuby = false;
    withPython3 = false;

    # Useful external tools for many plugins
    extraPackages = with pkgs; [
      ripgrep
      fd
      tree-sitter
      nodejs
      python3
      git
      nixfmt
    ];
  };

  home.file.".config/nvim".source = nvim-config;
}
