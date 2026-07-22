{ pkgs, lib, ... }:
{
  home.packages = with pkgs; [
    neovim
    fd
    tree-sitter
    python3
  ];

  home.activation.ensureNvimConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    GIT="${pkgs.git}/bin/git"
    if [ ! -d "$HOME/.config/nvim" ]; then
      $DRY_RUN_CMD $GIT clone https://github.com/glats/nvim "$HOME/.config/nvim"
    else
      if $GIT -C "$HOME/.config/nvim" rev-parse --git-dir >/dev/null 2>&1; then
        $DRY_RUN_CMD $GIT -C "$HOME/.config/nvim" fetch --depth=1 origin
        $DRY_RUN_CMD $GIT -C "$HOME/.config/nvim" merge --ff-only origin/main 2>/dev/null || true
      fi
    fi
  '';
}
