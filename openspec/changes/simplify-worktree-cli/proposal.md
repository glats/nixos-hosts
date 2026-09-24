# Proposal: Simplify Worktree CLI

## Intent

The shipped `managed-agent-worktrees` CLI forces repeating the task ID and a verbose verb on every call (`code-work managed start <id>`, `managed check <id> <check> [target]`, …). Replace it with a lean top-level surface where cwd carries task context inside the worktree and main-checkout operations address a task by ID, while preserving every lock, policy, and host-mutation gate.

## Scope

### In Scope
- Top-level verbs: `code-work new <task>`, cwd-inferred `check`, `ready`, `status`, and main-checkout `merge <task>`, `clean <task>`.
- Rename `start→new`, `integrate→merge`, `cleanup→clean`, `inspect→status`; keep `abandon`/`recover-lock`.
- cwd→task-id resolution by record-path match (never string prefix).
- Hidden, temporary `managed` forwarding shim (stderr hint, absent from `--help`), removed next release.
- Mandatory same-commit wiring: OpenCode Bash allowlist, agent prompt, shell wrapper.

### Out of Scope
- Subdirectory cwd inference (exact `record.Path == cwd` only).
- Removing the `managed` shim (deferred to a follow-up).
- Any change to the legacy `code-work <name> --done/--abort/--list/--prune` surface.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
None — requirements are capability-level and verb-agnostic; the `managed-agent-worktrees` spec contract is unchanged. Spec phase verifies scenario wording still maps to the new verbs.

## Approach

Clean rename (exploration Approach 2) with a short hidden `managed` forwarding shim bolted on (Approach 1's shim). The essential win is cwd inference, orthogonal to naming; the feature shipped days ago with a single internal consumer, so the compatibility surface is trivially small. `managedCommand` already centralizes dispatch, making the shim nearly free. cwd resolution iterates `.git/managed-worktrees/*.json` records and returns the id whose `record.Path == cwd`. Preserve lifecycle lock, `git worktree lock`, allowlist, state machine, and the human integration/activation gate exactly.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `pkgs/nixos-scripts/cmd/code-work/main.go` | Modified | Dispatch new verbs, `usageTemplate` |
| `pkgs/nixos-scripts/cmd/code-work/managed.go` | Modified | Verb rename, cwd inference, `ResolveTaskID` |
| `pkgs/nixos-scripts/internal/managedworktree/managedworktree.go` | Modified | Add `ResolveTaskID(root, cwd)` |
| `pkgs/nixos-scripts/cmd/code-work/main_test.go` | Modified | Rewrite invocations; add cwd/shim tests |
| `shared/opencode/local-agent-overlays.json` | Modified | Allowlist `"code-work check *"` |
| `shared/opencode/agents.nix` | Modified | Prompt references `code-work check` |
| `linux/home/shell.nix` | Modified | Whitelist new verbs past legacy `*)` branch |
| `docs/managed-agent-worktrees.md` | Modified | Reflect new verbs |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Shell wrapper `*)` branch creates legacy worktree named `new` | High | Update wrapper in same commit; add Nix-side route test |
| Agent allowlist denies renamed `check` | Med | Update pattern same commit; keep `managed` form during shim |
| Legacy worktree named `managed`/`managed-*` misresolves | Med | Record-path match, not prefix; cwd test covers it |
| Doc/help drift vs archived artifacts | Low | `usageTemplate` + docs updated; archive stays as audit trail |

## Rollback Plan

Revert the single change commit. The hidden `managed` shim keeps old invocations working for one release, so a revert before shim removal is non-breaking. Lock/state files are untouched.

## Dependencies

None external.

## Success Criteria

- [ ] `code-work new <task>`, `check`, `ready`, `status`, `merge <task>`, `clean <task>` work as specified across Linux and Darwin.
- [ ] `check`/`ready`/`status` error "not inside a managed worktree" from main or legacy worktree (no silent no-op).
- [ ] All lock, allowlist, state-machine, and integration-gate tests pass unchanged.
- [ ] Agent allowlist + prompt + shell wrapper updated in the same commit.
- [ ] `go -C pkgs/nixos-scripts test ./...` and `nix flake check --no-build` pass.
