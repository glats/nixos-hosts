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

  home.file.".config/nvim/lua/plugins/nix-perf.lua" = {
    text = ''
      local cmdline_queries = {}

      return {
        "folke/snacks.nvim",
        init = function()
          local uname = vim.uv.os_uname()
          if uname == nil or uname.sysname == "Darwin" then
            return
          end
          vim.g.snacks_animate = false
          vim.api.nvim_create_autocmd("User", {
            pattern = "VeryLazy",
            once = true,
            callback = function()
              vim.schedule(function()
                require("lazy").load({ plugins = { "blink.cmp" } })
                for _, kind in ipairs({ "highlights", "injections" }) do
                  local ok, query = pcall(vim.treesitter.query.get, "vim", kind)
                  if ok then
                    cmdline_queries[kind] = query
                  end
                end
              end)
            end,
          })
        end,
      }
    '';
    force = true;
  };

  home.activation.ensureNvimConfig = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
    if [ ! -d "$HOME/.config/nvim" ]; then
      $DRY_RUN_CMD ${pkgs.git}/bin/git clone https://github.com/glats/nvim "$HOME/.config/nvim" \
        || echo "ensureNvimConfig: clone failed; skipping" >&2
    fi
  '';

  systemd.user.services.nvim-config-update = {
    Unit = {
      Description = "Update the Neovim configuration checkout";
      StartLimitIntervalSec = 900;
      StartLimitBurst = 5;
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.writeShellScript "nvim-config-update" ''
        dir="$HOME/.config/nvim"
        ${pkgs.git}/bin/git -C "$dir" rev-parse --git-dir >/dev/null 2>&1 || exit 0
        ${pkgs.coreutils}/bin/timeout 60s ${pkgs.git}/bin/git -C "$dir" fetch --depth=1 origin || exit 1
        ${pkgs.git}/bin/git -C "$dir" merge --ff-only origin/main 2>/dev/null || true
      ''}";
      Restart = "on-failure";
      RestartSec = "30s";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
