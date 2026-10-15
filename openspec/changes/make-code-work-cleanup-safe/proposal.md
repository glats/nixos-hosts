# Proposal: Make `code-work` Cleanup Safe

## Intent

`code-work --done` force-removes the worktree (`git worktree remove --force`) and force-deletes the branch (`git branch -D`) after only checking that an upstream is *configured* — not in sync — so unpushed commits get orphaned. Replace `--done` with a non-destructive deprecation/safety guidance command, per exploration `evaluate-code-work-community-flow` (Approach 2).

Host scope: Linux hosts `rog`, `thinkcentre`, `t14` (shell wrapper). The Go binary change is host-agnostic; `macm5` (darwin) has no legacy wrapper and is unaffected.

## Scope

### In Scope
- Rewrite `cmdDone`: print integration + native cleanup guidance; never remove a worktree or delete a branch.
- Preserve `--abort` (destructive abandon), `--list`, `--prune` unchanged.
- Keep `code-work <task>` create + `opencode` launch flow intact.
- Update usage text, `cmdCreate` hints, and the `linux/home/shell.nix` wrapper.

### Out of Scope
- New lifecycle/state/agent policy or cleanup wrapper; managed `new/check/ready/status/merge/clean/abandon/recover-lock`.
- Auto-cleanup, ahead/behind gating, or converging `--done` onto the managed lifecycle.

## Capabilities

### New Capabilities
- `code-work-legacy-cleanup`: corrected non-destructive `--done` guidance; preserved `--abort`/`--list`/`--prune`.

### Modified Capabilities
None — `managed-agent-worktrees` is untouched; the legacy surface is out of that spec.

## Approach

Rewrite `cmdDone` to: verify inside a worktree, warn (non-fatal) on uncommitted changes, print guidance (deprecation note; integrate first via merge/PR; then `git worktree remove <path>` and `git branch -d <branch>`; `--abort` for discard; `--list`/`--prune` for status), and exit 0 with no git mutation. Remove now-unused `hasUpstream`. Split the `--done|--abort` wrapper case so only `--abort` keeps the cd-back dance; update both post-opencode hints. Add `--done` dispatch to the test helper and assert the worktree and branch survive `--done`.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `pkgs/nixos-scripts/cmd/code-work/main.go` | Modified | `cmdDone` → guidance; drop `hasUpstream`; usage + create hints |
| `linux/home/shell.nix` | Modified | Split `--done`/`--abort` case; update post-opencode hints |
| `pkgs/nixos-scripts/cmd/code-work/main_test.go` | Modified | Helper dispatch for `--done`; non-destructive assertion |

Docs: no standalone file documents legacy `--done`; the inline usage text is the doc surface. `docs/managed-agent-worktrees.md` needs no change.

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Users relying on `--done` auto-cleanup | Med | Guidance prints exact native commands; `--abort` still discards |
| Dead code / drift | Low | Remove `hasUpstream`; tests assert no mutation |
| Wrapper cd-back only for `--abort` | Low | Test `--abort` still returns to main root |

## Rollback Plan

Revert the single commit. `--done` restoring force-delete is trivially recoverable from git history; no state files are written.

## Dependencies

None.

## Success Criteria

- [ ] `--done` exits 0, prints guidance, leaves worktree and branch intact (no `--force` remove, no `-D`).
- [ ] `--abort` still force-removes and force-deletes; `--list`/`--prune` unchanged.
- [ ] `code-work <task>` create + `opencode` launch unchanged.
- [ ] `go -C pkgs/nixos-scripts test ./...` and `nix flake check --no-build` pass.
