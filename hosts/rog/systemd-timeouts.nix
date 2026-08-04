{ lib
, ...
}:

{
  # Fix 1: Extend timeouts to prevent exit status 4 in nixos-rebuild switch
  # See: investigation of intermittent systemd-run switch-to-configuration failures
  # Use mkForce to override the oci-containers module defaults
  systemd.services.nginx.serviceConfig.TimeoutStartSec = lib.mkForce "300";
  systemd.services."acme-glats.org".serviceConfig.TimeoutStartSec = lib.mkForce "300";
  systemd.services."docker-droppy".serviceConfig.TimeoutStartSec = lib.mkForce "300";
  systemd.services."docker-guacamoledb".serviceConfig.TimeoutStartSec = lib.mkForce "300";
  systemd.services."docker-jellyfin".serviceConfig.TimeoutStartSec = lib.mkForce "300";
  systemd.services."docker-jellyseerr".serviceConfig.TimeoutStartSec = lib.mkForce "300";

  # Prevent restart loops that consume time during switch
  # Use mkForce because nginx already defines this value
  systemd.services.nginx.startLimitIntervalSec = lib.mkForce 0;
  systemd.services."docker-droppy".startLimitIntervalSec = lib.mkForce 0;
  systemd.services."docker-jellyfin".startLimitIntervalSec = lib.mkForce 0;
  systemd.services."docker-guacamoledb".startLimitIntervalSec = lib.mkForce 0;
  systemd.services."docker-jellyseerr".startLimitIntervalSec = lib.mkForce 0;
}
