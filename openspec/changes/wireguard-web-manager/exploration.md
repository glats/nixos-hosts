# Exploration: WireGuard web manager (wg-easy) + peer revocation/re-creation

## Current State

WireGuard is served declaratively on `rog` only, via `linux/system/services/network/wireguard.nix`
(imported solely by `hosts/rog/default.nix` line 79). The module:

- Declares `networking.wireguard.interfaces.wg0` (server IP `10.13.13.1/24`, listenPort `51820`,
  `privateKeyFile` from sops `wireguard/server_private_key`), 5 peers with per-peer PSKs
  (oneplus9, mac, thinkpad, samsung, thinkphone — ips `.2`–`.6`).
- Runs `services.dnsmasq` on `10.13.13.1` (upstream 1.1.1.1/8.8.8.8, `resolveLocalQueries=false`).
- Enables `networking.nat` for `10.13.13.0/24` + sysctls (`ip_forward=1`, `disable_ipv6=1`, `src_valid_mark=1`).
- `system.activationScripts.wireguard-client-configs` regenerates `/etc/wireguard/clients/<name>.conf`
  at every activation (server pubkey + PSK, client key generated client-side).

Endpoints: `serverEndpoint = "guard.glats.org"` (wildcard-DNS on `glats.org`).

Secrets: `secrets/host/rog/wireguard.yaml` holds `server_private_key` + 5 peer PSKs, declared in
`hosts/rog/secrets.nix`.

Firewall: **DISABLED** — `linux/system/networking/firewall.nix` sets `networking.firewall.enable = false`.
No explicit 51820/udp rule exists (or is needed). Implication: the web UI port MUST be bound to
127.0.0.1 only, since there is no host firewall to fall back on.

Docker: `virtualisation.oci-containers.backend = "docker"`. Container pattern (`dozzle.nix`, `jellyfin.nix`,
`authelia.nix`): `image`, `autoStart`, `volumes`, `environment`/`environmentFiles`, `extraOptions`
(`--network`, `--memory`, `--cpus`, health-cmds), `ports`. **No existing container uses NET_ADMIN / SYS_MODULE / privileged** —
wg-easy would be the first.

nginx: `virtualHosts` in `web/nginx.nix`, domain `glats.org`, wildcard `*.glats.org` cert. Convention
`<name>.glats.org`. Authelia protection precedent = `openfang.glats.org` (inline `auth_request
/internal/authelia/authz` + `error_page 401 = @auth_redirect`); a `mkAutheliaVhost` helper exists but is currently unused.

Legacy dead weight already present: `bin/add-wireguard-peer`, `bin/remove-wireguard-peer`,
`bin/generate-thinkpad-wireguard` all reference pre-refactor paths (`modules/wireguard.nix`,
`hosts/rog/services/wireguard.nix`, `secrets/wireguard/peer-*-psk`) that no longer exist.
`bin/export-wireguard-configs` + spec `openspec/specs/wireguard-config-export/` (built in the previous
change 2026-08-15) exist and work today.

## Affected Areas

- `linux/system/services/network/wireguard.nix` — rewritten: declarative interface, peers, PSKs,
  activationScript, dnsmasq, NAT all removed; replaced by wg-easy oci-container definition.
- `hosts/rog/default.nix` — import line unchanged (module name kept); possibly add timeout overrides
  for `docker-wg-easy` (repo has a precedent of extending `systemd.services."docker-*"` timeouts).
- `hosts/rog/secrets.nix` + `secrets/host/rog/wireguard.yaml` — drop `server_private_key` + 5 PSKs;
  add `wireguard/password_hash` (bcrypt) [+ OIDC client secret if chosen].
- `linux/system/services/web/nginx.nix` — add `wg.glats.org` vhost (authelia-protected).
- `openspec/specs/wireguard-config-export/` — spec superseded by wg-easy's native download/QR; REMOVE.
- `bin/export-wireguard-configs`, `bin/add-wireguard-peer`, `bin/remove-wireguard-peer`,
  `bin/generate-thinkpad-wireguard` — all obsolete; REMOVE (with `pkgs/nixos-scripts` registration
  cleanup for export-wireguard-configs).
- `linux/system/networking/firewall.nix` — no change (already disabled).

## Options comparison (verified 2026-08-15 via GitHub releases + docs)

| Tool | Stars | License | Latest release | Maintenance | Peer CRUD | QR | Config download | Auto IP | Docker footprint | Notes |
|------|-------|---------|----------------|-------------|-----------|-----|-----------------|---------|------------------|-------|
| **wg-easy** | 26,665 | AGPL-3.0 | **v15.4.0 (2026-08-14)** | ✅ very active | ✅ | ✅ | ✅ | ✅ | single container, all-in-one (manages wg0 itself) | OIDC (Authelia/Authentik/Google/GitHub), 2FA/TOTP, client expiry, one-time links, Prometheus, per-client firewall |
| wg-portal | 1,765 | MIT | v2.3.1 (2026-06-12) | ✅ active | ✅ | ✅ | ✅ | ✅ | single Go binary or container (wgctrl) | multi-interface, LDAP/OIDC, per-user self-service; does NOT manage wg0 (attaches to existing) |
| wireguard-ui | 5,141 | MIT | v0.6.2 (**2024-01-07**) | ❌ stale 2.5y, 210 open issues | ✅ | ✅ | ✅ | partial | container | effectively unmaintained — REJECT |
| firezone | n/a | (SSO, policy) | n/a | active | — | — | — | — | heavy (Elixir+Postgres) | overkill; site-based policy engine, needs its own clients for mobile |

**Recommendation: wg-easy.** It is the most popular (26.6k stars), the simplest (one container that
runs WireGuard *and* the admin UI), and — decisively — it is actively maintained (v15.4.0 released the
day before this exploration) and now ships **native OIDC support including Authelia**, which this repo
already runs. AGPL-3.0 is irrelevant for private deployment (no redistribution). Fallback if wg-easy
ever stalls: wg-portal (MIT, still active) — but it does not manage the wg0 interface (uses `wgctrl`
against an existing interface), so it would *keep* the declarative module rather than replace it.

## wg-easy configuration (verified from docs/releases)

Key env vars:
- `WG_HOST=guard.glats.org` — public endpoint baked into generated client configs.
- `PASSWORD_HASH=<bcrypt>` — **v14+ requires this; `PASSWORD` is now rejected** (container throws
  `DO NOT USE PASSWORD ENVIRONMENT VARIABLE`). Generate: `docker run ghcr.io/wg-easy/wg-easy wgpw <pw>`
  (note `$` escaping if ever passed via compose; via oci-containers `environment` a single `$` is fine,
  but `$$` escaping may be needed depending on value interpolation — verify in design).
- `WG_DEFAULT_ADDRESS=10.13.13.x` — continues the existing IP scheme.
- `WG_DEFAULT_DNS=1.1.1.1` — wg-easy does NOT run a DNS server; the current dnsmasq (bound to 10.13.13.1,
  which ceases to exist as a host IP once wg0 moves into the container) must be dropped. `1.1.1.1` is
  functionally equivalent for this repo (no local name resolution today).
- `WG_PORT=51820` (public UDP), `PORT=51821` (web UI, bind loopback).
- `WG_ALLOWED_IPS=10.13.13.0/24` (optional; default 0.0.0.0/0 routes all client traffic — repo currently
  uses 10.13.13.0/24 split-tunnel, so set this to preserve split-tunnel).

Container shape (mapped to oci-containers):
- `image = "ghcr.io/wg-easy/wg-easy:15"` (pin major; avoid `:latest` churn).
- `volumes = [ "/srv/glats/wireguard:/etc/wireguard" ]` — **persists the server private key + wg0.conf +
  peers**; generated on first run, survives recreation. Also `"/lib/modules:/lib/modules:ro"` for module loading.
- `ports = [ "51820:51820/udp" "127.0.0.1:51821:51821/tcp" ]` — **web UI loopback-only** (firewall is off).
- `extraOptions = [ "--cap-add=NET_ADMIN" "--cap-add=SYS_MODULE" "--sysctl=net.ipv4.ip_forward=1"
  "--sysctl=net.ipv4.conf.all.src_valid_mark=1" ]` (+ memory limit). `/dev/net/tun` not required for
  kernel WireGuard (only for the userspace `wireguard-go` fallback; optional).

Server key: wg-easy generates a fresh server keypair on first run into `/etc/wireguard` volume. Old key
is irrelevant (revocation is the point). To *keep* the key across recreation, persist the volume (above).

## Integration design sketch

1. **Rewrite `wireguard.nix`** → becomes the wg-easy module (keep filename; still rog-only import).
   - REMOVE: `peers`, `mkWireGuardPeers`, `networking.wireguard.interfaces.wg0`,
     `system.activationScripts.wireguard-client-configs`, `services.dnsmasq`, `networking.nat`
     (wg-easy runs its own MASQUERADE inside the container — host NAT for 10.13.13.0/24 is obsolete).
   - KEEP: `boot.kernel.sysctl` (`ip_forward`, `src_valid_mark`) — harmless host-level insurance
     (container sets its own too). Keep `disable_ipv6` if IPv4-only is desired.
   - ADD: `virtualisation.oci-containers.containers.wg-easy` (shape above), a tmpfiles rule for
     `/srv/glats/wireguard`, and a `docker-wg-easy` timeout override if needed.
2. **nginx**: add `wg.glats.org` vhost using the authelia `auth_request` pattern (copy `openfang`
   precedent or use the unused `mkAutheliaVhost` helper) → proxy to `127.0.0.1:51821`.
3. **Authelia layering decision**: **nginx auth_request + wg-easy `PASSWORD_HASH`** (defense-in-depth,
   matches existing openfang precedent, zero new IdP config). Optional refinement for design phase:
   wg-easy native OIDC against Authelia (single sign-on, no second password) — needs an Authelia OIDC
   client (client_id, PBKDF2-hashed client_secret, PKCE, `client_secret_post`, redirect URIs
   `https://wg.glats.org/api/auth/oidc/callback|link`). Recommend shipping the simpler auth_request
   path first; OIDC as follow-up if desired.
4. **sops**: add `wireguard/password_hash` (bcrypt) to a new/extended `secrets/host/rog/wireguard.yaml`;
   remove the now-dead server/peer keys. Wire into container `environment` or an env file (authelia
   uses a systemd-oneshot env-file generator — reuse that pattern if `$` interpolation in bcrypt is a concern).

## Migration checklist

1. Deploy wg-easy container + nginx vhost + secrets (nixos-rebuild). wg0 now lives in the container;
   host wg0 is gone, so 51820/udp is served by the container.
2. First run: wg-easy generates server key into `/srv/glats/wireguard` (persisted). Log in to
   `https://wg.glats.org` (authelia → wg-easy password).
3. Create 4 peers in the UI: motorola-g70, thinkpad, samsung, mact2 (auto-assigned 10.13.13.x).
4. Distribute configs: QR (phones) / .conf download (laptops); mact2 imports via WireGuard macOS app.
5. Delete obsolete artifacts: `bin/{export-wireguard-configs,add-wireguard-peer,remove-wireguard-peer,
   generate-thinkpad-wireguard}`, spec `openspec/specs/wireguard-config-export/`, sops server/PSK keys,
   `/etc/wireguard/clients/*`, `~/Documents/wireguard/*`.
6. Verify: `nix flake check --no-build`; `docker exec wg-easy wg show`; client connectivity from each device.

## Revocation semantics

Removing the declarative `networking.wireguard.interfaces.wg0` destroys the old wg0 + old server keypair.
All 5 existing peers (oneplus9, mac, thinkpad, samsung, thinkphone) are immediately invalid — the old
server pubkey their configs reference no longer exists. This is the intended revocation. mac + thinkpad
identities are obsolete (superseded by mact2 + new thinkpad). Old client configs in `/etc/wireguard/clients/`
and `~/Documents/wireguard/` are dead — remove. `bin/export-wireguard-configs` + its spec are superseded
by wg-easy's native download/QR — remove (the spec's scenarios are all voided: no more server-side
config generation).

## Risks

- **Firewall disabled** → web UI MUST stay loopback-bound; a port-publish mistake (`51821:51821` without
  `127.0.0.1:`) would expose an unauthenticated-or-password-only UI to the internet. Highest-priority risk.
- **`PASSWORD_HASH` migration gotcha** — if `PASSWORD` (cleartext) is ever set instead, wg-easy v14+
  refuses to start / silently disables auth (historic issue #1269). Always use `PASSWORD_HASH`, verify
  login works post-deploy.
- **NAT/NAT nuance** — relying on wg-easy's internal MASQUERADE; if docker bridge + iptables interplay
  misroutes, peer internet access breaks. Design phase should sanity-check egress from a test peer.
- **DNS regression** — dropping dnsmasq removes `10.13.13.1` as a resolver; if any peer config hardcodes
  `DNS = 10.13.13.1`, it will silently fail. New client configs from wg-easy will carry `WG_DEFAULT_DNS`.
- **Key persistence** — if the `/etc/wireguard` volume is not mounted, every container recreation rotates
  the server key and orphans all peers. Volume mount is mandatory.
- **`$$` escaping** — bcrypt hash contains `$`; passing via `environment`/env-file must not be interpolated.
- **Split-tunnel default** — wg-easy defaults to `AllowedIPs 0.0.0.0/0` (full tunnel); repo uses
  `10.13.13.0/24`. Set `WG_ALLOWED_IPS` explicitly or peers will route all traffic.

## Ready for Proposal

Yes. Proceed to `sdd-propose`. Scope: `rog` only; rewrite `wireguard.nix`, add `wg.glats.org` vhost,
rotate sops wireguard secrets, delete 4 obsolete `bin/` scripts + 1 spec.

---

## Follow-up exploration: Authelia OIDC single sign-in (2026-08-15)

> **User auth decision changed**: replace wg-easy local password login with **Authelia as the single
> login (OIDC)** — no double login, no separate wg-easy password. This SUPERSEDES the auth portions of
> the original exploration above (the `PASSWORD_HASH` / `wgpw` approach, and the "ship auth_request first"
> recommendation).

### Verdict (short)

OIDC **is suitable** — wg-easy v15.4.0 (released 2026-08-14) added native OAuth/OIDC with an official
Authelia example. **BUT the `PASSWORD_HASH` approach in the design is INVALID for `:15`**: v15.0.0
(2025-05-28) was a complete rewrite that **removed `PASSWORD_HASH`/`PASSWORD`** — setting either now
**crashes the container at startup** (`src/server/utils/WireGuard.ts`: "You are using an invalid
Configuration for wg-easy… migrate from 14 to 15"). The only mandatory env var is `PORT`. The design
must be rewritten, not OIDC-bolted-on.

### wg-easy OIDC env vars — real list (verified from source: `oauth.ts`, `config.ts`)

The originally-assumed `OIDC_*` names **do not exist**. wg-easy uses `OAUTH_*`:

| Env | Req | Purpose |
|---|---|---|
| `OAUTH_PROVIDERS=oidc` | yes | enable generic OIDC (`google`/`github` also possible) |
| `OAUTH_OIDC_SERVER=https://auth.glats.org` | yes | OIDC issuer base URL (discovery via `/.well-known/openid-configuration`) |
| `OAUTH_OIDC_CLIENT_ID` | yes | client id |
| `OAUTH_OIDC_CLIENT_SECRET` | yes | the `$pbkdf2-sha512$...` hash string |
| `OAUTH_OIDC_NAME=Authelia` | no | button label (default "OIDC") |
| `OAUTH_AUTO_REGISTER=true` | no | first OIDC login auto-creates the user (admin — permissions not implemented yet) |
| `OAUTH_ALLOWED_DOMAINS=glats.org` | no | restrict by email domain |
| `OAUTH_AUTO_LAUNCH=oidc` | no | auto-redirect login page → provider (`/login?auto_launch=false` to bypass) |
| `DISABLE_PASSWORD_AUTH=true` | no | **removes the local password login entirely** (403 in `password.post.ts`; basic auth rejected in `session.ts`) |

- Scopes are **hardcoded** `openid email profile` (no `OIDC_SCOPES`). No `OIDC_REDIRECT_URL`,
  `OIDC_USER_CLAIM`, or `OIDC_SECRET_PBKDF2_*` vars exist.
- **Redirect URIs** (fixed paths, host built from request Host + `INSECURE` flag): `https://wg.glats.org/api/auth/oidc/callback` (login) and `.../oidc/link` (link).
- Provider must support PKCE + `client_secret_post` + HTTPS with valid cert.
- wg-easy asserts `sub`, `email`, and **`email_verified`** (truthy) from the userinfo (`oauth.ts`).

### `PASSWORD_HASH`: not required — forbidden

`PASSWORD`/`PASSWORD_HASH` are `@deprecated Only for migration purposes` and throw if set. With
`OAUTH_AUTO_REGISTER=true` the first OIDC login creates the admin — **no local password ever needed**.
Alternative bootstrap `INIT_ENABLED`/`INIT_USERNAME`/`INIT_PASSWORD` is NOT needed here (reintroduces a
password). Local login is fully disabled via `DISABLE_PASSWORD_AUTH=true` → single sign-in, exactly as
requested. No nginx `auth_request` (that was the double-login they rejected).

### `INSECURE` flag (critical)

`INSECURE` (default `false`) controls (a) the OIDC redirect URI protocol and (b) `secure: !INSECURE` on
the session cookie. **Keep it unset/false** so the redirect URI stays `https://wg.glats.org/...` and the
cookie is `secure`. Setting `INSECURE=true` behind the proxy would emit `http://` redirects + non-secure
cookie → OIDC breaks. nginx must forward `X-Forwarded-Host: $host` (already done by the vhost/`mkAutheliaVhost`
pattern; h3 `getRequestHost` prefers `x-forwarded-host`). `X-Forwarded-Proto` is ignored by wg-easy (protocol
comes from `INSECURE`) but harmless to send.

### Authelia OIDC client config (repo currently has NO `identity_providers` block)

Authelia OIDC additionally requires a mandatory `identity_providers.oidc.issuer_private_key` (RSA private
key — not auto-generated; generate with `authelia crypto pair rsa generate`, store PEM in sops). Client block:

```yaml
identity_providers:
  oidc:
    issuer_private_key: <rsa pem via sops>
    clients:
      - client_id: '<72-char rfc3986>'
        client_name: wg-easy
        client_secret: '$pbkdf2-sha512$...'
        redirect_uris:
          - https://wg.glats.org/api/auth/oidc/callback
          - https://wg.glats.org/api/auth/oidc/link
        scopes: [openid, profile, email]
        authorization_policy: one_factor
        pre_configured_consent_duration: 1 week
        require_pkce: true
        token_endpoint_auth_method: client_secret_post
```

**Secret semantics** (Authelia hashed-client-secret mode): `authelia crypto hash generate pbkdf2 --variant
sha512 --random --random.length 72 --random.charset rfc3986` prints ONE `$pbkdf2-sha512$...` string used in
BOTH `client_secret` (Authelia) and `OAUTH_OIDC_CLIENT_SECRET` (wg-easy). The RP presents the hash itself;
Authelia re-hashes and compares. Store the hash in sops anyway.

Repo specifics: `auth.glats.org` vhost already exists; wildcard `*.glats.org` cert covers both hosts.
Authelia `access_control` already has `- domain: "auth.glats.org" policy: bypass` → OIDC endpoints already
reachable without proxy auth. File-backend user `glats` already has `email: glats@glats.org` (required for
the `email` claim). Config is generated at runtime by `authelia-secrets` oneshot → add the `identity_providers`
block there, with id/secret/issuer-key from sops (`authelia/oidc_client_id`, `authelia/oidc_client_secret`,
`authelia/oidc_issuer_private_key` in `secrets/host/rog/authelia.yaml`).

### Network reachability (new, OIDC-specific risk)

wg-easy's OIDC client makes server-to-server HTTPS calls to `https://auth.glats.org` (discovery + token +
userinfo) from inside the container (default bridge). It must resolve AND reach `auth.glats.org` → nginx
(valid wildcard cert). NAT hairpin may fail. Mitigation: `--add-host=auth.glats.org:<host-LAN-ip>` on the
wg-easy container, or split-horizon DNS. Design phase must pin this.

### Recommendation

Ship OIDC. Design changes (supersede current design.md auth sections):
1. **Delete** `PASSWORD_HASH` + `wgpw` + the `wg-easy-secrets` oneshot (would crash v15). sops drops `wireguard/password_hash`.
2. **Add** `OAUTH_*` env vars (table above) — id/secret from sops; `OAUTH_AUTO_REGISTER=true`,
   `OAUTH_ALLOWED_DOMAINS=glats.org`, `OAUTH_AUTO_LAUNCH=oidc`, `DISABLE_PASSWORD_AUTH=true`.
3. **Keep** `INSECURE` unset; ensure `X-Forwarded-Host`; add `--add-host` for `auth.glats.org`.
4. **authelia.nix**: add `identity_providers.oidc` (issuer key + client) to the generated config; 3 new sops keys.
5. Image `:15` already includes OIDC (15.4.0 is the current 15.x); `:15` or `:15.4.0` pin both fine.
6. nginx `wg.glats.org` vhost: **NO `auth_request`** — plain proxy (the design's vhost is already correct).

### Risks (OIDC)

- OIDC shipped 2026-08-14 (1 day old) — brand-new feature; smoke-test carefully, pin tag.
- First-login bootstrap: `DISABLE_PASSWORD_AUTH=true`+`OAUTH_AUTO_REGISTER=true` must create the admin on
  first OIDC login; if a setup-wizard gate blocks OIDC before any user exists, a one-time `INIT_*` bootstrap
  may be needed (smoke-test).
- `email_verified` must be truthy from the Authelia file backend (else wg-easy 401s).
- Container → `auth.glats.org` NAT hairpin.
- Whole design.md is v14-era; substantial rewrite (not a bolt-on).

---

## Follow-up exploration: no-auth mode feasibility (Option X) — 2026-08-15

> **Question evaluated**: can we run wg-easy v15 with `DISABLE_PASSWORD_AUTH=true` and NO OIDC provider,
> behind nginx `auth_request` → Authelia, as the single-login path (avoiding the 1-day-old OIDC feature)?

### Verdict: INFEASIBLE — REJECTED

wg-easy v15 has **no "auth handled by reverse proxy" / no-auth mode**. Verified from source
(commit `9e21a96`, master):

**a. Container starts, but UI is unusable without a session.** Only `PORT` is mandatory
(`config.ts` `assertEnv('PORT')`); `DISABLE_PASSWORD_AUTH`/`OAUTH_*`/`INIT_*` are optional (no crash).
But `getCurrentUser` (`session.ts`) throws **401 "Session failed. No Authorization"** with no session cookie
and no `Authorization` header (header path 403s when `DISABLE_PASSWORD_AUTH=true`); `/api/session`
(`session.get.ts`) throws 401 "Not authenticated". The login page (`login/index.vue`) renders **blank**
(OAuth buttons `v-if="oauthEnabled"` = false; password form `v-if="!passwordDisabled"` = false) — no login
method exists.

**b. First-run setup wizard gates the UI and requires a password.** `defineSetupEventHandler`
(`handler.ts`) gates on `Database.general.getSetupStep()`; `setup/2.post.ts` (`UserSetupSchema`) requires
**username + password** → `Database.users.create(...)`. The unattended skip (`INIT_*`) still requires
`INIT_USERNAME` + `INIT_PASSWORD` (group 1). No passwordless bootstrap exists. So even completing setup
creates a password admin that `DISABLE_PASSWORD_AUTH=true` then makes un-loginable → permanent lockout
(the exact scenario `external-authentication.md` warns about: "If no login method is available, you will
not be able to log in… reset the configuration").

**c. Auth is global, not admin-only.** All protected routes use `definePermissionEventHandler` →
`getCurrentUser` → 401. Peer management is fully broken without a wg-easy session.

### Prior art (issues)

- **#1923** "[Feat]: External Authentication Support" — OPEN, 43 👍, updated 2026-07-22. Requests
  "disable authentication entirely… behind a proxy". Not implemented (OIDC #2659 was the partial answer).
- **#2354** "[Feat]: Disable Authentication for Clients" — closed **not_planned**.
- **#1329** "[Feat]: Support for Authentik // Disable Authentication" — closed **not_planned**.
- **#1269** — v14 "authentication effectively disabled" treated as a BUG, not a feature.

### Recommendation

Reject Option X. **Option Y (OIDC) remains the only true single-login path** — no change to the current
direction (obs `explore-oidc`). The one remaining uncertainty is Y's first-login admin bootstrap — smoke-test
it (`OAUTH_AUTO_REGISTER=true` must create the admin on first OIDC login, bypassing the setup wizard).
