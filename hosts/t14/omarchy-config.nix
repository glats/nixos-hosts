{ ... }:

{

  omarchy = {
    username = "glats";
    full_name = "Glats";
    email_address = "glats@local";

    theme = "glats";

    wifi.backend = "nm-iwd";

    monitors = [ "eDP-1,preferred,auto,1" ];

    hyprland.lidSwitch.enable = false;

    scale = 1;

    browser = "brave";
    terminal = "ghostty";

    firewall.enable = false;

    wayvnc = {
      enable = true;
      output = "DP-3";
    };

    greeter = {
      type = "regreet";
      focusMonitor = "LEN G24";
      keyboard = {
        layouts = [
          "es"
          "latam"
        ];
        options = "grp:alt_shift_toggle";
      };
      monitors = [
        "desc:Lenovo Group Limited LEN G24-10 U5B4GWF1,1920x1080@60,1080x420,1"
        "desc:AOC 24P1W1 OTNQ4HA000101,1920x1080@60,0x0,1,transform,1"
        "desc:AOC 2470W GGZM3HA438259,1920x1080@60,3000x420,1"
      ];
      cursor.theme = "Bibata-Modern-Ice";

      wayvnc = {
        enable = true;
        output = "DP-3";
      };
      layoutIndicator.enable = true;
    };
  };
}
