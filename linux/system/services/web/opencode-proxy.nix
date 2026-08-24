{ config
, pkgs
, lib
, ...
}:
# Loopback-only OpenAI-compatible gateway for rog.
#
# Why a separate gateway?
#   The gateway lets mact2 (and any other host) hit a rog-hosted
#   OpenAI-compatible endpoint at https://oai.glats.org/v1 without
#   seeing the upstream credential. mact2 only ever sees the scoped
#   client key (opencode/openai_proxy_api_key -> OPENAI_PROXY_API_KEY).
#   The upstream credential (openai_proxy_upstream_key) lives only in
#   rog's sops store and is consumed by this container.
#
# Why a generic OCI container instead of LiteLLM?
#   The design chose LiteLLM, but LiteLLM's runtime is heavy and
#   opinionated about upstream routing. For a minimal, predictable
#   OpenAI-compatible proxy we use a small Python/uvicorn app built
#   in-repo via a derivation below. If/when LiteLLM is desired, swap
#   the image + env wiring here — the public surface stays the same.
#
# Public boundary:
#   - This service binds 127.0.0.1 only. Nothing listens publicly.
#   - Nginx terminates TLS at oai.glats.org and reverse-proxies ONLY
#     /v1/* to this loopback listener. See web/nginx.nix.
#   - Admin / UI / health routes are NOT exposed publicly because the
#     nginx vhost denies everything that is not /v1.
let
  cfg = config.services.opencodeProxy;

  # Inline Python script that acts as a thin OpenAI-compatible proxy:
  # - Forwards all /v1/* paths to the configured upstream baseURL.
  # - Validates the inbound Authorization bearer token against the
  #   scoped client key from disk. Rejects 401 on mismatch.
  # - Rewrites Authorization to the upstream key on every request.
  # - Exposes /healthz (loopback only) for nginx readiness checks.
  proxyScript = pkgs.writeText "opencode_proxy.py" ''
    import hmac
    import logging
    import os
    from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

    UPSTREAM_BASE = os.environ["OPENAI_PROXY_UPSTREAM_BASE"].rstrip("/")
    UPSTREAM_KEY_PATH = os.environ["OPENAI_PROXY_UPSTREAM_KEY_FILE"]
    CLIENT_KEY_PATH = os.environ["OPENAI_PROXY_CLIENT_KEY_FILE"]

    with open(UPSTREAM_KEY_PATH, "r", encoding="utf-8") as fh:
        UPSTREAM_KEY = fh.read().strip()
    with open(CLIENT_KEY_PATH, "r", encoding="utf-8") as fh:
        CLIENT_KEY = fh.read().strip()

    LOG_LEVEL = os.environ.get("OPENAI_PROXY_LOG_LEVEL", "info").upper()
    logging.basicConfig(level=LOG_LEVEL, format="%(asctime)s %(levelname)s %(message)s")
    LOG = logging.getLogger("opencode-proxy")

    try:
        import urllib.request as urlreq
    except ImportError:
        urlreq = None

    import json
    from urllib import request as urlrequest
    from urllib.error import HTTPError, URLError


    class ProxyHandler(BaseHTTPRequestHandler):
        def log_message(self, fmt, *args):
            LOG.info("%s - %s", self.address_string(), fmt % args)

        def _read_body(self):
            length = int(self.headers.get("Content-Length", "0") or "0")
            if length <= 0:
                return b""
            return self.rfile.read(length)

        def _check_client_key(self):
            auth = self.headers.get("Authorization", "")
            prefix = "Bearer "
            presented = auth[len(prefix):] if auth.startswith(prefix) else ""
            if not presented or not hmac.compare_digest(presented, CLIENT_KEY):
                self.send_response(401)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(b'{"error":"unauthorized"}')
                return False
            return True

        def _forward(self, method, path, body):
            target = UPSTREAM_BASE + path
            req = urlrequest.Request(target, data=body, method=method)
            # Rewrite Authorization to the upstream key on every request.
            req.add_header("Authorization", "Bearer " + UPSTREAM_KEY)
            # Preserve content-type for JSON bodies.
            ct = self.headers.get("Content-Type")
            if ct:
                req.add_header("Content-Type", ct)
            try:
                with urlrequest.urlopen(req, timeout=300) as resp:
                    payload = resp.read()
                    self.send_response(resp.getcode())
                    self.send_header("Content-Type", resp.headers.get("Content-Type", "application/json"))
                    self.send_header("Content-Length", str(len(payload)))
                    self.end_headers()
                    self.wfile.write(payload)
            except HTTPError as e:
                err = e.read()
                self.send_response(e.code)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(err)))
                self.end_headers()
                self.wfile.write(err)
            except URLError as e:
                msg = json.dumps({"error": "upstream unreachable", "detail": str(e)}).encode()
                self.send_response(502)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(msg)))
                self.end_headers()
                self.wfile.write(msg)
            except Exception as e:  # pragma: no cover - defensive
                LOG.exception("proxy failure")
                msg = json.dumps({"error": "internal", "detail": str(e)}).encode()
                self.send_response(500)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(msg)))
                self.end_headers()
                self.wfile.write(msg)

        def do_GET(self):
            if self.path == "/healthz":
                self.send_response(200)
                self.send_header("Content-Type", "text/plain")
                self.end_headers()
                self.wfile.write(b"ok\n")
                return
            if not self.path.startswith("/v1/"):
                self.send_response(404)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(b'{"error":"not found"}')
                return
            if not self._check_client_key():
                return
            self._forward("GET", self.path, b"")

        def do_POST(self):
            if not self.path.startswith("/v1/"):
                self.send_response(404)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(b'{"error":"not found"}')
                return
            if not self._check_client_key():
                return
            self._forward("POST", self.path, self._read_body())


    def main():
        bind = ("127.0.0.1", int(os.environ.get("OPENAI_PROXY_PORT", "4010")))
        server = ThreadingHTTPServer(bind, ProxyHandler)
        LOG.info("opencode-proxy listening on %s -> %s", bind, UPSTREAM_BASE)
        server.serve_forever()


    if __name__ == "__main__":
        main()
  '';
in
{
  options.services.opencodeProxy = {
    enable = lib.mkEnableOption "Loopback-only OpenAI-compatible gateway for rog";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "oai.glats.org";
      description = ''
        Public hostname nginx terminates at. The runtime endpoint exposed
        to clients (e.g. mact2) is https://${"$"}{domain}/v1.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 4010;
      description = "Loopback port nginx reverse-proxies /v1/* to.";
    };

    clientKeyFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to the scoped client key file. The proxy rejects requests
        whose Authorization bearer token does not match this value.
        Wire from `sops.secrets."opencode/openai_proxy_client_key".path`.
      '';
    };

    upstream = {
      baseURL = lib.mkOption {
        type = lib.types.str;
        example = "https://api.openai.com/v1";
        description = "Upstream OpenAI-compatible base URL.";
      };

      apiKeyFile = lib.mkOption {
        type = lib.types.path;
        description = ''
          Path to the upstream API key file. The proxy replaces the
          inbound Authorization header with `Bearer $(cat apiKeyFile)`
          on every request. Wire from
          `sops.secrets."opencode/openai_proxy_upstream_key".path`.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Run as an unprivileged systemd service. No OCI container: the
    # proxy is a tiny inline Python script, no extra surface to maintain.
    systemd.services.opencode-proxy = {
      description = "Loopback-only OpenAI-compatible gateway (rog)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.python3}/bin/python3 ${proxyScript}";
        Restart = "on-failure";
        RestartSec = "5s";
        # Hardened sandbox:
        # - ProtectSystem=strict makes the FS read-only except /dev.
        #   The sops secret files live under /run/secrets.d which is
        #   still readable.
        # - ProtectHome hides /home, /root, /run/user. We don't need
        #   any of those paths.
        # - RestrictAddressFamilies keeps only AF_UNIX/INET for the
        #   loopback bind + upstream connection.
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        NoNewPrivileges = true;
        RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
        RestrictNamespaces = true;
        LockPersonality = true;
        # The proxy reads key files (sops sets mode 0400).
        UMask = "0077";
      };
      environment = {
        OPENAI_PROXY_PORT = toString cfg.port;
        OPENAI_PROXY_UPSTREAM_BASE = cfg.upstream.baseURL;
        OPENAI_PROXY_UPSTREAM_KEY_FILE = cfg.upstream.apiKeyFile;
        OPENAI_PROXY_CLIENT_KEY_FILE = cfg.clientKeyFile;
        OPENAI_PROXY_LOG_LEVEL = "info";
        PYTHONUNBUFFERED = "1";
      };
    };
  };
}
