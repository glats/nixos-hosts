# Tasks: Parallel Isolated OpenCode V2 Runtime

## Review Workload Forecast

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Focused test command | Runtime harness | Rollback boundary |
|------|------|---------------------|-----------------|-------------------|
| 1 | Delete stale `cmd/opencode2`; deliver `opencode-v2` seed `--v2` | Go suite | `nix build` per platform; versions 2.0.14 / 1.18.32 | Restore `cmd/opencode2/` + delivery; revert seed |
| 2 | Generator v1/v2 params; V1 byte-identical | `nix flake check --no-build` | `diff -r` opencode config | Revert generator params |
| 3 | `mkV2Environment`, wrappers, hook | Same + `nix flake check --no-build` | Host smoke matrix | Remove wrappers/options/hook; V1 untouched |
| 4 | Supervised V2: systemd user svc (Linux) + launchd (macm5); cfg-change restart | RED asserts + `nix flake check --no-build` | `systemctl --user` / `launchctl list`; kill server → recovery | Remove supervisor declarations; V1 untouched |

2026-09-25 update: design now OS-supervises V2; old activation restart superseded, reopened. Remaining ~150–250 lines.

## Phase 1: RED Tests (threat-matrix, before production)

- [x] 1.1 Seed RED tests in `pkgs/nixos-scripts/cmd/install-opencode-auth-seed/main_test.go`: `--v2` → dir 0600; V1 `auth.json` untouched; bad destination refused.
- [x] 1.2 RED: `cmd/opencode2` absent from `pkgs/nixos-scripts/default.nix` build.
- [x] 1.3 Wrapper RED: all `mkV2Environment` exports, args/cwd forwarded, no `--standalone`.
- [x] 1.4 Hook RED: restart only on changed V2 `opencode.json` cmp; unchanged → none; failure visible, no V1 fallback.
- [x] 1.5 Gate RED: default wrapper sets `OPENCODE_DISABLE_PROJECT_CONFIG=1`; `opencode2-project` exits nonzero on V1-SDK package.json.
- [x] 1.6 RED asserts (new): `shared/opencode.nix` — Linux `systemd.user.services.opencode2` foreground w/ `mkV2Environment` + `Restart=on-failure`; macm5 `launchd.agents.opencode2` run-at-load/keep-alive; activation launches supervisor (no `service` exec) on changed-cmp only; failed restart leaves stamp absent; one shared env.
  Test: asserts fail on current tree (exec hook, no units), then green with `nix flake check --no-build` after 3.6–3.10.

## Phase 2: Package & Delivery

- [x] 2.1 Delete `pkgs/nixos-scripts/cmd/opencode2/`, drop its `default.nix` entry; green 1.2 + suite.
- [x] 2.2 Create `pkgs/opencode-v2/default.nix`: hash-pinned `fetchurl`, Linux `autoPatchelfHook` + `makeBinaryWrapper`; no postinstall/npm/bun.
- [x] 2.3 Register in `lib/packages.nix`, `overlays/linux.nix`, `overlays/darwin.nix`.
- [x] 2.4 Deliver via `linux/system/base/profiles/dev.nix` + `darwin/home/packages.nix` (4 hosts).
- [x] 2.5 Repair `pkgs/opencode/default.nix`: refresh four v1.18.32 sha256 pins + fix `updateScript` awk regex; keep `version = "1.18.32"`.
- [x] 2.6 Extend `install-opencode-auth-seed` with `--v2`: one-way read-only V1 `auth.json` → 0600 V2 input; green 1.1 + suite.

## Phase 3: Generator & Isolation

- [x] 3.1 Parameterize generator for v1/v2 records; V2 emits only native global config, no plugins/commands/skills/npm tree.
- [x] 3.2 V1 byte-identical: regenerate, compare to baseline.
- [x] 3.3 Add single-source `mkV2Environment` in `shared/opencode.nix`.
- [x] 3.4 Add `opencode2` + `opencode2-project` wrappers in `shared/shell-aliases.nix`; project gate + `home.opencode.v2` options.
- [x] 3.5 Add cmp-guarded `home.activation` hook: `opencode2 service restart` on V2 config change.
  Superseded 2026-09-25: OS supervision per updated design; reopened as 3.6–3.9.
- [x] 3.6 Refactor `mkV2Environment` in `shared/opencode.nix`: drop non-readable option; render shell (wrappers) + service-env for systemd/launchd from one source.
- [x] 3.7 Declare `systemd.user.services.opencode2` (Linux): foreground server, rendered env, `Restart=on-failure`, enabled user session.
- [x] 3.8 Declare `launchd.agents.opencode2` (macm5): same binary/env, run-at-load, keep-alive.
- [x] 3.9 Rework activation hook: changed-cmp → restart supervisor (`systemctl --user restart opencode2` / `launchctl kickstart -k`); no `service` exec; stamp after success.
- [x] 3.10 Verify: `nix flake check --no-build` + `nix eval` rendered units; green 1.6.

## Phase 4: Verification

- [x] 4.1 Go suite; `nix fmt` touched files; `nix flake check --no-build`.
- [ ] 4.2 Toplevels: 3 `nixosConfigurations` + `darwinConfigurations.macm5`.
- [ ] 4.3 Per-host smoke: versions, no V1-dir writes, clean credentials, V2-root server, gate refusal, one-way seed, changed-only restart + supervised recovery.

## Phase 5: Cleanup

- [x] 5.1 No leftover `--standalone`, daemon units, or V1-branch code.
- [x] 5.2 Wrapper comment: launcher removed in Phase 2; V2 GA approach.
