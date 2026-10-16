{ lib, ... }:

{
  systemd.settings.Manager = {
    RuntimeWatchdogSec = "0";
    ShutdownWatchdogSec = "0";
  };

  systemd.settings.Manager.DefaultTimeoutStopSec = lib.mkDefault "20s";

  services.journald.extraConfig = ''
    Storage=persistent
    SystemMaxUse=500M
    MaxRetentionSec=2week
  '';
}
