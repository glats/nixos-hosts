{
  config,
  lib,
  pkgs,
  ...
}:

let
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
  users.users.ddclient = {
    isSystemUser = true;
    group = "ddclient";
    description = "Dynamic DNS Client user";
  };
  users.groups.ddclient = { };

  services.ddclient = {
    enable = true;
    protocol = "cloudflare";
    username = "token";
    passwordFile = tokenFile;
    usev4 = "webv4, webv4=ifconfig.io";
    usev6 = "";
    zone = "glats.org";
    domains = [
      "glats.org"
      "*.glats.org"
      "guard.glats.org"
    ];
    extraConfig = ''
      zone=maquilinux.org maquilinux.org,*.maquilinux.org
    '';
  };

  systemd.services.ddclient = {
    restartIfChanged = false;

    serviceConfig = {
      ExecStartPre = lib.mkBefore [ "!${extractToken}" ];
      DynamicUser = lib.mkForce false;
      User = lib.mkForce "ddclient";
      Group = lib.mkForce "ddclient";
      TimeoutStartSec = 120;
    };
  };
}
