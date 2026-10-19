# Nix binary cache (thinkcentre)

Thinkcentre acts as a LAN Nix binary cache: it serves its own `/nix/store` through Harmonia behind ncps, prewarms every host's closure while idle, and accepts pushes from macm5. rog exposes it off-LAN at `https://cache.glats.org` with basic auth. All hosts (rog, t14, macm5) read from it — thinkcentre never reads its own cache.

## Quick path

1. On a Linux host, check reachability: `curl http://172.16.0.11:8501/nix-cache-info`.
2. Off-LAN, check the remote path: `curl -n https://cache.glats.org/nix-cache-info` (netrc user `nix-cache`).
3. After a change on macm5: `nixos-build switch` pushes the new system to the cache automatically.

## Architecture

| Component | Host | Port / URL | Notes |
|---|---|---|---|
| Harmonia | thinkcentre | `:5000` | Serves thinkcentre's `/nix/store`, signed with the sops-managed Harmonia key |
| ncps (proxy) | thinkcentre | `:8501` | In front of Harmonia (`http://127.0.0.1:5000`) plus the upstream substituters; upstream caches stay at default priority 40 |
| nginx vhost | rog | `https://cache.glats.org` | Wildcard ACME `*.glats.org`; basic auth (htpasswd); proxies to `http://172.16.0.11:5000` (Harmonia) |
| Linux clients | rog, t14 | — | `linux/system/base/nix-cache-client.nix` |
| Darwin client | macm5 | — | `darwin/system/nix-cache-client.nix` (Determinate Nix, `nix.enable = false`) |

Public keys and URLs live in `shared/nix-cache.nix`; the modules import it, so editing the public key there is the single source of truth.

## Substituter priorities

| Cache | Priority | Purpose |
|---|---|---|
| LAN ncps `http://172.16.0.11:8501?priority=30` | 30 | Fastest, tried first on LAN |
| Upstream (cache.nixos.org, cachix) | 40 | Default nixpkgs order |
| Remote `https://cache.glats.org?priority=45` | 45 | Off-LAN fallback via rog; never preferred over LAN or upstream |

Thinkcentre is **not** a client of its own cache — it has no `nix-cache-client` module.

Off-LAN degradation comes from the existing shared Nix resilience settings (`shared/nix-resilience.nix`: `connect-timeout = 5`, `fallback = true`): the LAN URL times out silently after 5 s when the host is not on the LAN, and nix proceeds with the next substituter.

Authentication: Linux clients use `nix.settings.netrc-file` pointing at the sops-deployed netrc; macm5 uses `determinateNix.determinateNixd.authentication.additionalNetrcSources` (Determinate Nix rejects `netrc-file` inside `customSettings`).

## Prewarm

A systemd timer on thinkcentre (`nix-cache-prewarm.service` / `nix-cache-prewarm.timer`) runs `nix-cache prewarm` with the repo's operational CLI (`pkgs/nixos-scripts/cmd/nix-cache`).

- Timer: `OnBootSec = 15m`, then every `6h` (`OnUnitActiveSec`), `RandomizedDelaySec = 15m`, `Persistent = true`.
- Flake: `git+https://github.com/glats/nixos-hosts?ref=master`; state dir `/var/lib/nix-cache-prewarm`.
- Idle guard: the service skips the whole run when the 1-minute load average exceeds `--max-load 2.0`; it also runs with `Nice = 19`, `IOSchedulingClass = idle`, and thinkcentre sets `nix.daemonCPUSchedPolicy = "idle"` and `nix.daemonIOSchedClass = "idle"`.
- Two variants per run, both keeping GC roots as out-links under `/var/lib/nix-cache-prewarm/roots/`:
  - `current`: the build at the `origin/master` flake lock — `nixosConfigurations.{rog,t14,thinkcentre}` toplevels and `homeConfigurations.{rog,t14,thinkcentre}` activation packages. A failed Linux build here fails prewarm.
  - `next`: a scratch clone under `/var/lib/nix-cache-prewarm/next` after `nix flake update`, same outputs, always best-effort so a broken upgrade never fails the service.
- macm5 is **substitute-only** in prewarm (`--option max-jobs 0 --keep-going`): thinkcentre cannot build `aarch64-darwin`, so darwin closures are pulled from upstream instead. Prewarm failures for macm5 are warnings only.

## macm5 push

Thinkcentre cannot build aarch64-darwin, so macm5 publishes what it builds locally (thinkcentre includes `glats` in `nix.settings.trusted-users` for this reason).

Two mechanisms, both best-effort — a push failure only warns and never changes the command's exit code:

- `nix-cache push` — runs `nix copy --no-check-sigs --to ssh-ng://glats@thinkcentre` (default path `/run/current-system`; pass store paths to push others). Use `--strict` to make a copy failure fatal.
- `nixos-build` hook — after a **successful** darwin applying operation (`switch`, `upgrade`, `safe`; `boot`/`test` are unsupported on darwin and never push), `nixos-build` performs the same push automatically. It never pushes on Linux hosts, after `dry`/`check`/`build`, or after a failed build. Opt out with `NIX_CACHE_PUSH=0` (see `nixos-build help`).
- `nix-cache push --strict` exits non-zero on copy failure; the nixos-build hook is always best-effort.

Only the exact destination `ssh-ng://glats@thinkcentre` skips signature checks for uploads: locally built Darwin paths can be unsigned, and this transfer trusts the source machine through authenticated SSH as the trusted user `glats`. SSH host verification remains enabled. Custom destinations retain signature checks, and this does not change global `require-sigs` or verification when downloading from caches.

## Secrets layout

All secrets are sops-encrypted; never decrypt them (`sops` encrypt/edit only through the repo's `.sops.yaml` rules).

| sops file | Keys | Purpose |
|---|---|---|
| `secrets/host/thinkcentre/nix-cache.yaml` | `nix-cache/harmonia_signing_key` | Harmonia `signKeyPaths` (NAR signing) |
| | `nix-cache/ncps_signing_key` | ncps `cache.secretKeyPath` (proxy signature) |
| `secrets/host/rog/nix-cache.yaml` | `nix-cache/htpasswd` | bcrypt htpasswd for `cache.glats.org` (user `nix-cache`), deployed owned by nginx `0400` |
| | `nix-cache/netrc` | rog's own netrc so it can use the remote substituter |
| `secrets/host/t14/nix-cache.yaml` | `nix-cache/netrc` | `machine cache.glats.org login nix-cache` |
| `secrets/host/macm5/nix-cache.yaml` | `nix-cache/netrc` | same netrc for macm5 |

Each file is encrypted with the admin age key plus the host key; `.sops.yaml` has creation rules for `secrets/host/{rog,thinkcentre,t14,macm5}/.+` placed before the generic rules.

## Key rotation

1. Generate a new key on a trusted machine: `nix-store --generate-binary-cache-key thinkcentre-harmonia-<n> harmonia.key harmonia.pub` (same shape for the ncps key).
2. Open the sops file for editing rather than decrypting it by hand: `sops secrets/host/thinkcentre/nix-cache.yaml` and replace the `harmonia_signing_key` (or `ncps_signing_key`) value.
3. Update the matching `publicKey` in `shared/nix-cache.nix`.
4. Rebuild thinkcentre with `nixos-build switch`, then rebuild the clients and update the trusted public key there — until clients trust the new public key, paths signed with it raise "untrusted key" warnings.
5. Preconditions: run the rotation on a machine holding the sops admin age key; the usual sops workflow (`.sops.yaml` creation rules) applies.

Basic-auth rotation (rog + clients):

1. Generate a new password and hash: `htpasswd -BnC 10 nix-cache`, then `sops secrets/host/rog/nix-cache.yaml` and replace `nix-cache/htpasswd`.
2. Rebuild rog (`nixos-build switch`).
3. Put the new password line (`machine cache.glats.org login nix-cache password <new>`) into `nix-cache/netrc` via sops in `secrets/host/{rog,t14,macm5}/nix-cache.yaml`.
4. Rebuild t14 and macm5.

## Troubleshooting

| Symptom | Check |
|---|---|
| No cache hits on LAN | `curl http://172.16.0.11:8501/nix-cache-info` on a LAN host |
| Remote cache unreachable | `curl -n https://cache.glats.org/nix-cache-info` (uses the netrc); confirms ACME cert, basic auth, and the rog → Harmonia proxy. Without `-n` expect `401` — that proves auth is on |
| Auth failures with basic auth | the htpasswd blob was regenerated without updating the netrc files, or vice versa |
| Untrusted key warnings | compare the nix error's key with `shared/nix-cache.nix`; a key rotation without a client rebuild is the usual cause |
| Prewarm not running | `systemctl status nix-cache-prewarm.timer` (next trigger), `journalctl -u nix-cache-prewarm -n 100` |
| Prewarm skipped | the log line `prewarm skipped: load average ... > ...` means the idle guard tripped; wait for the next timer activation |
| Push failures in nixos-build | `WARNING: push failed (best-effort, continuing): ...` on stderr; the build result is still valid — see `nix-cache push --strict` to debug, and check thinkcentre's `nix.settings.trusted-users` |
