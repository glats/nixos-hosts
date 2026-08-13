{ config, lib, ... }:

{
  # Create a dedicated user for ddclient (required when not using DynamicUser)
  users.users.ddclient = {
    isSystemUser = true;
    group = "ddclient";
    description = "Dynamic DNS Client user";
  };
  users.groups.ddclient = { };

  services.ddclient = {
    enable = true;
    configFile = config.sops.secrets."ddclient".path;
  };

  # Override to use the real user instead of DynamicUser
  # This fixes the "install: invalid user" error
  systemd.services.ddclient = {
    # Do not restart during activation: if a one-shot run is stuck, a
    # restart's stop job times out (TimeoutStopSec) and marks the unit
    # failed, which makes switch-to-configuration abort with exit 4.
    # The timer picks up config changes within the next 10 minutes.
    restartIfChanged = false;

    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = lib.mkForce "ddclient";
      Group = lib.mkForce "ddclient";
      # One-shot units default to TimeoutStartSec=infinity: a hung run
      # (stalled network fetch) stays "activating" forever. Cap it so
      # systemd kills the leftover processes and the next timer run
      # starts fresh.
      TimeoutStartSec = 120;
    };
  };
}
