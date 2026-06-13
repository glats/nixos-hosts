# T14 starship prompt config.
#
# Personal prompt configuration ported from the external drive's
# `~/.config/starship.toml`. Omarchy only enables starship with no
# custom config, so this module is a true additive delta.
#
# Key choices:
#   * Cyan prompt color (italic branch, bold character, cyan directory)
#   * Two-level directory truncation with ellipsis prefix
#   * Git status symbols for ahead/behind/modified/etc.
#   * `command_timeout = 200` for fast prompt updates
#
# Note: starship template variables (`${count}`, `${ahead_count}`, etc.)
# must be escaped in Nix strings with `\${` to prevent Nix from
# attempting interpolation at evaluation time.  The home-manager
# `programs.starship.settings` attrset is rendered to a TOML config
# file at build time, so the escapes are stripped and the TOML
# receives the literal `${count}` etc. that starship expects.
{ ... }:

{
  programs.starship = {
    enable = true;
    settings = {
      add_newline = true;
      command_timeout = 200;
      format = "[$directory$git_branch$git_status]($style)$character";

      character = {
        error_symbol = "[✗](bold cyan)";
        success_symbol = "[❯](bold cyan)";
      };

      directory = {
        truncation_length = 2;
        truncation_symbol = "…/";
        repo_root_style = "bold cyan";
        repo_root_format = "[$repo_root]($repo_root_style)[$path]($style)[$read_only]($read_only_style) ";
      };

      git_branch = {
        format = "[$branch]($style) ";
        style = "italic cyan";
      };

      git_status = {
        format = "[$all_status]($style)";
        style = "cyan";
        ahead = "⇡\${count} ";
        diverged = "⇕⇡\${ahead_count}⇣\${behind_count} ";
        behind = "⇣\${count} ";
        conflicted = " ";
        up_to_date = " ";
        untracked = "? ";
        modified = " ";
        stashed = "";
        staged = "";
        renamed = "";
        deleted = "";
      };
    };
  };
}
