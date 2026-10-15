{ config, lib, ... }:

{
  # Create a dedicated user for ddclient (required when not using DynamicUser)
  users.users.ddclient = {
    isSystemUser = true;
    group = "ddclient";
    description = "Dynamic DNS Client user";
  };
  users.groups.ddclient = { };

  # Cloudflare DDNS for every zone served by this host. Only the API token
  # is secret; the record list stays reviewable here. The cloudflare
  # protocol updates existing records only (it never creates them) and
  # preserves each record's proxy setting.
  services.ddclient = {
    enable = true;
    protocol = "cloudflare";
    username = "token";
    passwordFile = config.sops.secrets."cloudflare_dns_api_token".path;
    usev4 = "webv4, webv4=ifconfig.io";
    # IPv4 only: do not start publishing AAAA records.
    usev6 = "";
    zone = "glats.org";
    domains = [
      "glats.org"
      "*.glats.org"
      "guard.glats.org"
    ];
    # Per-host zone override; the global zone above applies to `domains`.
    extraConfig = ''
      zone=maquilinux.org maquilinux.org,*.maquilinux.org
    '';
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
