{ config, pkgs, ... }:

let
  tokenFile = config.sops.secrets."cloudflare_cli_api_token".path;

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
