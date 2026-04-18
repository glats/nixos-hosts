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
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = lib.mkForce "ddclient";
      Group = lib.mkForce "ddclient";
    };
  };
}
