{ ... }:

{
  programs.gh = {
    enable = true;
    settings = {
      version = 1;
      git_protocol = "https";
      prompt = "enabled";
      prefer_editor_prompt = false;
      color_labels = false;
      accessible_colors = false;
      accessible_prompter = false;
      spinner = true;
      aliases = {
        co = "pr checkout";
      };
    };
  };
}
