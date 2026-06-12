# T14 Starship prompt configuration.
#
# Minimal, fast prompt tuned for the laptop screen — single line,
# no module bloat.  Activated by omarchy's HM module via
# programs.starship.enableZshIntegration in zsh.nix (or by setting
# `eval "$(starship init zsh)"` in .zshrc if integration is off).
#
# Layout: directory -> git branch -> runtime language -> symbol.
# No python/conda/java nodes — they slow down startup and we never
# use them in interactive shells.
{ ... }:

{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      # Top-level prompt format (single-line to keep nixfmt happy).
      # Modules from left to right:
      #   bg-#a6e3a1 / fg-#1e1e2e  - os / username (green block)
      #   bg-#45475a / fg-#a6e3a1  - directory (green text)
      #   bg-#89b4fa / fg-#45475a  - git branch + status (blue)
      #   bg-#45475a / fg-#89b4fa  - nodejs (blue text)
      #   bg-#f38ba8 / fg-#45475a  - time (red)
      format = "[░▒▓](#a6e3a1)$os$username[░▒▓](bg:#45475a fg:#a6e3a1)$directory[░▒▓](fg:#45475a bg:#89b4fa)$git_branch$git_status[░▒▓](fg:#89b4fa bg:#45475a)$nodejs$rust$golang$php[░▒▓](fg:#45475a bg:#f38ba8)$time[░▒▓](fg:#f38ba8)";

      # Disable the newline before the prompt (saves vertical space)
      add_newline = false;

      # Palettes for module color customisation
      palettes = {
        glats = {
          color_fg0 = "#1e1e2e";
          color_fg1 = "#cdd6f4";
          color_red = "#f38ba8";
          color_green = "#a6e3a1";
          color_yellow = "#f9e2af";
          color_blue = "#89b4fa";
          color_magenta = "#f5c2e7";
          color_cyan = "#94e2d5";
          color_white = "#cdd6f4";
        };
      };

      # Module: directory
      directory = {
        style = "fg:#a6e3a1 bg:#45475a";
        format = "[ $path ]($style)";
        truncation_length = 3;
        truncation_symbol = "…/";
      };

      # Module: git_branch
      git_branch = {
        style = "bg:#89b4fa";
        format = "[ $symbol $branch(:$remote_branch) ]($style)";
        symbol = "";
      };

      # Module: git_status
      git_status = {
        style = "bg:#89b4fa";
        format = "[$all_status$ahead_behind ]($style)";
        conflicted = "⚠ ";
        ahead = "⇡";
        behind = "⇣";
        diverged = "⇕";
        untracked = "?";
        stashed = "$";
        modified = "!";
        staged = "+";
        renamed = "»";
        deleted = "✘";
      };

      # Module: nodejs (only when in a node project)
      nodejs = {
        style = "bg:#45475a";
        format = "[ $symbol ($version) ]($style)";
        symbol = "";
        detect_extensions = [
          "js"
          "ts"
          "mjs"
          "cjs"
        ];
        detect_files = [
          "package.json"
          ".node-version"
        ];
      };

      # Time (right side)
      time = {
        style = "fg:#f38ba8 bg:#45475a";
        format = "[ $time ]($style)";
        time_format = "%R";
        disabled = false;
      };
    };
  };
}
