{ ... }:

{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      add_newline = false;
      command_timeout = 1000;
      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };
      directory.truncation_length = 3;
      git_status.disabled = false;
      cmd_duration.min_time = 2000;
      nix_shell.format = "via [$symbol$state]($style) ";
    };
  };
}
