# Tasks: Retire OpenCode V1

## Review Workload Forecast

Estimated changed lines: ~1,300–1,800.

Delivery strategy: exception-ok
Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: High

### Suggested Work Units

| Unit | Goal (PR) | Test / harness | Rollback boundary |
|------|-----------|------------------------|-------------------|
| 1 | Helpers (PR 1): 4.1–4.3 after RED 1.1–1.3 | `go -C pkgs/nixos-scripts test ./...`; rog `opencode-home`, `--v2` refusal, dry-run | `launcher.go`, `launcher_test.go`, `install-opencode-auth-seed/{main,main_test}.go`, `sync-opencode-remote/{main,main_test}.go` |
| 2 | Atomic Nix retirement (PR 2): 2.1–2.4 + 3.1–3.5 + RED 1.4 | `nix flake check --no-build`; V2 `opencode.json` eval diff; `home-launcher.test.py` | files of 2.2–2.4 and 3.1–3.5, plus `pkgs/opencode/`, `pkgs/opencode-npm-packages/` (not `pkgs/opencode-v2/`) |
| 3 | Docs (PR 3): 3.6 | N/A — docs only | `docs/home-link.md`, `docs/opencode-v2-final-cutover.md` |

## Phase 1: RED Tests (threat matrix)

- [x] 1.1 `pkgs/nixos-scripts/internal/opencodehome/launcher_test.go`: missing/nonexecutable/self target rejected no spawn; argv/standalone/server forwarding; proxy up/down env (S4,S5,S13).
- [x] 1.2 `pkgs/nixos-scripts/cmd/install-opencode-auth-seed/main_test.go`: default/`--v2`/invalid/API-key/conflict refused nonzero pre-fetch/decrypt/auth/backup/write; credentials/backups identical (S10,S11).
- [x] 1.3 `pkgs/nixos-scripts/cmd/sync-opencode-remote/main_test.go`: quoted/injected paths, unavailable V2 rejected pre-write; credentials/DBs excluded (S6).
- [x] 1.4 `shared/opencode/home-launcher.test.py`: drop V1 fixture; assert V2 skills/OpenFang order/activation; MCP proxy clean (S7,S12,S13).

## Phase 2: V1 Delivery Removal (atomic with Phase 3)

- [x] 2.1 Delete `pkgs/opencode/`, `pkgs/opencode-npm-packages/`; only after consumers gone (S1).
- [x] 2.2 Remove V1 entries/exports `lib/packages.nix` (55,58), `overlays/linux.nix` (19,22), `overlays/darwin.nix` (59,62).
- [x] 2.3 Remove `opencode` from `linux/system/base/profiles/dev.nix`, `darwin/home/packages.nix`; keep `opencode-v2` (S1).
- [x] 2.4 `pkgs/gentle-ai-assets/default.nix`, `pkgs/engram-assets/{default.nix,vanilla.nix}`: stop V1 plugin emission; keep V2 (S7,S8).

## Phase 3: V1 Config / Options / Plugins Trim (atomic with Phase 2)

- [x] 3.1 `shared/opencode.nix`: remove `v1RuntimeConfig`, V1 `mkRuntimeConfig` call (248–257), no dangling `cfg`/`imports`; keep `enable` packages/keys and V2.
- [x] 3.2 `shared/opencode/runtime-config.nix`: delete V1 `else` (313–570) and V1 `let` (91–133); re-source `syncOpencodeSkillsToOpenfang` from V2 (S8).
- [x] 3.3 Delete `shared/opencode/plugins.nix`, `shared/opencode/rtk.ts` after consumers; retain `shared/opencode/agents.nix`, `shared/opencode/permissions.nix` (read-only) — V2 needs `cfg.agents`/`cfg.permissions`; update `imports` (S1).
- [x] 3.4 `shared/opencode/providers-base.nix`: drop V1 `allProviders`/`disabledProviders`; keep `providerAllowlist`,`nvidiaProvider` (S3).
- [x] 3.5 `shared/opencode-profile.nix`, `shared/shell-aliases.nix`: drop V1 assignments/comments; keep `opencode2`,`opencode2-project`,`opencode2-home` (S3).
- [x] 3.6 `docs/home-link.md`, `docs/opencode-v2-final-cutover.md`: current V2 instructions; preserve dirty edits.

## Phase 4: Helpers

- [x] 4.1 `pkgs/nixos-scripts/internal/opencodehome/launcher.go`: absolute isolated V2 default; reject missing/nonexecutable/self pre-probe (RED 1.1 first) (S4,S5).
- [x] 4.2 `pkgs/nixos-scripts/cmd/install-opencode-auth-seed/main.go`: refuse legacy calls incl `--v2` pre-fetch/decrypt/auth/backup/write; advise `opencode2-home auth login openai` (RED 1.2 first) (S10,S11).
- [x] 4.3 `pkgs/nixos-scripts/cmd/sync-opencode-remote/main.go`: V2 dirs/defaults, preflight remote V2, exclude credentials/DBs, drop V1 npm/provider/plugin steps (RED 1.3 first) (S6).

## Phase 5: Verification

- [x] 5.1 `nix fmt` touched files; `nix flake check --no-build`; `nix build .#packages.x86_64-linux.gentle-ai-assets .#packages.x86_64-linux.engram-assets` (S6). Additional sandbox regression gate: `nix build .#packages.x86_64-linux.nixos-scripts --no-link --print-out-paths` passed after declaring `jq` as a test-only native input.
- [x] 5.2 `go -C pkgs/nixos-scripts test ./...`; `shared/opencode/home-launcher.test.py` (S6,S12,S13).
- [ ] 5.3 Evaluate separately 3 Linux toplevels, Darwin toplevel, 4 HM drvPaths (S1–S3,S6). PARTIAL: all three Linux and Linux HM evaluations passed; macm5 Darwin/HM explicitly DEFERRED by user until rog is finished (prior Linux attempt failed platform mismatch).
- [ ] 5.4 Reachable rog smoke `opencode2` PONG/auth/MCP; remote runtime UNVERIFIED, never inferred (S9,S14,S15). PARTIAL: rog existing isolated V2 service returned PONG using existing native auth; all seven MCPs connected, including Engram. Checkout Go-built launcher consumed changed launcher code, but used installed native V2/server/config, not the full candidate generation. The Nix-built `nixos-scripts` package now passes sandbox tests; candidate HM config still differs from installed and no activation was performed. thinkcentre/t14 runtime UNVERIFIED; macm5 DEFERRED.
- [ ] 5.5 Confirm untouched `~/.config/opencode/` (read-only), `~/.local/share/opencode/` (read-only), generations and untracked migration folders (read-only) (S2). PARTIAL: rog root/generation/migration-directory metadata observed without reading archive contents; no historical metadata baseline exists, so byte-level historical preservation is NOT proven. Existing fixture/source non-destructive evidence retained; no activation or GC.

Rog candidate follow-up: system/HM drvPath reevaluation passed. Actual standalone HM candidate BUILD PASSED; full rog system BUILD INCOMPLETE after a foreground 120-second timeout (no final output path/success). Repaired Nix-built candidate helper passed managed `--version` and `run --help`, no second PONG. Structural comparison preserved namespace, provider policies, agent/model identifiers, permissions and MCP identifiers; the only config differences are local MCP PATH profile-directory specialization. Full system activation readiness is BLOCKED by incomplete system build, not the resolved jq defect. Candidate-generation runtime remains pending; macm5 deferred and multi-host task 5.3 still incomplete.

Scenarios: S1 delivery, S2 archives, S3 V2, S4 helpers, S5 unavailable, S6 evidence, S7 enabled, S8 legacy, S9 smoke, S10 seed, S11 interface, S12 MCP, S13 proxy, S14 native-home, S15 gated.

Post-deployment rog subresults (2026-10-06): PASS. Running system exactly matches built candidate zrrz7pnmsrlzcbjfs4kg960wwn2mjca6; integrated HM qsij6vxxz2yhvq09vbrbayn78ax3mp16 activation service succeeded. Managed closures have V2 only, deployed config/environment match integrated candidate, fresh shell has opencode2 and no bare opencode, Nix-built helper matches repaired package. opencode2-home is Darwin-only in source (N/A on rog). Seven MCPs and native Engram access pass. One bounded fresh standalone post-deployment PONG passes, consuming deployed config without restarting retained shared server PID81666. Archive metadata observed, root metadata matches earlier observation; historical content identity not proven. Composite 5.3–5.5 remain partial across hosts: macm5 DEFERRED; thinkcentre/t14 runtime UNVERIFIED. No formal fleet completion/archive.
