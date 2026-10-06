# Exploration: Droppy declarative music mount and user account

## Goal (restated)

1. Expose `/run/media/library/music` inside the Droppy container, preserving existing files. **Read-only (`:ro`) is now user-approved.**
2. Add a normal (non-privileged) user `shrike` with a user-specified password, managed **exactly as `glats` is managed today** — not via an assistant-selected new secret mechanism.
3. Preserve the existing `glats` account and all hashes, privileges, sessions, and shared links.
4. Never include the actual password in any output or persistent artifact.

## Credential lifecycle of `glats` (verified, second pass)

The `glats` Droppy account is **runtime Droppy-native `db.json` only**. There is no declarative secret, bootstrap, or sops management for it.

Evidence:

- `git log` for `linux/system/services/web/droppy.nix` shows exactly two commits: `31b451f T3: relocate host and feature services` (the structural refactor move) and `6d2b283 fix(droppy): normalize upload permissions so nginx can serve them`. Neither adds account seeding, a secret, or a bootstrap script.
- No `db.json` reference exists anywhere in the repository outside the pending inline code; no script writes or seeds `db.json`.
- No Droppy secret existed before the new untracked `secrets/host/rog/droppy-users.json`. The other `secrets/host/rog/*` files are authelia, cloudflare, ddclient, guacamole, openfang, romm, and wireguard — none Droppy-related.
- Droppy's documented first-run behavior (`droppyjs/droppy` README) creates the first account via an interactive prompt; credentials live only in `config/db.json`, persisted by the host bind mount `/srv/glats/droppy/config`. The repo touches that path only for ownership (`droppy-permissions` → `glats:users`), never for credentials.
- The NixOS system user `glats` (`linux/system/base/users.nix:26`) is a **distinct** entity from the Droppy app account `glats`; only the NixOS system user is declarative.

Conclusion: the source of truth for `glats`'s Droppy password is the hash in the live `db.json`, created at runtime by Droppy itself. It has never been sops-managed. The pending `droppy-users.json` + `preStart` would introduce a **new** sops source of truth that did not previously exist for Droppy accounts — this is exactly the "assistant-selected new secret mechanism" the user disallowed.

## Conflict and resolution

"Everything declarative via Nix" and "manage `shrike` exactly as `glats`" are mutually exclusive: `glats` has no declarative lifecycle — its account and password exist only in runtime `db.json`. The user's latest instruction resolves the conflict in favor of matching `glats` (runtime-native). Therefore the assistant-selected sops/preStart/encrypted-seed mechanism is **rejected**.

## Current State

The module `linux/system/services/web/droppy.nix` (imported only by `hosts/rog/default.nix:74`) defines one oci-container (`ghcr.io/droppyjs/droppy:v1.3.1`, host port `9002:8989`) with volumes `/srv/glats/droppy/config:/config` and `/run/media/stuff/droppy:/files`. The container entrypoint (`docker-start.sh`) maps `/config` → `~/.droppy/config` and `/files` → `~/.droppy/files`, and runs as a `droppy` user whose UID defaults to `0` (root) when `UID` is unset.

Uncommitted pending additions (unapproved candidates, **not to be edited now**):

- A `"/run/media/library/music:/files/music:ro"` volume line (read-only music — now approved in principle).
- A `sops.secrets.droppy-users` block (`format = "json"`, `key = ""`, `mode = "0400"`, `restartUnits = [ "docker-droppy.service" ]`).
- A `systemd.services.docker-droppy.preStart` that merges the sops-decrypted user map add-only into `db.json` via jq `.users = ($managed[0] + .users)` (existing users win), with atomic temp-file rename.
- A new untracked `linux/system/services/web/droppy.test.py` exercising that merge expression.

`.sops.yaml` already has a `path_regex: secrets/host/rog/.+` creation rule, so the new `secrets/host/rog/droppy-users.json` needs no new creation rule (irrelevant if it is removed).

Live runtime (observed, NOT to change now): `shrike` was already added to the live DB `/srv/glats/droppy/config/db.json` via Droppy's native DB API; `glats` was verified unchanged; a protected DB backup exists from approximately `20261005-192211`; the temporary `90-music.conf` override was removed and the service restarted from the original declarative `ExecStart` — no music volume is currently applied at runtime.

## Serving topology

`drop.glats.org` (`nginx.nix:402`) proxies `/` to `127.0.0.1:9002` (Droppy app). The `glats.org` and `localhost` vhosts alias `/uploads/` and `/files/` directly to `/run/media/stuff/droppy/nginx/` with fancyindex. A music mount at `/files/music` is reachable through the Droppy app, not the nginx fancyindex alias. Precedent for read-only media mounts: `jellyfin.nix`, `romm.nix`, `gonic.nix`.

## Source-verified Droppy facts (droppyjs/droppy @ v1.3.1)

- DB file `~/.droppy/config/db.json`, shape `{ users: {...}, sessions: {...}, links: {...} }`.
- User record on disk is exactly `{ hash: string, privileged: boolean }` (no `_id` on disk).
- Password hash: `salt = crypto.randomBytes(4).toString("hex")` (8 hex chars); `hash = HMAC-SHA256(key = password + salt + username, empty message)` as hex, stored as `"hash$salt"`.
- Droppy pretty-prints `db.json` and watches it only while running; runtime account writes overwrite, so any declarative seed must be add-only with existing-users-win — but no declarative seed is being adopted (see Recommendation).
- Accounts are created at runtime: first account via first-run prompt; additional accounts via the options UI or CLI.

## Research sources and honest availability

- **Context7**: only `/websites/getdroppy_app` (unrelated macOS app); no droppyjs docs. Facts verified from `droppyjs/droppy` source.
- **GitHub (get_me = glats)**: issue search for droppyjs/droppy account management returned 0 relevant issues; source files fetched instead.
- **Exa**: sops-nix official docs (Mic92/sops-nix) — relevant only to the rejected secret mechanism.

## Affected Areas

- `linux/system/services/web/droppy.nix` — the read-only music volume is the only change to keep; the sops secret and preStart are candidates to remove.
- `secrets/host/rog/droppy-users.json` — new untracked secret; candidate to remove.
- `linux/system/services/web/droppy.test.py` — new unrun test; candidate to remove (tests the rejected preStart merge).
- `hosts/rog/default.nix` — import line 74 (unchanged).
- `linux/system/services/web/nginx.nix` — serving topology context only; no change required.

## Approaches

1. **Runtime-native account (chosen, matches `glats`)** — create `shrike` once via Droppy's native UI/CLI, exactly as `glats` was created; the credential lives only in runtime `db.json`. Declarative change is the music read-only mount only.
   - Pros: identical lifecycle to `glats`; no new secret mechanism; no password anywhere in the repo; minimal scope.
   - Cons: `shrike` is not reproducible from Nix; it is an operational one-time action (documented in a runbook/comment), same as `glats` today.
   - Effort: Minimal.

2. **Hash-in-secret sops + add-only jq preStart (pending inline work)** — rejected by the user's "exactly as `glats`" requirement; introduces a new secret mechanism.
3. **Password-in-secret sops + compute hash at preStart** — rejected for the same reason.
4. **Dedicated Go/Nix helper** — rejected (overkill; also a new mechanism).

## Recommendation

Adopt Approach 1. The declarative change shrinks to the **read-only music mount** (`/run/media/library/music:/files/music:ro`, approved). `shrike` is created at runtime via Droppy's native interface exactly like `glats`, with no secret, no preStart, and no bootstrap; document this as an operational note so it is not mistaken for declarative provisioning. The pending `sops.secrets.droppy-users`, `docker-droppy.preStart`, `droppy.test.py`, and the encrypted `secrets/host/rog/droppy-users.json` should be **removed in the apply phase** (not edited now); the already-hot-provisioned live `shrike` account remains as the runtime record, mirroring `glats`.

## Risks

- None from the music mount beyond the accepted bind-mount-empty-dir risk shared with jellyfin/romm.
- The live `shrike` account was already hot-provisioned; a runtime-native approach keeps it consistent with `glats`, so no drift risk.
- Removing the pending files must not touch the unrelated dirty OpenCode/openspec/doc changes.

## Required acceptance tests

1. `nix fmt -- linux/system/services/web/droppy.nix` then `nix flake check --no-build`.
2. `nix eval .#nixosConfigurations.rog.config.system.build.toplevel.drvPath`.
3. `nixos-build dry` (or `safe`) — build without activation; avoid full-system activation of unrelated dirty changes.
4. Post-approval runtime check: music browsable read-only at `drop.glats.org`; `glats` unchanged; `shrike` present and able to log in with the user's password (verified by the user, not automated here).

## Explicit remaining approvals

1. Music read-only — **approved**.
2. `shrike` managed exactly as `glats` (runtime-native, no secret) — **confirmed by the user**; the one narrow confirmation to close the loop: that "declarative" now applies only to the music mount, and `shrike`'s account/password will live only in runtime `db.json` (not reproducible from Nix), mirroring `glats`.
3. Remove the pending sops/preStart/encrypted-seed/test in the apply phase (recommended) — await apply-phase approval.

## Ready for Proposal

Yes. Scope is now minimal and unambiguous: keep the read-only music volume, drop the declarative account-seeding mechanism, and treat `shrike` as a runtime-native account identical to `glats`. The orchestrator should present the proposal on that basis and confirm the single clarification above before spec/design.
