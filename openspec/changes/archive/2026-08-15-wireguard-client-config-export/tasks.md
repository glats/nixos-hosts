# Tasks: WireGuard client config export to ~/Documents

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~45 (40-line script + 2-line registration) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: Yes
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Script + registration + verification | PR 1 | `nix flake check --no-build` | Manual `export-wireguard-configs` run on rog (per spec scenarios) | Delete `bin/export-wireguard-configs` + its cp/chmod block; `rm -rf ~/Documents/wireguard` |

## Phase 1: Script creation — `bin/export-wireguard-configs`

- [x] 1.1 Create `bin/export-wireguard-configs` with `#!/usr/bin/env bash`, `set -euo pipefail`, fixed vars `SRC=/etc/wireguard/clients`, `DST=/home/glats/Documents/wireguard`, `OWNER=glats`, `GROUP=users`, `MODE=600` (per design draft).
- [x] 1.2 Add stages 1–2: `sudo -v` auth check and `sudo test -d "$SRC"` source guard — each exits 1 with clear stderr (spec: sudo unavailable, missing source).
- [x] 1.3 Add stages 3–4: `sudo find "$SRC" -maxdepth 1 -type f -name '*.conf' -printf '%f\n'`; empty-source guard exits 0 before mkdir/prune (spec: empty source).
- [x] 1.4 Add stage 5: `mkdir -p "$DST"` + `sudo install -o glats -g users -m 600 "$SRC/$name" "$DST/$name"` loop (spec: happy path, auto-create dir, idempotent overwrite).
- [x] 1.5 Add stage 6: `find "$DST"` list, `grep -qxF` against src, `rm -f` non-matching (spec: removed peer pruned). `chmod +x`; `bash -n` passes.

## Phase 2: Registration — `pkgs/nixos-scripts/default.nix`

- [x] 2.1 Add `cp $src/export-wireguard-configs $out/bin/` + `chmod +x $out/bin/export-wireguard-configs` in `installPhase`, alphabetically after `export-mate-config` (spec: script on PATH).

## Phase 3: Verification

- [x] 3.1 Run `format-nix`; diff limited to `pkgs/nixos-scripts/default.nix` (bash script must stay untouched by formatter).
- [x] 3.2 Run `nix flake check --no-build`; must exit 0 (spec: `export-wireguard-configs` present in `$out/bin`).
- [x] 3.3 Manual success-path checks on rog: run twice, verify 5 `.conf` in `~/Documents/wireguard/`, `stat` = `glats:users` 600, exactly one per peer (spec: happy path, auto-create dir, idempotent).
- [x] 3.4 Manual prune check on rog: temporarily remove one source `.conf`, re-run, confirm destination copy removed (spec: removed peer pruned).
- [x] 3.5 Manual failure-safety checks on rog: missing source (mv dir → non-zero + stderr, destination intact), empty source (exit 0, exports untouched), sudo failure (non-interactive → non-zero + error) (spec: missing source, empty source, sudo failure).
