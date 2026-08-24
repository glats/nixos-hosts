{ config
, pkgs
, lib
, ...
}:

let
  domain = "glats.org";

  # Standard security headers block. frameOption = SAMEORIGIN | DENY
  secHeaders = frameOption: ''
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Frame-Options ${frameOption} always;
  '';

  # Generate a simple proxy vhost (port + optional locExtra/vhostExtra)
  mkProxyVhost =
    { port
    , locExtra ? ""
    , vhostExtra ? ""
    , frame ? "SAMEORIGIN"
    , basicAuth ? null
    ,
    }:
    {
      useACMEHost = domain;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString port}";
        proxyWebsockets = true;
      }
      // lib.optionalAttrs (locExtra != "") { extraConfig = locExtra; };
      extraConfig = secHeaders frame + vhostExtra;
    }
    // lib.optionalAttrs (basicAuth != null) { basicAuthFile = basicAuth; };

  # ARR-style location extra config: standard headers + 90s timeouts
  arrLocExtra = ''
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_connect_timeout 90s;
    proxy_send_timeout 90s;
    proxy_read_timeout 90s;
  '';

  # Authelia-protected location extra config
  autheliaLocExtra = ''
    auth_request /internal/authelia/authz;
    auth_request_set $auth_status $upstream_status;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_connect_timeout 90s;
    proxy_send_timeout 90s;
    proxy_read_timeout 90s;
    error_page 401 = @auth_redirect;
  '';

  # Authelia-protected vhost helper (like mkProxyVhost but with auth)
  mkAutheliaVhost = { port, domain }:
    let
      locExtra = ''
        auth_request /internal/authelia/authz;
        auth_request_set $auth_status $upstream_status;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 90s;
        proxy_send_timeout 90s;
        proxy_read_timeout 90s;
        error_page 401 = @auth_redirect;
      '';
    in
    {
      useACMEHost = "glats.org";
      forceSSL = true;

      locations."/internal/authelia/authz" = {
        proxyPass = "http://127.0.0.1:9091/api/verify";
        extraConfig = ''
          internal;
          proxy_pass_request_body off;
          proxy_set_header Content-Length "";
          proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
          proxy_set_header X-Real-IP $remote_addr;
        '';
      };

      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString port}";
        proxyWebsockets = true;
        extraConfig = locExtra;
      };

      locations."@auth_redirect" = {
        return = "302 https://auth.glats.org/?rd=https://${domain}$request_uri";
      };

      extraConfig = secHeaders "SAMEORIGIN";
    };

  # ARR stack - data-driven via port mapping
  arrServices = {
    radarr = 7878;
    sonarr = 8989;
    prowlarr = 9696;
    bazarr = 6767;
  };
  arrVhosts = lib.mapAttrs'
    (name: port: {
      name = "${name}.${domain}";
      value = mkProxyVhost {
        inherit port;
        locExtra = arrLocExtra;
      };
    })
    arrServices;

  # Qbit has extra X-Real-IP and X-Forwarded-For headers
  qbitLocExtra = ''
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_connect_timeout 90s;
    proxy_send_timeout 90s;
    proxy_read_timeout 90s;
  '';

  # Seerr has extra X-Real-IP header
  seerrLocExtra = ''
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_connect_timeout 90s;
    proxy_send_timeout 90s;
    proxy_read_timeout 90s;
  '';
in
{
  security.acme = {
    acceptTerms = true;
    defaults.email = "glats.walker@gmail.com";
    defaults.dnsProvider = "cloudflare";
    defaults.environmentFile = config.sops.secrets."cloudflare_dns_api_token".path;

    certs."glats.org" = {
      domain = "glats.org";
      extraDomainNames = [ "*.glats.org" ];
      dnsPropagationCheck = true;
      group = "nginx";
    };
  };

  services.nginx = {
    enable = true;
    package = pkgs.nginx.override {
      modules = [ pkgs.nginxModules.fancyindex ];
    };
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;

    commonHttpConfig = ''
      proxy_headers_hash_max_size 1024;
    '';

    clientMaxBodySize = "100g";

    virtualHosts = {
      "localhost" = {
        listen = [
          {
            addr = "127.0.0.1";
            port = 80;
          }
          {
            addr = "172.16.0.5";
            port = 80;
          }
        ];
        serverName = "localhost 172.16.0.5";

        locations."/" = {
          root = "/srv/glats/nginx/html";
          index = "index.html";
          extraConfig = ''
            try_files $uri $uri/ =404;
          '';
        };

        locations."/grupazo" = {
          root = "/srv/glats/nginx/html";
          extraConfig = ''
            autoindex on;
          '';
        };

        extraConfig = ''
          # uploads/ - fancyindex for local network
          location /uploads/ {
            alias /run/media/stuff/droppy/nginx/;
            fancyindex on;
            fancyindex_exact_size off;
            fancyindex_localtime on;
            fancyindex_show_dotfiles off;
          }

          # files/ - fancyindex for local network
          location /files/ {
            alias /run/media/stuff/droppy/nginx/;
            fancyindex on;
            fancyindex_exact_size off;
            fancyindex_localtime on;
            fancyindex_show_dotfiles off;
          }

          # Security headers
          ${secHeaders "DENY"}
        '';
      };

      "glats.org" = {
        useACMEHost = "glats.org";
        forceSSL = true;

        locations."/" = {
          root = "/srv/glats/nginx/html";
          index = "index.html";
          extraConfig = ''
            try_files $uri $uri/ =404;
          '';
        };

        locations."/grupazo" = {
          root = "/srv/glats/nginx/html";
          extraConfig = ''
            autoindex on;
          '';
        };

        extraConfig = ''
          # uploads/ - autoindex restricted to local network, files accessible to all
          location /uploads/ {
            alias /run/media/stuff/droppy/nginx/;

            # Directory listing only for local network
            location = /uploads/ {
              allow 172.16.0.0/24;
              allow 127.0.0.1;
              deny all;
              autoindex on;
            }
          }

          # files/ - autoindex restricted to local network, files accessible to all
          location /files/ {
            alias /run/media/stuff/droppy/nginx/;

            # Directory listing only for local network
            location = /files/ {
              allow 172.16.0.0/24;
              allow 127.0.0.1;
              deny all;
              autoindex on;
            }
          }

          ${secHeaders "DENY"}
          add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        '';
      };

      "jelly.${domain}" = {
        useACMEHost = "glats.org";
        forceSSL = true;

        locations."/" = {
          proxyPass = "http://127.0.0.1:8096";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header X-Forwarded-Protocol $scheme;
            proxy_set_header X-Forwarded-Host $host;

            # Disable buffering when the nginx proxy gets very resource heavy upon streaming
            proxy_buffering off;

            # Streaming can have long pauses between data
            proxy_read_timeout 3600s;
            proxy_send_timeout 3600s;
          '';
        };

        locations."/socket" = {
          proxyPass = "http://127.0.0.1:8096/socket";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header X-Forwarded-Protocol $scheme;
            proxy_set_header X-Forwarded-Host $host;

            # WebSocket connections need long timeouts
            proxy_read_timeout 3600s;
            proxy_send_timeout 3600s;
          '';
        };

        extraConfig = secHeaders "SAMEORIGIN";
      };

      "gonic.${domain}" = {
        useACMEHost = "glats.org";
        forceSSL = true;

        locations."/" = {
          proxyPass = "http://127.0.0.1:4747";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_cookie_path / "/; Secure";
            proxy_set_header X-Forwarded-Host $host;
          '';
        };

        extraConfig = secHeaders "SAMEORIGIN";
      };

      "tty.${domain}" = {
        useACMEHost = "glats.org";
        forceSSL = true;

        locations."/" = {
          proxyPass = "http://127.0.0.1:9004";
          proxyWebsockets = true;
        };

        extraConfig = secHeaders "SAMEORIGIN";
      };

      "guac.${domain}" = {
        useACMEHost = "glats.org";
        forceSSL = true;

        locations."/" = {
          proxyPass = "http://127.0.0.1:9003/guacamole/";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_buffering off;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_cookie_path /guacamole/ /;

            # Guacamole needs WebSockets
            proxy_read_timeout 3600s;
            proxy_send_timeout 3600s;
          '';
        };

        extraConfig = secHeaders "SAMEORIGIN";
      };

      "code.${domain}" = {
        useACMEHost = "glats.org";
        forceSSL = true;

        locations."/" = {
          proxyPass = "http://127.0.0.1:9008";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            # proxy_set_header Host removed - nginx sets it automatically
            proxy_set_header X-NginX-Proxy true;
            proxy_read_timeout 43200000;
          '';
        };

        extraConfig = secHeaders "SAMEORIGIN";
      };

      "file.${domain}" = {
        useACMEHost = "glats.org";
        forceSSL = true;

        # Basic auth (htpasswd)
        basicAuthFile = "/srv/glats/nginx/.htpasswd";

        locations."/" = {
          proxyPass = "http://127.0.0.1:5091";
          proxyWebsockets = true;
          extraConfig = ''
            # Large uploads
            client_max_body_size 100g;
            proxy_request_buffering off;
            proxy_buffering off;
            proxy_connect_timeout 300s;
            proxy_read_timeout 43200s;
            proxy_send_timeout 43200s;
          '';
        };

        extraConfig = secHeaders "SAMEORIGIN";
      };

      "drop.${domain}" = {
        useACMEHost = "glats.org";
        forceSSL = true;

        # Large uploads + long-running connections
        extraConfig = ''
          client_max_body_size 100g;
          client_body_timeout 43200s;
          send_timeout 43200s;

          ${secHeaders "SAMEORIGIN"}
        '';

        locations."/" = {
          proxyPass = "http://127.0.0.1:9002";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Real-Port $remote_port;
            proxy_cache off;
            proxy_buffering off;
            proxy_redirect off;
            proxy_request_buffering off;
            proxy_ignore_client_abort on;
            proxy_connect_timeout 300s;
            proxy_read_timeout 43200s;
            proxy_send_timeout 43200s;
          '';
        };
      };

      "repo.${domain}" = {
        useACMEHost = "glats.org";
        forceSSL = true;
        root = "/srv/glats/nginx/repo";

        locations."/linux/" = {
          tryFiles = "$uri $uri/ =404";
          extraConfig = ''
            autoindex on;
          '';
        };

        locations."/" = {
          return = "404";
        };

        extraConfig = ''
          add_header X-Content-Type-Options nosniff always;
          add_header X-Frame-Options DENY always;
        '';
      };

      "maquiroot.${domain}" = {
        useACMEHost = "glats.org";
        forceSSL = true;
        root = "/srv/glats/nginx/maquiroot";

        locations."/" = {
          tryFiles = "$uri $uri/ =404";
          extraConfig = ''
            autoindex on;
            autoindex_exact_size on;
            autoindex_localtime on;
            autoindex_format html;
          '';
        };

        extraConfig = ''
          add_header X-Content-Type-Options nosniff always;
          add_header X-Frame-Options DENY always;

          # Large file support for rootfs tarballs (3-4GB)
          client_max_body_size 0;
          proxy_request_buffering off;
        '';
      };

      "qbit.${domain}" = mkProxyVhost {
        port = 8080;
        locExtra = qbitLocExtra;
      };

      "seerr.${domain}" = mkProxyVhost {
        port = 5055;
        locExtra = seerrLocExtra;
      };

      "roms.${domain}" = mkProxyVhost {
        port = 8081;
        locExtra = arrLocExtra;
      };

      "auth.${domain}" = {
        useACMEHost = "glats.org";
        forceSSL = true;

        locations."/" = {
          proxyPass = "http://127.0.0.1:9091";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $host;
          '';
        };

        extraConfig = secHeaders "SAMEORIGIN";
      };

      "openfang.${domain}" = {
        useACMEHost = "glats.org";
        forceSSL = true;

        # Internal authelia verification endpoint (no access from outside)
        locations."/internal/authelia/authz" = {
          proxyPass = "http://127.0.0.1:9091/api/verify";
          extraConfig = ''
            internal;
            proxy_pass_request_body off;
            proxy_set_header Content-Length "";
            proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
            proxy_set_header X-Real-IP $remote_addr;
          '';
        };

        # Bypass locations - API and WebSocket don't use auth_request
        locations."/api/" = {
          proxyPass = "http://127.0.0.1:50051";
          proxyWebsockets = true;
          extraConfig = ''
            # proxy_set_header Host removed - nginx sets it automatically
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };

        locations."/v1/" = {
          proxyPass = "http://127.0.0.1:50051";
          proxyWebsockets = true;
          extraConfig = ''
            # proxy_set_header Host removed - nginx sets it automatically
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };

        locations."/ws" = {
          proxyPass = "http://127.0.0.1:50051/ws";
          proxyWebsockets = true;
          extraConfig = ''
            # proxy_set_header Host removed - nginx sets it automatically
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_read_timeout 86400s;
            proxy_send_timeout 86400s;
          '';
        };

        # Main location - requires auth via auth_request
        locations."/" = {
          proxyPass = "http://127.0.0.1:50051";
          proxyWebsockets = true;
          extraConfig = ''
            auth_request /internal/authelia/authz;
            auth_request_set $auth_status $upstream_status;
            # proxy_set_header Host removed - nginx sets it automatically
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            error_page 401 = @auth_redirect;
          '';
        };

        # Redirect unauthenticated users to Authelia login
        locations."@auth_redirect" = {
          return = "302 https://auth.glats.org/?rd=https://openfang.glats.org$request_uri";
        };

        extraConfig = secHeaders "SAMEORIGIN";
      };

      # oai.glats.org: public reverse proxy in front of the loopback-only
      # OpenAI-compatible gateway (services.opencodeProxy on rog).
      # Only /v1/* is exposed; admin/UI/health routes are NOT proxied
      # to anything public, per the opencode-runtime-proxy spec.
      "oai.${domain}" = {
        useACMEHost = "glats.org";
        forceSSL = true;

        # Explicit deny for anything that is NOT /v1 — keeps admin and
        # health endpoints loopback-only even if a typo path matches.
        extraConfig = ''
          # Lock to OpenAI-compatible runtime surface only.
          location / {
            return 404;
          }

          # Long-lived streaming/responses from upstream LLM APIs.
          proxy_read_timeout 3600s;
          proxy_send_timeout 3600s;
          proxy_connect_timeout 60s;

          ${secHeaders "DENY"}
        '';

        locations."/v1/" = {
          proxyPass = "http://127.0.0.1:4010";
          proxyWebsockets = false;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header Authorization "";
            proxy_set_header X-OpenAI-Proxy-Key $http_x_openai_proxy_key;
          '';
        };

        # Convenience: /v1/models so a curl smoke test works without
        # trailing-slash confusion.
        locations."/v1/models" = {
          proxyPass = "http://127.0.0.1:4010/v1/models";
          proxyWebsockets = false;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header Authorization "";
            proxy_set_header X-OpenAI-Proxy-Key $http_x_openai_proxy_key;
          '';
        };
      };
    }
    // arrVhosts;
  };

  systemd.services.nginx = {
    after = [ "acme-glats.org.service" ];
    wants = [ "acme-glats.org.service" ];
  };
}
