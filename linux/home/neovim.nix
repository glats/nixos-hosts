{
  pkgs,
  lib,
  ...
}:
{
  home.packages = with pkgs; [
    ripgrep
    fd
    tree-sitter
    nodejs
    python3
    git
    imagemagick
    lua5_1
    luarocks
    icu
  ];

  programs.neovim.enable = lib.mkForce false;

  home.file.".config/nvim/lua/plugins/nix/snacks.lua" = {
    text = ''
      return {
        "folke/snacks.nvim",
        opts = {
          image = {
            enabled = true,
            backend = "kitty",
          },
        },
      }
    '';
    force = true;
  };

  home.file.".config/nvim/lua/plugins/nix/image.lua" = {
    text = ''
      return {
        "3rd/image.nvim",
        build = "luarocks --lua-version 5.1 install magick",
        opts = {
          backend = "kitty",
          integrations = {
            markdown = {
              enabled = true,
              clear_in_insert_mode = false,
              download_remote_images = true,
              filetypes = { "markdown", "vimwiki" },
            },
          },
          max_width = 100,
          max_height = 12,
          max_height_window_percentage = math.huge,
          max_width_window_percentage = math.huge,
          window_overlap_level = 3,
        },
      }
    '';
    force = true;
  };

  home.file.".config/nvim/lua/plugins/nix/perf.lua" = {
    text = ''
      return {
        "folke/snacks.nvim",
        init = function()
          local uname = vim.uv.os_uname()
          if uname == nil or uname.sysname == "Darwin" then
            return
          end
          vim.g.snacks_animate = false
        end,
      }
    '';
    force = true;
  };

  home.activation.ensureNvimConfig = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
    GIT="${pkgs.git}/bin/git"
    if [ ! -d "$HOME/.config/nvim" ]; then
      $DRY_RUN_CMD $GIT clone https://github.com/glats/nvim "$HOME/.config/nvim" \
        || echo "ensureNvimConfig: clone failed; skipping" >&2
    else
      if $GIT -C "$HOME/.config/nvim" rev-parse --git-dir >/dev/null 2>&1; then
        if $DRY_RUN_CMD $GIT -C "$HOME/.config/nvim" fetch --depth=1 origin; then
          $DRY_RUN_CMD $GIT -C "$HOME/.config/nvim" merge --ff-only origin/main 2>/dev/null || true
        else
          echo "ensureNvimConfig: fetch failed; keeping current config" >&2
        fi
      fi
    fi
  '';
}
