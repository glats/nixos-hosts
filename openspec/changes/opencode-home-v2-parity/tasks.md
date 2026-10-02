# Tasks: OpenCode V2 Scoped Home Launcher Parity

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 650–800 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 launcher core → PR 2 wiring+regression → PR 3 docs |
| Delivery strategy | auto-chain |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: pending
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Go launcher core + RED tests | PR 1 | `go -C pkgs/nixos-scripts test ./internal/opencodehome/...` | Recorder-subprocess argv/env capture | Revert `cmd/opencode-home/` + `internal/opencodehome/` |
| 2 | `opencode2-home` wiring + config regression | PR 2 | `python3 shared/opencode/home-launcher.test.py` | macm5 home-config offline eval | Revert `shared/shell-aliases.nix` + test |
| 3 | Docs | PR 3 | `git diff --stat docs/home-link.md` | N/A (doc-only) | Revert `docs/home-link.md` |

## Phase 1: Go Launcher Core (RED first)

- [x] 1.1 RED — Write `pkgs/nixos-scripts/internal/opencodehome/launcher_test.go`: probe success/refusal/injected timeout, one-second dial bound, stderr notice, conditional HTTP(S)_PROXY, V2-only NO_PROXY loopback append, invalid `OPENCODE_HOME_BINARY` fails visibly, V1 env unchanged.
- [x] 1.2 RED — Recorder-subprocess tests: byte-for-byte argv (spaces, empty strings, option-like) with no flag injection; packaged target beats same-named PATH executables; isolation XDG vars pass through; control variable stripped.
- [x] 1.3 GREEN — Create `pkgs/nixos-scripts/internal/opencodehome/launcher.go`: injectable `net.DialTimeout` probe, child-env builder, absolute-target resolution, `syscall.Exec`, strip `OPENCODE_HOME_BINARY`.
- [x] 1.4 Modify `pkgs/nixos-scripts/cmd/opencode-home/main.go` to a thin entry calling launcher; keep package build registered in `pkgs/nixos-scripts/default.nix`.
- [x] 1.5 Run `go -C pkgs/nixos-scripts test ./internal/opencodehome/...` until green; `go vet` clean.

## Phase 2: Wiring + Generated-Config Regression

- [ ] 2.1 Regression — Create `shared/opencode/home-launcher.test.py` (pattern: `shared/opencode/v2-agents.test.py` (read-only)): eval `flake.homeConfigurations.macm5.config`; assert generated V2 isolation exports, guarded-source `opencode2-home` text, `OPENCODE_HOME_BINARY=` `${pkgs.opencode-v2}/bin/opencode2`, packaged-launcher exec, `opencode2`/`opencode2-project` preserved, MCP scrub on V1+V2, remote MCPs untouched. (Linux host evaluation and source-level macOS assertions pass; full macOS config evaluation is blocked by cross-system store realization.)
- [x] 2.2 GREEN — Modify `shared/shell-aliases.nix`: Darwin+V2-gated `opencode2-home()` subshell; guarded source of `~/.local/share/opencode-v2/environment` fails nonzero before launch; preserve existing functions.
- [x] 2.3 Run `python3 shared/opencode/home-launcher.test.py` until PASS and `python3 shared/opencode/v2-agents.test.py` stays PASS.

## Phase 3: Verification

- [x] 3.1 `nix fmt --` all touched Nix; `nix flake check --no-build`.
- [ ] 3.2 Eval `.#homeConfigurations.macm5.activationPackage.drvPath`, `.#darwinConfigurations.macm5.config.system.build.toplevel.drvPath`, and Linux `.#homeConfigurations.{rog,thinkcentre,t14}.activationPackage.drvPath`. (Linux evaluations pass; macOS evaluation is blocked by cross-system store realization.)
- [x] 3.3 `go -C pkgs/nixos-scripts test ./...` and both Python regressions pass. Actual package build passed as `/nix/store/yddpx28bv8snls8zl04wxr97rj2avs9m-nixos-scripts-1.0.0.drv` → `/nix/store/r2s06k426f58ppvswwjm4aifjgh9101r-nixos-scripts-1.0.0`. The reported failed derivation (`xdlrf3gypf2k8rm1diyydg51jmnas4yn`) used source archive `p5da7mrq33vlqxwmbr3mh35b14f43wv9-nixos-scripts`, which did not contain the then-untracked `internal/opencodehome` directory; direct Go tests used the working tree.

## Phase 4: Documentation + Cleanup

- [x] 4.1 Modify `docs/home-link.md`: V1 `opencode-home`; scoped `opencode2-home`; document private V2 server defaults for TUI/mini/run, argument handling, explicit `--server`, fallback notice, and proof limits.
- [x] 4.2 Confirm `git status -sb` shows only intended files changed; dirty worktree, no commits, no activation. (Pre-existing unrelated dirty/untracked files remain untouched.)

## Phase 5: Default Private V2 Server

- [x] 5.1 Make `opencode2-home` select private V2 mode by default for interactive TUI/mini/run without injecting flags into unrelated commands or explicit server choices.
- [x] 5.2 Add regression coverage for default TUI/run flag placement and forwarding; align the delta spec, design, and runbook with the approved default.
