# Proposal: WireGuard web manager (wg-easy)

## Intent

Replace the declarative WireGuard setup on `rog` with **wg-easy** (v15.4.0) so peers can be managed (create/edit/delete, config download + QR) via a web UI instead of hand-edited Nix. Authentication is **Authelia OIDC single sign-on** (no local wg-easy password). Also revoke the 5 old peers and drop the now-obsolete config-export machinery.

## Scope — host: `rog` only

### In Scope
- Rewrite `linux/system/services/network/wireguard.nix` (keep filename; still imported only by `hosts/rog/default.nix`): remove declarative `wg0`/peers/PSKs/`activationScript`/dnsmasq/`networking.nat`; keep sysctls (`ip_forward`, `src_valid_mark`); add `wg-easy` oci-container — image `ghcr.io/wg-easy/wg-easy:15`, `NET_ADMIN`+`SYS_MODULE`, container sysctls + `--add-host=auth.glats.org:172.16.0.5`, env `WG_HOST=guard.glats.org`, `WG_PORT=51820`, `PORT=51821` (docker-loopback `127.0.0.1:51821:51821/tcp`), `WG_DEFAULT_ADDRESS=10.13.13.x`, `WG_DEFAULT_DNS=1.1.1.1`, `WG_ALLOWED_IPS=10.13.13.0/24` (split tunnel), OIDC env (`OAUTH_PROVIDERS=oidc`, `OAUTH_OIDC_SERVER=https://auth.glats.org`, `OAUTH_OIDC_CLIENT_ID`, `OAUTH_AUTO_REGISTER=true`, `OAUTH_ALLOWED_DOMAINS=glats.org`, `OAUTH_AUTO_LAUNCH=oidc`, `DISABLE_PASSWORD_AUTH=true`) with `OAUTH_OIDC_CLIENT_SECRET` from sops; volume `/srv/glats/wireguard` (+ tmpfiles rule). **No `PASSWORD`/`PASSWORD_HASH`** (crashes v15).
- sops: add `wireguard/oauth_client_secret` (`$pbkdf2-sha512$` string, shared with Authelia `client_secret`) to `secrets/host/rog/wireguard.yaml`; add `authelia/oidc_issuer_private_key` (RSA PEM) to `secrets/host/rog/authelia.yaml`; remove `server_private_key` + 5 PSKs from `wireguard.yaml` + `hosts/rog/secrets.nix`.
- authelia: add `identity_providers.oidc` block (issuer key + `wg-easy` client: redirect URIs, `scopes=[openid,profile,email]`, PKCE, `client_secret_post`, `one_factor`) to the generated config.
- nginx: add `wg.glats.org` vhost → `127.0.0.1:51821`, TLS per repo convention (`useACMEHost`), **plain proxy, no `auth_request`** (auth is wg-easy OIDC → Authelia).
- Delete obsolete: `bin/{export-wireguard-configs,add-wireguard-peer,remove-wireguard-peer,generate-thinkpad-wireguard}` + their `pkgs/nixos-scripts/default.nix` registrations, spec `openspec/specs/wireguard-config-export/`, runtime `/etc/wireguard/clients/*`, `~/Documents/wireguard/*`.
- Post-deploy manual step (documented): create 4 peers in UI — motorola-g70, thinkpad, samsung, mact2.

### Out of Scope
- wg-portal / other managers. Endpoint domain change. Non-rog hosts. Google/GitHub OIDC providers (only Authelia).

## Capabilities

- **New** `wireguard-web-management`: wg-easy UI at wg.glats.org — login required, peer CRUD, config download + QR, auto IP assignment, split-tunnel default.
- **Removed** `wireguard-config-export`: superseded by wg-easy native download/QR. (Reason: obsolete. Migration: distribute configs via UI.)

## Approach

Follow exploration §"Integration design sketch", with **Authelia OIDC single sign-on** (user decision, verified 2026-08-15). wg-easy owns `wg0` + NAT inside the container; host keeps only sysctls. Auth = OIDC against this repo's Authelia; local password login disabled (`DISABLE_PASSWORD_AUTH=true`), no `PASSWORD_HASH`, no nginx `auth_request`.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `linux/system/services/network/wireguard.nix` | Rewrite | declarative WG → wg-easy container (OIDC env) |
| `linux/system/services/web/authelia.nix` | Modify | add `identity_providers.oidc` (issuer key + client) |
| `hosts/rog/secrets.nix` | Modify | drop 6 keys, add `oauth_client_secret` + `oidc_issuer_private_key` |
| `secrets/host/rog/{wireguard,authelia}.yaml` | Modify | sops rotate (via `sops secrets/...`) |
| `linux/system/services/web/nginx.nix` | Modify | add `wg.glats.org` vhost (no auth_request) |
| `pkgs/nixos-scripts/default.nix` | Modify | remove 4 script registrations |
| `bin/{export-wireguard-configs,add,remove-wireguard-peer,generate-thinkpad-wireguard}` | Remove | obsolete |
| `openspec/specs/wireguard-config-export/` | Remove | superseded |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Firewall disabled → UI exposed if not loopback-bound | Med | docker port-publish `127.0.0.1:51821` (authoritative); verify refused on LAN + WAN post-deploy |
| OIDC shipped 2026-08-14 (1 day old) | Med | pin `:15`; smoke-test full login flow at deploy |
| First-login bootstrap (setup wizard vs `OAUTH_AUTO_REGISTER`) | Med | smoke-test; fallback to one-time `INIT_USERNAME`/`INIT_PASSWORD` |
| `email_verified` claim not truthy from file backend | Med | verify Authelia userinfo for `glats`; 401 would reveal it |
| Container → `auth.glats.org` NAT hairpin | Med | `--add-host=auth.glats.org:172.16.0.5` |
| `PASSWORD`/`PASSWORD_HASH` set → container crashes | Low | neither is set anywhere; `DISABLE_PASSWORD_AUTH=true` |
| Volume unmounted → key rotation orphans peers | Med | mandatory `/srv/glats/wireguard` mount |
| Full-tunnel default | Low | set `WG_ALLOWED_IPS=10.13.13.0/24` |
| `$` interpolation in `$pbkdf2$` secret | Med | env-file/sops pattern; single `$(cat)` read into `printf %s` |
| Container NAT/egress breakage | Med | test egress from one peer |

## Rollback Plan

1. `git revert <change-commit>` (or `git checkout <pre-change-sha> -- linux/system/services/network/wireguard.nix hosts/rog/secrets.nix`).
2. `docker rm -f wg-easy && rm -rf /srv/glats/wireguard` — frees 51820/udp + 51821.
3. Remove `wg.glats.org` vhost from `nginx.nix`.
4. `nixos-build` — old declarative `wg0` + 5 peers restored (encrypted keys still in git history at `secrets/host/rog/wireguard.yaml`).
5. Re-export old client configs from git history if needed.

## Dependencies

- sops access to edit `secrets/host/rog/{wireguard,authelia}.yaml`; OIDC client secret generated via `authelia crypto hash generate pbkdf2`; issuer RSA key via `openssl genpkey`.

## Success Criteria

- [ ] `nix flake check --no-build` passes (rog).
- [ ] `https://wg.glats.org` → Authelia login → OIDC callback → wg-easy UI (no local password form); `docker exec wg-easy wg show` lists 4 peers.
- [ ] UI NOT reachable on `:51821` externally or on LAN `172.16.0.5`; `:51820/udp` reachable.
- [ ] First OIDC login auto-creates the admin (setup wizard bypassed).
- [ ] Old scripts/spec/runtime leftovers removed; split-tunnel confirmed on one peer.
