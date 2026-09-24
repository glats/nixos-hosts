# Proposal: make-code-work-cleanup-safe-v2

## Intent

`code-work --done` force-removes the worktree (`git worktree remove --force`) and force-deletes its branch (`git branch -D`), gated only by a configured-upstream check that does not guarantee the branch is pushed or in sync, so it can orphan unpushed/unmerged commits. Make `--done` non-destructive (guidance only, zero git mutation) while retaining `--abort` as the single explicit destructive discard path.

## Scope

### In Scope

- `cmdDone` (main.go): verify in-worktree, warn (non-fatal) on uncommitted changes, print concise native-cleanup guidance, exit 0 with no git mutation; remove `hasUpstream`.
- `usageTemplate` `--done` line and `cmdCreate` post-create hints.
- Focused legacy flag tests: `--done` no-op (worktree + branch survive, exit 0), `--abort` still discards.
- `linux/home/shell.nix` `code-work()`: split `--done|--abort` so only `--abort` keeps cd-back-to-main-root.

### Out of Scope

- No new commands, state files, agents, permission grants, profiles, wrappers, policies, or lifecycle automation.
- `--abort` / `--list` / `--prune` / `code-work <task>` behavior unchanged.
- `managed.go`, `internal/managedworktree/`, agent configs, docs, `managed-agent-worktrees` spec — untouched.

## Capabilities

### New Capabilities

None — the legacy surface has no spec; no new capability is introduced.

### Modified Capabilities

None — no existing spec scopes the legacy `--done`/`--abort` surface.

## Approach

Approach 1 from exploration, verbatim: single-function `cmdDone` rewrite mirroring `readMarker`'s native-guidance wording; delete dead `hasUpstream`; split the wrapper case. No auto-cleanup, no managed-lifecycle convergence.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `pkgs/nixos-scripts/cmd/code-work/main.go` | Modified | `cmdDone` → non-destructive guidance; remove `hasUpstream`; update `usageTemplate` + `cmdCreate` hints |
| `pkgs/nixos-scripts/cmd/code-work/main_test.go` | Modified | Dispatch `--done`/`--abort` in helper; assert `--done` no-op and `--abort` discard |
| `linux/home/shell.nix` | Modified | Split `--done`/`--abort` case: `--abort` keeps cd-back; `--done` stays in worktree |

Hosts: Linux (`rog`, `thinkcentre`, `t14`) via `shell.nix`; Go binary packaged under `pkgs/nixos-scripts`. `macm5` unaffected (darwin Home Manager, not `linux/home/shell.nix`).

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| `--done` muscle-memory loss (now manual) | High | Guidance names exact native commands; `--abort` remains discard path |
| Wrapper cd-back misbehavior | Med | Split case; only `--abort` cd-backs |
| `--abort` regression from case split | Low | Test asserts `--abort` still discards |
| Dead `hasUpstream` drift | Low | Remove in same change |
| Test gap (`--done`/`--abort` untested) | Med | New focused tests prove both paths |

## Rollback Plan

`git revert` the single commit restores force-remove/force-delete `--done` and the combined wrapper case. No data migration.

## Dependencies

None. Exploration `sdd/make-code-work-cleanup-safe-v2/explore` confirmed.

## Success Criteria

- [ ] `code-work --done` inside a worktree prints guidance, exits 0, mutates nothing (worktree + branch survive).
- [ ] `code-work --abort` still force-removes the worktree and force-deletes the branch.
- [ ] `hasUpstream` removed; no compile dead code.
- [ ] Wrapper: `--done` no longer cd-backs; `--abort` still cd-backs to main root.
- [ ] `go -C pkgs/nixos-scripts test ./...` passes with new legacy flag tests.
