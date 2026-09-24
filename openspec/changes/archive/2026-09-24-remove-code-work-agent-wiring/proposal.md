# Proposal: Remove Code-Work Agent Wiring

## Intent

Decouple the OpenCode `managed-writing-task` agent from the `code-work` CLI by removing its three `code-work` touch points, with no replacement permission, profile, command, or behavior. Capability result: the managed agent loses its repository-provided Nix check path (keeps edit, branch-local Git, tests; loses fmt/eval/flake-check/build).

## Scope

### In Scope
- Remove the `code-work check` prompt instruction in `shared/opencode/agents.nix`.
- Remove both `code-work` Bash allowlist entries in `shared/opencode/local-agent-overlays.json`; drop trailing comma.
- Remove the three `wt-*` aliases in `linux/home/shell.nix`.
- Reconcile contradicted check requirements in `managed-agent-worktrees` and `gentle-ai-declarative-runtime` specs via deltas.

### Out of Scope
- No replacement permission, profile, command, docs, Go/Nix packaging, or behavior.
- `code-work` binary, wrapper, worktrees, locks, Go code, docs, `permissions.nix` preserved.
- No re-grant of the check capability.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `managed-agent-worktrees`: "Managed Agent Capability Boundary" — drop `fmt`/`eval`/`flake-check`/`build` checks and the "via `code-work check`" binding. Boundary becomes edit + branch-local Git + tests.
- `gentle-ai-declarative-runtime`: "Managed Writing-Agent Profile" — drop "allowlisted local checks".

## Approach

Minimal three-file decoupling (exploration Approach 1): delete the prompt sentence, two JSON entries, and three aliases. Profile, `defaultAgents` injection, and `code-work new` launch stay untouched. Spec reconciliation runs in spec phase, never silently.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `shared/opencode/agents.nix` | Modified | Drop `code-work check` sentence from prompt. |
| `shared/opencode/local-agent-overlays.json` | Modified | Remove two `code-work` Bash entries; drop trailing comma. |
| `linux/home/shell.nix` | Modified | Remove `wt-done`/`wt-abort`/`wt-list`. |
| `openspec/changes/remove-code-work-agent-wiring/specs/*/spec.md` | Added (spec phase) | Reconciliation deltas. |

Hosts: `shared/opencode/*` = all four; `linux/home/shell.nix` = rog, thinkcentre, t14.

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Agent check regression (intended) | High | Recorded; reflected in delta. |
| JSON trailing comma | Med | Drop comma; flake check proves parse. |
| Spec contradiction unresolved | Med | Modified Capabilities drive deltas. |
| Ordering vs un-archived `simplify-worktree-cli` | Med | This delta is authoritative; archive after it. |
| Docs drift (four checks still listed) | Low | Out of scope; noted for follow-up. |

## Rollback Plan

Revert the single commit. Removals are explicit string/entry deletions; restoring them re-attaches `code-work check`. No lock, worktree, Go, or packaging state touched.

## Dependencies

None external. Requires `simplify-worktree-cli` delta to stay un-archived until this reconciliation archives.

## Success Criteria

- [ ] `code-work` absent from both `shared/opencode` files; `wt-*` absent from `shell.nix`; wrapper stays.
- [ ] Profile persists with git/go-test entries but no `code-work` key.
- [ ] `nix fmt` + `nix flake check --no-build` pass; JSON parses.
- [ ] Deltas reconcile both contradicted check requirements (no silent `code-work check`).
