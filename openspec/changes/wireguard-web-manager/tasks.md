# Tasks: WireGuard web manager (wg-easy) — OIDC via Authelia

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~550-600 (bulk = 257 script deletions) |
| 400-line budget risk | High |
| Chained PRs recommended | No |
| Suggested split | single atomic commit |
| Delivery strategy | single-pr (size:exception accepted) |
| Chain strategy | size-exception |

Decision needed before apply: Yes
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: High

Decision needed: user must run one-time secret generation (client secret + issuer key) before deploy.

### Suggested Work Units

Single unit — full atomic commit (user choice "Commit único atómico", size:exception accepted):

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | secrets → code → verify → cleanup in one commit | PR 1 | `nix flake check --no-build`; `curl -sI http://127.0.0.1:51821` | deploy on rog via `nixos-build`; OIDC login flow | `git checkout d925ac3 --` affected files + `docker rm -f wg-easy` |

## Phase 1: Secrets (blocked on user generation)

- [x] 1.1 Generated `$pbkdf2-sha512$` shared string via `nix run nixpkgs#authelia -- crypto hash generate pbkdf2` (value redacted).
- [x] 1.2 Generated RSA issuer PEM via `nix run nixpkgs#openssl -- genpkey` (kept in temp file, not committed).
- [x] 1.3 sops `secrets/host/rog/wireguard.yaml`: removed `server_private_key` + 5 PSKs; added `wireguard/oauth_client_secret` via `sops set`.
- [x] 1.4 sops `secrets/host/rog/authelia.yaml`: added `authelia/oidc_issuer_private_key` (RSA PEM) via `sops set`.
- [x] 1.5 `hosts/rog/secrets.nix`: dropped 6 legacy `wireguard/*` declarations; added `wireguard/oauth_client_secret` + `authelia/oidc_issuer_private_key`, mode 0400.

## Phase 2: Code changes

- [x] 2.1 Rewrote `linux/system/services/network/wireguard.nix`: wg-easy container with OIDC env, loopback UI, persisted volume, no PASSWORD/PASSWORD_HASH.
- [x] 2.2 `linux/system/services/web/authelia.nix`: authelia-secrets now writes OIDC issuer PEM and env vars; configuration.yml includes `identity_providers.oidc` block.
- [x] 2.3 `linux/system/services/web/nginx.nix`: added `"wg.${domain}"` plain TLS proxy vhost (no auth_request).
- [x] 2.4 `hosts/rog/systemd-timeouts.nix`: added `docker-wg-easy` TimeoutStartSec mkForce "300".

## Phase 3: Verification (OIDC smoke, rog)

- [ ] 3.1 `format-nix`; `nix flake check --no-build` → exit 0.
- [ ] 3.2 `nixos-build` dry→switch; RED: wg-easy healthy; `docker exec wg-easy wg show` → wg0+pubkey; `curl -sI http://127.0.0.1:51821` → 200.
- [ ] 3.3 RED (loopback-only): `curl http://172.16.0.5:51821` + `<public-ip>:51821` → refused.
- [ ] 3.4 RED (OIDC e2e): wg.glats.org → auto-redirect auth.glats.org → login glats → callback → UI; no password form.
- [ ] 3.5 RED (bootstrap): OAUTH_AUTO_REGISTER creates admin, wizard bypassed; fallback one-time INIT_USERNAME/INIT_PASSWORD if blocked.
- [ ] 3.6 RED (email_verified): userinfo for glats → truthy (else 401).
- [ ] 3.7 RED (hairpin): container logs show token exchange to auth.glats.org (172.16.0.5).
- [ ] 3.8 RED (no PASSWORD in store): grep store path for PASSWORD_HASH/PASSWORD → absent.
- [ ] 3.9 RED (key survives): `docker rm -f wg-easy`, restart → same pubkey, peers valid.
- [ ] 3.10 Create 4 peers (motorola-g70, thinkpad, samsung, mact2); AllowedIPs=10.13.13.0/24; `wg show` → 4 peers + handshakes; mact2 QR.
- [ ] 3.11 Record rollback sequence (`git checkout d925ac3 --` restore; docker rm -f wg-easy; rm -rf /srv/glats/wireguard; sops revert) in verify-report.

## Phase 4: Cleanup

- [ ] 4.1 Delete `bin/{export-wireguard-configs,add-wireguard-peer,remove-wireguard-peer,generate-thinkpad-wireguard}`.
- [ ] 4.2 `pkgs/nixos-scripts/default.nix`: remove 4 cp/chmod blocks (lines 22-23, 31-32, 40-41, 49-50).
- [ ] 4.3 Delete `openspec/specs/wireguard-config-export/` — AT ARCHIVE only (sdd-archive merges REMOVED delta; not during apply).
- [ ] 4.4 Post-switch: `rm -rf /etc/wireguard/clients ~/Documents/wireguard`.
