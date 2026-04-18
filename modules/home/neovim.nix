{ pkgs
, inputs
, lib
, ...
}:

let
  # Derivation that merges upstream nvim config with local customizations
  nvim-with-custom = pkgs.stdenvNoCC.mkDerivation {
    pname = "nvim-config-merged";
    version = "unstable";
    
    src = inputs.nvim-config;
    
    installPhase = ''
      mkdir -p $out
      
      # Copy all upstream files
      cp -r ./* $out/
      
      # Create directory for custom nix plugins
      mkdir -p $out/lua/plugins/nix
      
      # Write custom snacks.lua
      cat > $out/lua/plugins/nix/snacks.lua <<'EOF'
    return {
      "folke/snacks.nvim",
      opts = {
        image = {
          enabled = true,
          backend = "kitty",
        },
      },
    }
    EOF
      
      # Write custom image.lua
      cat > $out/lua/plugins/nix/image.lua <<'EOF'
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
    EOF
    '';
    
    dontBuild = true;
  };
in
{
  # Neovim config from merged derivation
  home.file.".config/nvim".source = nvim-with-custom;

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
}
