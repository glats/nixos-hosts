{ config, lib, pkgs, ... }:

{
  time.timeZone = "America/Santiago";

  environment.etc."timezone".text = "${config.time.timeZone}\n";

  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_TIME = "es_CL.UTF-8";
    };
  };

  console.keyMap = "es";

  services.xserver = {
    xkb.layout = "es";
    xkb.model = "pc105";
  };
}
