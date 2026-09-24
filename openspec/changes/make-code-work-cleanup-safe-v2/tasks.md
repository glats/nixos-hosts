# Tasks: Make `code-work --done` Non-Destructive (V2)

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~120–180 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single direct-master patch |
| Delivery strategy | single-pr (direct to master, commit/push only after all checks pass) |
| Chain strategy | stacked-to-main |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: stacked-to-main
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Non-destructive `--done` + preserved `--abort` in Go | direct commit to master | `go -C pkgs/nixos-scripts test ./cmd/code-work` | Legacy worktree subprocess helper (real git repo) | Revert the single commit; restores force-remove `--done` and combined wrapper case |
| 2 | Wrapper case split in `linux/home/shell.nix` | same commit (tiny, coupled) | `nix eval .#homeConfigurations.rog.activationPackage.drvPath` | Manual: `code-work --done` stays in worktree; `--abort` cd-backs | Revert restores combined `--done\|--abort` case |

## Phase 1: RED Tests for Legacy Flags (`pkgs/nixos-scripts/cmd/code-work/main_test.go`)

- [x] 1.1 Extend `TestCodeWorkCommandHelperProcess` dispatch to route `--done`, `--abort`, and `--list` real flags (create path optional).
- [x] 1.2 RED: `--done` case in helper — legacy-created worktree with unpushed commits (no upstream); assert exit 0, no force-remove (`worktree dir survives`), branch ref survives, HEAD unchanged. Current code fails this (it removes/deletes) — proves the boundary.
- [x] 1.3 RED: `/path` (read-only) — worktree survival assertions compare against `git rev-parse HEAD` and `git rev-parse refs/heads/<branch>` (read-only), captured before and after `--done`.

## Phase 2: Non-Destructive `--done` (`pkgs/nixos-scripts/cmd/code-work/main.go`)

- [x] 2.1 Rewrite `cmdDone` (currently ~main.go:324-388): validate in-`.worktrees/` location + read `.worktree-base` marker (reuse existing helpers), then warn non-fatally on uncommitted changes; never git-mutate.
- [x] 2.2 `cmdDone` prints native guidance mirroring `readMarker` wording: integrate first (merge or open+merge PR), then `git worktree remove <path>`, then `git branch -d <branch>`; mention `--abort` for discard, `--list`/`--prune` for status; exit 0.
- [x] 2.3 Delete `hasUpstream` (main.go:146-148) — dead after rewrite; `go build` must show no unused symbols.
- [x] 2.4 Update `usageTemplate` `--done` line and `cmdCreate` post-create hints: `--done` = finish & show cleanup guidance; `--abort` = discard (destructive).
- [x] 2.5 GREEN: Phase 1.2 assertions pass after rewrite.
- [x] 2.6 RED→GREEN: `--abort` test in separate legacy worktree — force-removes directory, force-deletes branch (both gone after exit 0); must pass unchanged vs current behavior.

## Phase 3: Wrapper Case Split (`linux/home/shell.nix`)

- [x] 3.1 Split the `--done|--abort)` case (~shell.nix:71-76): only `--abort` captures main root and cd-backs; `--done` falls through to direct command invocation, shell stays in worktree.

## Phase 4: Verification & Delivery

- [x] 4.1 `go -C pkgs/nixos-scripts test ./...` — all packages pass.
- [x] 4.2 `nix fmt -- linux/home/shell.nix`.
- [ ] 4.3 Eval: `nix eval .#homeConfigurations.rog.activationPackage.drvPath` and `.#t14` (Linux shared `shell.nix` consumers); `nix eval .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath` for one host.
- [ ] 4.4 `nix flake check --no-build`.
- [x] 4.5 Commit to master (single commit) and push under the user's explicit direct-master authorization despite the unrelated 4.3–4.4 blockers.
