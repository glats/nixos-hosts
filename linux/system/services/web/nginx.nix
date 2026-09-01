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

      # tun.glats.org — VLESS+WS private-link endpoint with cover page.
      # The unguessable WS path is the ONLY path nginx proxies to the
      # loopback sing-box listener; every other request resolves to the
      # cover page under /srv/glats/nginx/html (matches the glats.org
      # vhost static-root pattern). generated-once random hex (NOT
      # sops) — obscurity, not authentication. The same value is the
      # `transport.path` in linux/system/services/network/sing-box-link.nix
      # and the `path` in the mact2 client + phone share link.
      "tun.${domain}" = {
        useACMEHost = "glats.org";
        forceSSL = true;

        # Cover page at /
        locations."/" = {
          root = "/srv/glats/nginx/html";
          index = "index.html";
          extraConfig = ''
            try_files $uri $uri/ =404;
          '';
        };

        # Single proxy for the VLESS+WS path. proxyWebsockets=true
        # expands to the standard proxy_set_header Upgrade / Connection
        # upgrade / proxy_http_version 1.1 trio.
        #
        # Upgrade guard (verify finding G12): a request to this path
        # WITHOUT a WebSocket upgrade must never reach sing-box — its
        # `handshake error: bad "Upgrade" header` body is a tell-tale
        # tunnel artifact. Spec scenario: every path on this vhost that
        # is not a valid WS upgrade behaves like the cover site.
        # `if` + `return` is the classic safe rewrite-module guard: it
        # 404s (rendered as the cover page by the error_page below)
        # during the rewrite phase, before any proxying; real WS
        # upgrades ($http_upgrade == "websocket") fall through to
        # proxyPass untouched.
        locations."/ed59280aa562f4b7eba4519e3c316e24" = {
          proxyPass = "http://127.0.0.1:4011";
          proxyWebsockets = true;
          extraConfig = ''
            if ($http_upgrade != "websocket") { return 404; }
            proxy_read_timeout 3600s;
            proxy_send_timeout 3600s;
          '';
        };

        extraConfig = ''
          # G12: nginx-generated 404s (guarded WS path above + stray
          # paths) must present the cover page, never a bare nginx error
          # page. Upstream (sing-box) responses pass through unchanged —
          # proxy_intercept_errors stays off — so the tunnel is unaffected.
          error_page 404 /index.html;

          ${secHeaders "DENY"}
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

        # Direct-access locations - API and WebSocket skip auth_request
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
    }
    // arrVhosts;
  };

  systemd.services.nginx = {
    after = [ "acme-glats.org.service" ];
    wants = [ "acme-glats.org.service" ];
  };
}
