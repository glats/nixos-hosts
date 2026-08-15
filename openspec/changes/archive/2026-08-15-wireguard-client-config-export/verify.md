# Verification Report: wireguard-client-config-export

- **Change**: wireguard-client-config-export
- **Mode**: hybrid (Engram + openspec)
- **Verdict**: PASS WITH WARNINGS
- **Strict TDD**: false (no TDD runner)

## Completeness

| Artifact | Present | Status |
|----------|---------|--------|
| proposal.md | yes | complete |
| specs/wireguard-config-export/spec.md | yes | 6 requirements / 8 scenarios (all `[rog]` tagged) |
| design.md | yes | complete |
| tasks.md | yes | Phases 1–2 + 3.1–3.2 `[x]`; 3.3–3.5 (manual runtime) executed during this verify |
| Implemented code | yes | `bin/export-wireguard-configs` (new) + `pkgs/nixos-scripts/default.nix` (modified) |

> Note: orchestrator prompt stated "7 requirements / 9 scenarios". Actual spec count is **6 requirements / 8 scenarios** (recounted line-by-line from the delta spec). Envelope totals below reflect the actual count.

## Build / Test Evidence

| Command | Exit | Result |
|---------|------|--------|
| `bash -n bin/export-wireguard-configs` | 0 | PASS (syntax valid) |
| `nix flake check --no-build` (test_command) | 0 | PASS — all checks passed; `nixos-scripts` + formatter derivations evaluate |
| `nixfmt` (flake formatter, nixfmt 1.4.0) on `pkgs/nixos-scripts/default.nix` | 0 | PASS — no diff (already correctly formatted) |
| `nix build .#packages.x86_64-linux.nixos-scripts` | 1 | **FAIL** — pre-commit artifact (see W-1) |

- `test_output_hash` (flake check output): `842796a02f3570cd342a08242ab32e31017c1b731147486ed95f71c8ac3d15a7`
- `build_output_hash` (nixos-scripts build log): `e4b2199039701eb013ae33493f6959d182a99f72e920f38c825922ae8f7df5c1`

### Runtime harness (host = `rog`, wireguard server host)

`sudo -n true` succeeded non-interactively (cached/NOPASSWD), so runtime checks were executed. Source `/etc/wireguard/clients/` contained exactly the 5 expected peers: `oneplus9.conf, mac.conf, thinkpad.conf, samsung.conf, thinkphone.conf`.

## Spec Compliance Matrix

| # | Requirement / Scenario | Verification method | Result |
|---|------------------------|---------------------|--------|
| 1 | On-demand export — Happy path [rog] | real run #1 | **PASS** — "Exported 5 config(s)"; 5 files, all `600 glats:users` |
| 2 | On-demand export — Destination auto-created [rog] | real run #1 (DST absent beforehand) | **PASS** — `~/Documents/wireguard/` created + populated |
| 3 | Idempotent overwrite — Re-run no duplicates [rog] | real run #2 + `sudo cmp` | **PASS** — still 5 files, all byte-identical to source, no dupes |
| 4 | Stale-file pruning — Removed peer pruned [rog] | fake stale `ghost-test.conf` + run #3 | **PASS** — "pruned 1 stale", ghost removed, 5 real remain |
| 5 | Missing/empty source — Missing source dir [rog] | sudo stub (`test -d`→fail) | **PASS** — exit 1, stderr "source directory not found", DST sha256 unchanged |
| 6 | Missing/empty source — Empty source dir [rog] | sudo stub (`find`→empty) | **PASS** — exit 0, "destination left untouched", DST sha256 unchanged |
| 7 | sudo failure handling — sudo unavailable [rog] | sudo stub (`-v`→fail) | **PASS** — exit 1, stderr "sudo authentication failed" |
| 8 | Script registration — Script on PATH [rog] | `nix flake check --no-build` + installPhase inspection | **PASS** — flake check exit 0; `cp`+`chmod +x` lines present (see W-1) |

All 8 scenarios verified. Runtime scenarios 1–7 were executed for real (or via faithful sudo stub for the failure-safety branches, exercising the script's actual control flow without mutating the authoritative source dir). Destination integrity (sha256) was snapshotted before and after all failure-safety tests and was unchanged.

## Correctness (code inspection, line-by-line)

| Guard | Spec requirement | Evidence |
|-------|------------------|----------|
| `sudo -v` auth check (lines 13–17) | sudo failure → non-zero + clear error | `if ! sudo -v; then echo ... >&2; exit 1` — verified at runtime (scenario 7) |
| `sudo test -d "$SRC"` (lines 19–23) | missing source → non-zero + stderr, DST untouched | exit 1 before any destination op — verified at runtime (scenario 5) |
| `src_files=$(sudo find ...)` empty guard `[ -z ]` exit 0 (lines 25–32) | empty source → exit 0, no prune | exits BEFORE `mkdir`/prune — verified at runtime (scenario 6) |
| `mkdir -p "$DST"` (line 34) | auto-create destination | verified at runtime (scenario 2) |
| `sudo install -o glats -g users -m 600` (line 40) | ownership `glats:users`, mode `600` | all 5 files `600 glats:users` — verified at runtime (scenario 1) |
| prune loop `grep -qxF` + `rm -f` (lines 44–52) | remove stale DST `.conf` only | ghost-test pruned, real peers kept — verified at runtime (scenario 4) |
| `set -euo pipefail` + quoted expansions | no crash on edge cases | confirmed across all scenarios |

## Design Coherence

| Design decision | Matches implementation? |
|-----------------|------------------------|
| sudo read of root-only source (`sudo find` + `sudo install`) | yes |
| Single sudo prompt (`sudo -v` up-front) | yes |
| Empty-source guard before `mkdir`/prune | yes |
| `install -o -g -m` single command | yes |
| `grep -qxF` prune compare (no hardcoded peer list) | yes |
| Self-contained (no `lib/common.sh`) | yes |
| Registration alphabetically after `export-mate-config` | yes (lines 31–32 of default.nix) |

No design deviation. `linux/system/services/network/wireguard.nix` untouched (out of scope, correct).

## Issues

### WARNING — W-1: package build fails until script is git-staged (pre-commit artifact, NOT a code defect)

`nix build .#packages.x86_64-linux.nixos-scripts` exits 1:

```
cp: cannot stat '/nix/store/...-bin/export-wireguard-configs': No such file or directory
```

Root cause: `bin/export-wireguard-configs` is **untracked** in git (`git ls-files --error-unmatch` fails; `git check-ignore` reports "not ignored"). Nix flakes include only git-tracked files in the source, so the store archive of `bin/` omits the new script, and the installPhase `cp` fails. `nix flake check --no-build` passes only because it evaluates without building.

Resolution: `git add bin/export-wireguard-configs` (part of delivery/PR). Once tracked, the package builds and `$out/bin/export-wireguard-configs` is produced. No code change needed. Scenario 8 is proven by installPhase inspection + flake-check evaluation; final `$out/bin` confirmation is deferred to post-staging build.

### WARNING — W-2: unrelated modified file in working tree

`linux/system/base/profiles/core.nix` is modified (adds `ocrmypdf` and `kdePackages.okular`). This is unrelated to `wireguard-client-config-export` and must NOT be included in this change's commit/PR.

### SUGGESTION — S-1

`nix fmt --check` is not supported by the installed nix CLI ("unrecognised flag '--check'"). Formatting was instead verified by running the flake formatter (`nixfmt` 1.4.0) against a copy and confirming no diff. No action required; noted for future verify runs.

## Git Hygiene

| Path | Expected | Actual |
|------|----------|--------|
| `bin/export-wireguard-configs` | new (untracked) | correct — but untracked (see W-1) |
| `pkgs/nixos-scripts/default.nix` | +3 lines (cp/chmod registration) | correct |
| `openspec/changes/wireguard-client-config-export/` | SDD artifacts | correct |
| `linux/system/base/profiles/core.nix` | should NOT be present | **unexpected** (see W-2) |

## Final Verdict

**PASS WITH WARNINGS** — all 6 requirements and 8 scenarios verified; implementation code is correct and matches spec + design. Two non-code warnings: (W-1) package build requires `git add bin/export-wireguard-configs` before the deliverable builds; (W-2) unrelated `core.nix` edit must be excluded from this change's commit.
