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
    };
  };
}
