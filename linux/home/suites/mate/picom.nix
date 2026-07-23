{ ... }:

{
  services.picom = {
    enable = true;
    backend = "xrender";
    vSync = true;
    shadow = true;
    fade = false;

    settings = {
      detect-client-opacity = true;
      detect-transient = true;
      detect-client-leader = true;
      detect-rounded-corners = true;
      unredir-if-possible = true;

      shadow-exclude = [
        "window_type = 'menu'"
        "window_type = 'dropdown_menu'"
        "window_type = 'popup_menu'"
        "window_type = 'utility'"
        "_GTK_FRAME_EXTENTS"
        "argb && (override_redirect || wmwin)"
      ];

      wintypes = {
        dropdown_menu = {
          shadow = false;
        };
        popup_menu = {
          shadow = false;
        };
        menu = {
          shadow = false;
        };
        utility = {
          shadow = false;
        };
        tooltip = {
          shadow = false;
        };
      };
    };
  };
}
