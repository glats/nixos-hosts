{ ... }:

{
  programs.alacritty = {
    enable = true;
    settings = {
      colors.draw_bold_text_with_bright_colors = true;
      window.startup_mode = "Maximized";
    };
  };
}
