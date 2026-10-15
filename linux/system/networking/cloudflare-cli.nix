{ config, pkgs, ... }:

let
  tokenFile = config.sops.secrets."cloudflare_cli_api_token".path;

  # flarectl reads CF_API_TOKEN; load it from sops so no shell export is
  # needed. Expects the host to declare the cloudflare_cli_api_token secret,
  # which is the ACME (lego) env file `CLOUDFLARE_DNS_API_TOKEN=<token>`.
  flarectl = pkgs.writeShellApplication {
    name = "flarectl";
    text = ''
      if [ -z "''${CF_API_TOKEN:-}" ] && [ -r ${tokenFile} ]; then
        token="$(< ${tokenFile})"
        CF_API_TOKEN="''${token#CLOUDFLARE_DNS_API_TOKEN=}"
        export CF_API_TOKEN
      fi
      exec ${pkgs.flarectl}/bin/flarectl "$@"
    '';
  };
in
{
  environment.systemPackages = [ flarectl ];
}
