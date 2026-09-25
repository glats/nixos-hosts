# Tasks: Parallel Isolated OpenCode V2 Runtime

## Review Workload Forecast

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Focused test command | Runtime harness | Rollback boundary |
|------|------|---------------------|-----------------|-------------------|
| 1 | Delete stale `cmd/opencode2`; deliver `opencode-v2` + seed `--v2` (autonomous) | `go -C pkgs/nixos-scripts test ./...` | `nix build` per platform; versions 2.0.14 / 1.18.32 | Restore `cmd/opencode2/` + delivery items; revert seed |
| 2 | Generator v1/v2 params; V1 byte-identical | `nix flake check --no-build` | `diff -r` of `~/.config/opencode/` per host | Revert generator params |
| 3 | `mkV2Environment`, wrappers, hook | Same + `nix flake check --no-build` | Host smoke matrix | Remove wrappers/options/hook; V1 untouched |

## Phase 1: RED Tests (threat-matrix, before production)

- [x] 1.1 Go RED table tests in `pkgs/nixos-scripts/cmd/install-opencode-auth-seed/main_test.go`: `--v2` → V2 dir 0600; V1 `auth.json` unchanged; refuse bad V2 destination.
- [x] 1.2 RED test in `pkgs/nixos-scripts`: `cmd/opencode2` absent from `default.nix` build.
- [x] 1.3 Wrapper RED: all `mkV2Environment` exports (`XDG_CONFIG_HOME`→`~/.config/opencode-v2`, data/cache/state→`~/.local/opencode-v2/*`, `OPENCODE_CONFIG_DIR`, `OPENCODE_DB`, `TMPDIR`), args/cwd forwarded, no `--standalone`.
- [x] 1.4 Hook RED: restart only on changed V2 `opencode.json` cmp; unchanged → none; failure visible, no V1 fallback/write.
- [x] 1.5 Gate RED: default wrapper sets `OPENCODE_DISABLE_PROJECT_CONFIG=1`; `opencode2-project` exits nonzero on V1-SDK `$PWD/.opencode/package.json` (`@opencode-ai/plugin`), never execs.

## Phase 2: Package & Delivery

- [x] 2.1 Delete `pkgs/nixos-scripts/cmd/opencode2/` + drop its `pkgs/nixos-scripts/default.nix` entry; green Phase 1.2 + suite at 2.6.
- [x] 2.2 Create `pkgs/opencode-v2/default.nix`: hash-pinned `fetchurl` of `@opencode/cli-<os>-<arch>@2.0.14`, Linux `autoPatchelfHook` + `makeBinaryWrapper`; no postinstall/npm/bun.
- [x] 2.3 Register in `lib/packages.nix`, `overlays/linux.nix`, `overlays/darwin.nix`.
- [x] 2.4 Deliver via `linux/system/base/profiles/dev.nix` and `darwin/home/packages.nix` (4 hosts).
- [x] 2.5 V1 1.18.32 gate: repair `pkgs/opencode/default.nix` — refresh the four v1.18.32 `sha256` pins (stale v1.18.22 hashes confirmed; exploration) and correct `passthru.updateScript`'s awk regex to `/sha256 = "[^"]*"/` so bumps cannot desync; keep `version = "1.18.32"`. Verify: `nix build .#opencode` per platform; `opencode` = bare `1.18.32`.
- [x] 2.6 Extend `pkgs/nixos-scripts/cmd/install-opencode-auth-seed` with `--v2`: one-way read-only V1 `auth.json` → 0600 V2 input; green Phase 1.1 + suite.

## Phase 3: Generator & Isolation

- [x] 3.1 Parameterize `shared/opencode/runtime-config.nix` + `shared/opencode.nix` with v1/v2 records; V2 emits only native global config (`update = "disable"`), no plugins/`tui.json`/commands/skills/npm tree.
- [x] 3.2 V1 byte-identical: capture `~/.config/opencode/` baseline, regenerate, `diff -r` clean.
- [x] 3.3 Add single-source `mkV2Environment` in `shared/opencode.nix`.
- [x] 3.4 Add `opencode2` + `opencode2-project` wrappers in `shared/shell-aliases.nix`; project gate + `home.opencode.v2` options (`enable`, `runtimeRoot`, `projectConfigCommand`).
- [x] 3.5 Add cmp-guarded `home.activation` hook: run `opencode2 service restart` only on V2 `opencode.json` change; report failures.

## Phase 4: Verification

- [x] 4.1 `go -C pkgs/nixos-scripts test ./...`; `nix fmt` touched files; `nix flake check --no-build`.
- [ ] 4.2 Toplevels: 3 `nixosConfigurations` + `darwinConfigurations.macm5`.
- [ ] 4.3 Per-host smoke: versions, no fresh-launch V1-dir writes, clean credentials, V2-root server, gate refusal, one-way seed, changed-only restart (rog, thinkcentre, t14, macm5).

## Phase 5: Cleanup

- [x] 5.1 No leftover `--standalone`, daemon units, or V1-branch code.
- [x] 5.2 In wrapper comments: launcher removed in Phase 2; V2 GA approach.
