{ config, pkgs, ... }:


{
  security.acme = {
    acceptTerms = true;
    defaults.email = "glats.walker@gmail.com";
    defaults.dnsProvider = "cloudflare";
    defaults.environmentFile = config.sops.secrets."cloudflare_api_token".path;

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
          { addr = "127.0.0.1"; port = 80; }
          { addr = "172.16.0.5"; port = 80; }
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
          add_header X-Content-Type-Options nosniff always;
          add_header X-XSS-Protection "1; mode=block" always;
          add_header X-Frame-Options DENY always;
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

          # Security headers
          add_header X-Content-Type-Options nosniff always;
          add_header X-XSS-Protection "1; mode=block" always;
          add_header X-Frame-Options DENY always;
          add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        '';
      };

      "jelly.glats.org" = {
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

        extraConfig = ''
          # Security headers
          add_header X-Content-Type-Options nosniff always;
          add_header X-XSS-Protection "1; mode=block" always;
          add_header X-Frame-Options SAMEORIGIN always;
        '';
      };

      "gonic.glats.org" = {
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

        extraConfig = ''
          # Security headers
          add_header X-Content-Type-Options nosniff always;
          add_header X-XSS-Protection "1; mode=block" always;
          add_header X-Frame-Options SAMEORIGIN always;
        '';
      };

      "tty.glats.org" = {
        useACMEHost = "glats.org";
        forceSSL = true;

        locations."/" = {
          proxyPass = "http://127.0.0.1:9004";
          proxyWebsockets = true;
        };

        extraConfig = ''
          # Security headers
          add_header X-Content-Type-Options nosniff always;
          add_header X-XSS-Protection "1; mode=block" always;
          add_header X-Frame-Options SAMEORIGIN always;
        '';
      };

      "guac.glats.org" = {
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

        extraConfig = ''
          # Security headers
          add_header X-Content-Type-Options nosniff always;
          add_header X-XSS-Protection "1; mode=block" always;
          add_header X-Frame-Options SAMEORIGIN always;
        '';
      };

      "code.glats.org" = {
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

        extraConfig = ''
          # Security headers
          add_header X-Content-Type-Options nosniff always;
          add_header X-XSS-Protection "1; mode=block" always;
          add_header X-Frame-Options SAMEORIGIN always;
        '';
      };

      "file.glats.org" = {
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

        extraConfig = ''
          # Security headers
          add_header X-Content-Type-Options nosniff always;
          add_header X-XSS-Protection "1; mode=block" always;
          add_header X-Frame-Options SAMEORIGIN always;
        '';
      };

      "drop.glats.org" = {
        useACMEHost = "glats.org";
        forceSSL = true;

        # Large uploads + long-running connections
        extraConfig = ''
          client_max_body_size 100g;
          client_body_timeout 43200s;
          send_timeout 43200s;

          # Security headers
          add_header X-Content-Type-Options nosniff always;
          add_header X-XSS-Protection "1; mode=block" always;
          add_header X-Frame-Options SAMEORIGIN always;
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

      "repo.glats.org" = {
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
          # Security headers
          add_header X-Content-Type-Options nosniff always;
          add_header X-Frame-Options DENY always;
        '';
      };

      "maquiroot.glats.org" = {
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
          # Security headers
          add_header X-Content-Type-Options nosniff always;
          add_header X-Frame-Options DENY always;

          # Large file support for rootfs tarballs (3-4GB)
          client_max_body_size 0;
          proxy_request_buffering off;
        '';
      };

      # ============================================================
      # ARR Stack Services
      # ============================================================

      "radarr.glats.org" = {
        useACMEHost = "glats.org";
        forceSSL = true;

        locations."/" = {
          proxyPass = "http://127.0.0.1:7878";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_connect_timeout 90s;
            proxy_send_timeout 90s;
            proxy_read_timeout 90s;
          '';
        };

        extraConfig = ''
          add_header X-Content-Type-Options nosniff always;
          add_header X-XSS-Protection "1; mode=block" always;
          add_header X-Frame-Options SAMEORIGIN always;
        '';
      };

      "sonarr.glats.org" = {
        useACMEHost = "glats.org";
        forceSSL = true;

        locations."/" = {
          proxyPass = "http://127.0.0.1:8989";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_connect_timeout 90s;
            proxy_send_timeout 90s;
            proxy_read_timeout 90s;
          '';
        };

        extraConfig = ''
          add_header X-Content-Type-Options nosniff always;
          add_header X-XSS-Protection "1; mode=block" always;
          add_header X-Frame-Options SAMEORIGIN always;
        '';
      };

      "prowlarr.glats.org" = {
        useACMEHost = "glats.org";
        forceSSL = true;

        locations."/" = {
          proxyPass = "http://127.0.0.1:9696";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_connect_timeout 90s;
            proxy_send_timeout 90s;
            proxy_read_timeout 90s;
          '';
        };

        extraConfig = ''
          add_header X-Content-Type-Options nosniff always;
          add_header X-XSS-Protection "1; mode=block" always;
          add_header X-Frame-Options SAMEORIGIN always;
        '';
      };

      "bazarr.glats.org" = {
        useACMEHost = "glats.org";
        forceSSL = true;

        locations."/" = {
          proxyPass = "http://127.0.0.1:6767";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_connect_timeout 90s;
            proxy_send_timeout 90s;
            proxy_read_timeout 90s;
          '';
        };

        extraConfig = ''
          add_header X-Content-Type-Options nosniff always;
          add_header X-XSS-Protection "1; mode=block" always;
          add_header X-Frame-Options SAMEORIGIN always;
        '';
      };

      "qbit.glats.org" = {
        useACMEHost = "glats.org";
        forceSSL = true;

        locations."/" = {
          proxyPass = "http://127.0.0.1:8080";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_connect_timeout 90s;
            proxy_send_timeout 90s;
            proxy_read_timeout 90s;
          '';
        };

        extraConfig = ''
          add_header X-Content-Type-Options nosniff always;
          add_header X-XSS-Protection "1; mode=block" always;
          add_header X-Frame-Options SAMEORIGIN always;
        '';
      };

      "seerr.glats.org" = {
        useACMEHost = "glats.org";
        forceSSL = true;

        locations."/" = {
          proxyPass = "http://127.0.0.1:5055";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_connect_timeout 90s;
            proxy_send_timeout 90s;
            proxy_read_timeout 90s;
          '';
        };

        extraConfig = ''
          add_header X-Content-Type-Options nosniff always;
          add_header X-XSS-Protection "1; mode=block" always;
          add_header X-Frame-Options SAMEORIGIN always;
        '';
      };

      # ============================================================
      # Authelia SSO
      # ============================================================

      "auth.glats.org" = {
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

        extraConfig = ''
          add_header X-Content-Type-Options nosniff always;
          add_header X-XSS-Protection "1; mode=block" always;
          add_header X-Frame-Options SAMEORIGIN always;
        '';
      };

      "openfang.glats.org" = {
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

        extraConfig = ''
          # Security headers
          add_header X-Content-Type-Options nosniff always;
          add_header X-XSS-Protection "1; mode=block" always;
          add_header X-Frame-Options SAMEORIGIN always;
        '';
      };
    };
  };

  systemd.services.nginx = {
    after = [ "acme-glats.org.service" ];
    wants = [ "acme-glats.org.service" ];
  };
}
