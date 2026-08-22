# wireguard-web-management Specification

## Purpose

wg-easy (v15.4.0) provides self-service WireGuard peer management on `rog` via a web UI at `wg.glats.org`, replacing the declarative WireGuard stack. Login is **Authelia OIDC single sign-on** (no local wg-easy password).

## Requirements

### Requirement: Container deployment

The system MUST run wg-easy as a single oci-container on `rog`, binding the web UI to `127.0.0.1:51821` only (never exposed publicly), serving peers on `51820/udp`, with `NET_ADMIN` + `SYS_MODULE` capabilities, and persisting the server key and peer configs in `/srv/glats/wireguard` across recreation.

#### Scenario: UI loopback-only [rog]

- GIVEN the wg-easy container runs on `rog`
- WHEN a client requests `http://<rog-public-ip>:51821`
- THEN the connection MUST be refused
- AND loopback `127.0.0.1:51821` from the host MUST respond

#### Scenario: Key survives recreation [rog]

- GIVEN a server keypair exists in `/srv/glats/wireguard`
- WHEN the container is removed and recreated
- THEN the same server public key MUST be retained
- AND existing peers MUST stay valid

### Requirement: Authentication

The web UI SHALL authenticate users via **Authelia OIDC** (single sign-on). `OAUTH_PROVIDERS=oidc`, `OAUTH_OIDC_SERVER=https://auth.glats.org`, `OAUTH_AUTO_LAUNCH=oidc`, `OAUTH_AUTO_REGISTER=true`, `OAUTH_ALLOWED_DOMAINS=glats.org`, and `DISABLE_PASSWORD_AUTH=true` MUST be set. The local wg-easy password form MUST be disabled. Cleartext `PASSWORD`/`PASSWORD_HASH` MUST NOT be set (wg-easy v15 crashes if they are). `INSECURE` MUST remain unset so the redirect URI is `https://` and the session cookie is `secure`.

#### Scenario: OIDC single sign-on [rog]

- GIVEN an anonymous client requests `https://wg.glats.org`
- WHEN no valid wg-easy session cookie is present
- THEN the server MUST redirect to the Authelia login at `auth.glats.org`
- AND after successful Authelia sign-in the callback MUST establish a session

#### Scenario: Local password form disabled [rog]

- GIVEN the wg-easy container runs with `DISABLE_PASSWORD_AUTH=true`
- WHEN the login page is rendered
- THEN no local username/password form MUST be shown
- AND the only login method MUST be the OIDC provider (Authelia)

#### Scenario: No PASSWORD_HASH [rog]

- GIVEN the container environment
- THEN neither `PASSWORD` nor `PASSWORD_HASH` MUST be present
- AND the container MUST start successfully (not crash with "migrate from 14 to 15")

### Requirement: Reverse proxy

nginx MUST serve `wg.glats.org` with TLS, proxying to `127.0.0.1:51821`. This vhost MUST be a plain proxy with **NO `auth_request`** — access flows through wg-easy's own OIDC login (which redirects to Authelia). It MUST forward `X-Forwarded-Host $host` so wg-easy derives the correct `https://wg.glats.org/...` OIDC redirect URI.

#### Scenario: TLS proxy [rog]

- GIVEN `wg.glats.org` resolves to `rog`
- WHEN a browser requests `https://wg.glats.org`
- THEN nginx MUST proxy to `127.0.0.1:51821` over TLS
- AND MUST forward `X-Forwarded-Host $host`

#### Scenario: No auth_request [rog]

- GIVEN the `wg.glats.org` vhost is configured
- WHEN a request arrives without prior authelia auth
- THEN nginx MUST NOT redirect to the authelia authz endpoint
- AND MUST NOT emit `auth_request /internal/authelia/authz`

### Requirement: Peer management

An authenticated user MAY create, edit, and delete peers from the UI. Each new peer MUST be auto-assigned an IP in `10.13.13.0/24`. Config download + QR MUST be available. Client configs MUST use split-tunnel `AllowedIPs = 10.13.13.0/24`, NOT `0.0.0.0/0`.

#### Scenario: Create peer, auto IP [rog]

- GIVEN an authenticated user opens the UI
- WHEN they create peer `thinkpad`
- THEN it MUST get an IP in `10.13.13.0/24`
- AND config download + QR MUST be available

#### Scenario: Split tunnel [rog]

- GIVEN a peer config is generated
- WHEN the client imports it
- THEN `AllowedIPs` MUST equal `10.13.13.0/24`, NOT `0.0.0.0/0`

#### Scenario: Delete peer [rog]

- GIVEN a peer exists
- WHEN the user deletes it
- THEN it MUST be removed from the interface and stop connecting

### Requirement: Declarative stack removal

The system MUST NOT define `networking.wireguard.interfaces.wg0`, run `services.dnsmasq`, enable `networking.nat` for `10.13.13.0/24`, or run the `wireguard-client-configs` activationScript. Host sysctls (`ip_forward`, `src_valid_mark`) MUST be retained.

#### Scenario: No host wg0 [rog]

- GIVEN the change is applied on `rog`
- THEN no host `wg0` interface MUST exist
- AND `51820/udp` MUST be served by the container

### Requirement: Secrets

The OIDC client secret (`wireguard/oauth_client_secret`, a `$pbkdf2-sha512$` string shared with Authelia's `client_secret`) MUST live in sops `secrets/host/rog/wireguard.yaml`. The Authelia OIDC issuer RSA private key (`authelia/oidc_issuer_private_key`, PEM) MUST live in sops `secrets/host/rog/authelia.yaml`. Legacy `server_private_key` and peer PSKs MUST be removed from sops and `hosts/rog/secrets.nix`. Neither `PASSWORD` nor `PASSWORD_HASH` MUST exist.

#### Scenario: sops rotation [rog]

- GIVEN `secrets/host/rog/wireguard.yaml`
- THEN it MUST contain `wireguard/oauth_client_secret`
- AND MUST NOT contain `server_private_key`, peer PSKs, or any password hash

#### Scenario: issuer key [rog]

- GIVEN `secrets/host/rog/authelia.yaml`
- THEN it MUST contain `authelia/oidc_issuer_private_key` (RSA PEM)

### Requirement: Legacy cleanup

The system MUST remove `bin/export-wireguard-configs` and the legacy peer scripts (`add-wireguard-peer`, `remove-wireguard-peer`, `generate-thinkpad-wireguard`) with their `pkgs/nixos-scripts` registrations, and clear `/etc/wireguard/clients/` and `~/Documents/wireguard/`.

#### Scenario: No leftovers [rog]

- GIVEN the change is fully applied
- THEN none of the legacy `bin/` scripts MUST exist on PATH
- AND `/etc/wireguard/clients/` and `~/Documents/wireguard/` MUST be empty or absent

### Requirement: Rollback affordance

The removed declarative configuration SHALL remain recoverable from git history, including encrypted sops keys.

#### Scenario: Recoverable [rog]

- GIVEN the change is deployed and found faulty
- WHEN an operator reverts the change commits
- THEN prior `wg0`, peers, and sops keys MUST be restorable from git history
