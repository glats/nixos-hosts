# Design: WireGuard web manager (wg-easy) — OIDC via Authelia

## Technical Approach

Replace the declarative WireGuard stack on `rog` with one wg-easy (`:15`) oci-container that owns `wg0`, NAT, and peers. Authentication is **Authelia OIDC single sign-on** — wg-easy's own password login is gone (v15 removed `PASSWORD`/`PASSWORD_HASH`; setting either crashes the container with "migrate from 14 to 15"). `DISABLE_PASSWORD_AUTH=true` + `OAUTH_AUTO_LAUNCH=oidc` make Authelia the only login. nginx serves `wg.glats.org` as a plain TLS proxy (no `auth_request`). The shared OIDC client secret and the Authelia issuer key are delivered at runtime from sops via the repo's env-file generator pattern.

## Architecture Decisions

| Decision | Option | Tradeoff | Choice |
|---|---|---|---|
| Auth | OIDC (Authelia) / `PASSWORD_HASH` / proxy-auth | `PASSWORD_HASH` crashes v15; proxy-auth (`DISABLE_PASSWORD_AUTH` + no OIDC) = blank login + setup-wizard lockout (Option X dead) | OIDC against this repo's Authelia |
| Web UI loopback | docker `-p 127.0.0.1:51821` / in-container `HOST`/`PORT` bind | v15 splits `PORT`(port)+`HOST`(bind); `HOST` bind is buggy (#1899, nitro ignores it); in-container loopback bind is unreachable via docker DNAT | port-publish `127.0.0.1:51821:51821/tcp` + `PORT=51821` |
| Client secret delivery | `environmentFiles` + oneshot / `environment` attrset | attrset embeds `$pbkdf2$` in world-readable Nix store | repurpose `wg-easy-secrets` oneshot → `/srv/glats/wireguard/wg-easy.env` |
| Issuer key delivery | `_FILE` env / inline in generated YAML | multi-line PEM can't ride a line-based env file; `_FILE` is Authelia's documented file-secret pattern | write PEM to `/srv/glats/authelia/oidc-issuer-private-key.pem`, reference via `_FILE` env |
| Hairpin (container→auth.glats.org) | `--add-host` / split-DNS | public DNS resolves to NAT'd WAN IP → hairpin fails | `--add-host=auth.glats.org:172.16.0.5` |
| Image tag | `:15` / `:latest` | `:latest` churn; `:15` = 15.4.0 (OIDC shipped 2026-08-14 — pin + smoke-test) | `ghcr.io/wg-easy/wg-easy:15` |

## Data Flow

```
browser ─https─▶ nginx wg.glats.org (TLS wildcard, NO auth_request)
                   │ proxyPass 127.0.0.1:51821 (docker-loopback only)
                   ▼
             wg-easy (NET_ADMIN+SYS_MODULE)
                │ UI :51821 (loopback)          │ wg0 10.13.13.1/24 :51820/udp
                │ OIDC client ──HTTPS──▶ auth.glats.org (172.16.0.5 via --add-host) ─▶ Authelia
                └── /srv/glats/wireguard (server key + peers, persisted)
```

Secret flow: `sops → /run/secrets/{wireguard/oauth_client_secret, authelia/oidc_issuer_private_key} → wg-easy-secrets / authelia-secrets oneshots → env file + PEM`.

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `linux/system/services/network/wireguard.nix` | Rewrite | declarative WG → wg-easy (OIDC env, draft below) |
| `linux/system/services/web/authelia.nix` | Modify | add `identity_providers.oidc` to generated config + 2 runtime secrets |
| `linux/system/services/web/nginx.nix` | Modify | add `wg.glats.org` plain-proxy vhost |
| `hosts/rog/secrets.nix` | Modify | drop 6 `wireguard/*`; add `wireguard/oauth_client_secret` + `authelia/oidc_issuer_private_key` |
| `secrets/host/rog/{wireguard,authelia}.yaml` | Modify | sops rotate (below) |
| `hosts/rog/systemd-timeouts.nix` | Modify | add `docker-wg-easy` 300s timeout |
| `pkgs/nixos-scripts/default.nix` | Modify | remove 4 script registrations |
| `bin/{export-wireguard-configs,add-wireguard-peer,remove-wireguard-peer,generate-thinkpad-wireguard}` | Delete | obsolete |
| `openspec/specs/wireguard-config-export/` | Delete | superseded |

## Module Draft — `wireguard.nix`

```nix
{ config, pkgs, ... }: {
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.disable_ipv6" = 1;
    "net.ipv4.conf.all.src_valid_mark" = 1;
  };
  systemd.tmpfiles.rules = [ "d /srv/glats/wireguard 0755 root root -" ];

  systemd.services.wg-easy-secrets = {   # runtime env file (authelia/romm pattern)
    before = [ "docker-wg-easy.service" ];
    wantedBy = [ "docker-wg-easy.service" ];
    serviceConfig = {
      Type = "oneshot"; RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "wg-easy-secrets" ''
        mkdir -p /srv/glats/wireguard
        S=$(cat ${config.sops.secrets."wireguard/oauth_client_secret".path})
        printf 'OAUTH_OIDC_CLIENT_SECRET=%s\n' "$S" > /srv/glats/wireguard/wg-easy.env
        chmod 600 /srv/glats/wireguard/wg-easy.env
      '';
    };
  };

  virtualisation.oci-containers.containers.wg-easy = {
    image = "ghcr.io/wg-easy/wg-easy:15";
    autoStart = true;
    ports = [ "51820:51820/udp" "127.0.0.1:51821:51821/tcp" ];
    volumes = [ "/srv/glats/wireguard:/etc/wireguard" "/lib/modules:/lib/modules:ro" ];
    capabilities = { NET_ADMIN = true; SYS_MODULE = true; };
    environment = {
      WG_HOST = "guard.glats.org";
      WG_PORT = "51820";
      PORT = "51821";
      WG_DEFAULT_ADDRESS = "10.13.13.x";
      WG_DEFAULT_DNS = "1.1.1.1";
      WG_ALLOWED_IPS = "10.13.13.0/24";
      OAUTH_PROVIDERS = "oidc";
      OAUTH_OIDC_SERVER = "https://auth.glats.org";
      OAUTH_OIDC_CLIENT_ID = "wg-easy";   # non-secret literal (public in OAuth)
      OAUTH_OIDC_NAME = "Authelia";
      OAUTH_AUTO_REGISTER = "true";
      OAUTH_ALLOWED_DOMAINS = "glats.org";
      OAUTH_AUTO_LAUNCH = "oidc";
      DISABLE_PASSWORD_AUTH = "true";
      # INSECURE stays unset (false) → https redirect URI + secure session cookie
    };
    environmentFiles = [ "/srv/glats/wireguard/wg-easy.env" ];
    extraOptions = [
      "--sysctl=net.ipv4.ip_forward=1"
      "--sysctl=net.ipv4.conf.all.src_valid_mark=1"
      "--add-host=auth.glats.org:172.16.0.5"
      "--memory=512m"
    ];
  };
  systemd.services.docker-wg-easy = {
    after = [ "wg-easy-secrets.service" ];
    requires = [ "wg-easy-secrets.service" ];
  };
}
```

## Authelia additions — `authelia.nix`

In `authelia-secrets` oneshot: read `wireguard/oauth_client_secret` + `authelia/oidc_issuer_private_key`; write the PEM to `/srv/glats/authelia/oidc-issuer-private-key.pem` (chmod 600); append `AUTHELIA_OIDC_CLIENT_SECRET=<hash>` and `AUTHELIA_IDENTITY_PROVIDERS_OIDC_ISSUER_PRIVATE_KEY_FILE=/srv/glats/authelia/oidc-issuer-private-key.pem` to `authelia.env`; add to the generated `configuration.yml`:

```yaml
identity_providers:
  oidc:
    issuer_private_key: ${AUTHELIA_IDENTITY_PROVIDERS_OIDC_ISSUER_PRIVATE_KEY_FILE}
    clients:
      - client_id: wg-easy
        client_name: wg-easy
        client_secret: $AUTHELIA_OIDC_CLIENT_SECRET
        redirect_uris:
          - https://wg.glats.org/api/auth/oidc/callback
          - https://wg.glats.org/api/auth/oidc/link
        scopes: [openid, profile, email]
        authorization_policy: one_factor
        require_pkce: true
        token_endpoint_auth_method: client_secret_post
        pre_configured_consent_duration: 1 week
```

`auth.glats.org` already has `access_control policy: bypass` → OIDC endpoints reachable without proxy auth. The existing file-backend user `glats` carries `email: glats@glats.org`; `email_verified` must resolve truthy (verify in smoke test).

## nginx vhost — `wg.glats.org`

Plain proxy (mirror `gonic`), `useACMEHost = "glats.org"` (wildcard covers it). **No `auth_request`.** `X-Forwarded-Host` is mandatory — wg-easy derives its OIDC redirect URI from it.

```nix
"wg.${domain}" = {
  useACMEHost = "glats.org";
  forceSSL = true;
  locations."/" = {
    proxyPass = "http://127.0.0.1:51821";
    proxyWebsockets = true;
    extraConfig = ''
      proxy_set_header X-Forwarded-Host $host;
      proxy_set_header X-Forwarded-Proto $scheme;
      proxy_read_timeout 3600s;
      proxy_send_timeout 3600s;
    '';
  };
  extraConfig = secHeaders "SAMEORIGIN";
};
```

## sops rotation + one-time generation

| File | Change |
|---|---|
| `secrets/host/rog/wireguard.yaml` | REMOVE `server_private_key` + 5 PSKs; ADD `oauth_client_secret` |
| `secrets/host/rog/authelia.yaml` | ADD `oidc_issuer_private_key` (RSA PEM block scalar) |

One-time commands (run by user/apply before deploy):

```bash
# 1. client secret → one $pbkdf2-sha512$ string used in BOTH Authelia client_secret
#    AND wg-easy OAUTH_OIDC_CLIENT_SECRET (stored once in wireguard/oauth_client_secret)
docker run --rm authelia/authelia crypto hash generate pbkdf2 \
  --variant sha512 --random --random.length 72 --random.charset rfc3986
# 2. issuer RSA key (unencrypted PEM → authelia/oidc_issuer_private_key)
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048
# 3. rotate
sops secrets/host/rog/wireguard.yaml   # + oauth_client_secret, - 6 keys
sops secrets/host/rog/authelia.yaml    # + oidc_issuer_private_key (block scalar)
```

`hosts/rog/secrets.nix`: drop 6 `wireguard/*`, add `wireguard/oauth_client_secret` (wireguard.yaml) and `authelia/oidc_issuer_private_key` (authelia.yaml) — default mode 0400 root, read only by the two root oneshots.

## Interfaces / Contracts

- **Module options**: NO new options. `wireguard.nix` stays a plain config module imported by `hosts/rog/default.nix` (line 79 unchanged). Emits `boot.kernel.sysctl`, `systemd.tmpfiles.rules`, `systemd.services`, `virtualisation.oci-containers.containers.wg-easy`.
- **Migration**: **breaking** — removing declarative `wg0` destroys the old server keypair; all 5 old peers (oneplus9, mac, thinkpad, samsung, thinkphone) are revoked. Re-enroll (motorola-g70, thinkpad, samsung, mact2) via UI after OIDC login.

## Testing / Smoke test (rog)

1. `docker exec wg-easy wg show` → `wg0` + server pubkey; `curl -sI http://127.0.0.1:51821` → 200; `curl -sI http://172.16.0.5:51821` → refused (loopback-only).
2. **OIDC end-to-end**: `https://wg.glats.org` → auto-redirect to `auth.glats.org` login → sign in as `glats` → callback → UI (no local password form).
3. **First-login bootstrap**: `OAUTH_AUTO_REGISTER=true` must create the admin and skip the setup wizard on first OIDC login (if the wizard blocks, fall back to one-time `INIT_USERNAME`/`INIT_PASSWORD`).
4. **`email_verified` claim** truthy from Authelia file backend (else 401) — inspect userinfo for `glats`.
5. **Hairpin**: container logs show successful token exchange against `auth.glats.org` (172.16.0.5).
6. Create 4 peers → `wg show` handshakes; config `AllowedIPs = 10.13.13.0/24`; mact2 via QR.
7. `nix flake check --no-build`; `docker ps` → container healthy.

## Threat Matrix

Matrix rows (routing/shell/VCS/PR automation) are **N/A** — no subprocess/VCS automation. Applicable invariant: UI never publicly reachable (firewall off) — RED test: `curl http://172.16.0.5:51821` and `curl http://<public-ip>:51821` both refused.

## Rollback

```bash
git checkout <pre-change-sha> -- linux/system/services/network/wireguard.nix \
  linux/system/services/web/nginx.nix linux/system/services/web/authelia.nix \
  hosts/rog/secrets.nix hosts/rog/systemd-timeouts.nix \
  secrets/host/rog/wireguard.yaml secrets/host/rog/authelia.yaml \
  bin/ pkgs/nixos-scripts/default.nix
docker rm -f wg-easy && rm -rf /srv/glats/wireguard
sops revert secrets/host/rog/wireguard.yaml secrets/host/rog/authelia.yaml  # if already rotated
nixos-build
```

## Open Questions

None blocking. Flags for apply: confirm Authelia `_FILE` env name (`AUTHELIA_IDENTITY_PROVIDERS_OIDC_ISSUER_PRIVATE_KEY_FILE`) against current docs; if `OAUTH_AUTO_REGISTER` doesn't bypass the setup wizard, use one-time `INIT_*` bootstrap.
