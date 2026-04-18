{ pkgs
, inputs
, lib
, ...
}:
{
  # Don't enable programs.neovim - it creates init.lua which conflicts with git repo
  # We manage nvim config via the activation script below
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
  ];

  home.file = {
    ".config/nvim/lua/plugins/snacks.lua".text = ''
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

    ".config/nvim/lua/plugins/image.lua".text = ''
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
  };

  home.activation."install-nvim-config" =
    let
      dst = "$HOME/.config/nvim";
      repo = "https://github.com/j1cs/nvim.git";
    in
    lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      echo "> Ensuring Neovim config at ${dst} (repo: ${repo})"
      if [ ! -d "${dst}" ] || [ -z "$(ls -A "${dst}" 2>/dev/null)" ]; then
        echo "> Cloning ${repo} into ${dst}"
        mkdir -p "${dst}"
        rmdir "${dst}" 2>/dev/null || true
        "${pkgs.git}/bin/git" clone "${repo}" "${dst}" || true
      else
        if [ -d "${dst}/.git" ]; then
          current_remote=$("${pkgs.git}/bin/git" -C "${dst}" remote get-url origin 2>/dev/null || true)
          if [ "$current_remote" = "${repo}" ]; then
            if "${pkgs.git}/bin/git" -C "${dst}" diff --quiet && [ -z "$(${pkgs.git}/bin/git -C "${dst}" status --porcelain)" ]; then
              echo "> Updating ${dst} (git pull --ff-only)"
              "${pkgs.git}/bin/git" -C "${dst}" pull --ff-only || true
            else
              echo "> Skipping update: local changes present in ${dst}"
            fi
          else
            echo "> Skipping update: origin is $current_remote, not ${repo}"
          fi
        else
          echo "> ${dst} exists and is not a git repo; leaving as-is"
        fi
      fi
      chmod -R u+rwX "${dst}" 2>/dev/null || true
    '';
}
