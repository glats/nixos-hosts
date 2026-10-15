{
  config,
  lib,
  pkgs,
  ...
}:

let
  # The shared sops secret is the ACME (lego) environment file:
  # `CLOUDFLARE_DNS_API_TOKEN=<token>`. ddclient needs the bare token, so a
  # root pre-start step extracts it into the private runtime directory.
  tokenFile = "/run/ddclient/cloudflare-token";
  extractToken = pkgs.writeShellScript "ddclient-extract-cloudflare-token" ''
    set -eu
    umask 077
    ${pkgs.gnused}/bin/sed -n 's/^CLOUDFLARE_DNS_API_TOKEN=//p' \
      ${config.sops.secrets."cloudflare_dns_api_token".path} > ${tokenFile}
    if [ ! -s ${tokenFile} ]; then
      echo "CLOUDFLARE_DNS_API_TOKEN missing from the sops secret" >&2
      exit 1
    fi
  '';
in
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
    passwordFile = tokenFile;
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
      # Runs before the module's pre-start, which reads passwordFile.
      ExecStartPre = lib.mkBefore [ "!${extractToken}" ];
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
