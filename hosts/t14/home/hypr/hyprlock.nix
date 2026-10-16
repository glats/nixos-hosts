{ lib, ... }:

{
  programs.hyprlock = {
    enable = true;
    settings = {
      source = "~/.config/omarchy/current/theme/hyprlock.conf";

      background = {
        color = lib.mkForce "$color";
      };

      input-field = {
        size = lib.mkForce "650, 100";
        inner_color = lib.mkForce "$inner_color";
        outer_color = lib.mkForce "$outer_color";
        font_family = lib.mkForce "Source Sans 3";
        font_color = lib.mkForce "$font_color";
        placeholder_text = lib.mkForce "Enter Password";
        check_color = lib.mkForce "$check_color";
      };

      auth = {
        fingerprint.enabled = lib.mkForce false;
      };
    };
  };
}
