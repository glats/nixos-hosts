{ ... }:

{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      add_newline = false;
      command_timeout = 1000;
      format = "$username$hostname:$directory$character";
      right_format = "$git_branch$git_status$nix_shell$cmd_duration";
      username = {
        show_always = true;
        format = "$user";
      };
      hostname = {
        ssh_only = false;
        format = "@$hostname";
      };
      directory = {
        format = "$path/ ";
        truncation_length = 0;
        truncate_to_repo = false;
        home_symbol = "~";
      };
      character = {
        format = "$symbol ";
        success_symbol = ">";
        error_symbol = ">";
      };
      cmd_duration.min_time = 2000;
      nix_shell.format = " [$symbol$state]($style)";
    };
  };
}
