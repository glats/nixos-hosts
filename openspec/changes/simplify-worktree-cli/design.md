# Design: Simplify Worktree CLI

## Technical Approach

Expose the managed lifecycle as canonical top-level `code-work` verbs while retaining a hidden, one-release `managed` compatibility adapter. Canonical worktree operations resolve the task solely from the exact recorded workspace path; main-checkout operations retain their current selector, cleanliness, state, lock, merge, validation, rollback, and activation gates.

## Architecture Decisions

| Decision | Choice | Alternative | Rationale |
|---|---|---|---|
| CLI surface | Top-level verbs plus hidden adapter. | Immediate removal. | Compatibility without a permanent second API. |
| Cwd identity | `Clean(record.Path) == Clean(cwd)`. | `.worktrees/managed` prefix. | Records cannot classify legacy `managed*` worktrees. |
| Admission | Main: `new`, `merge`, `clean`; worktree: `check`, `ready`, `status`. | Subdirectory/main inference. | Preserves explicit safety gates. |
| Compatibility | Old grammar, one stderr hint, same guarded handler, no help entry. | Document both. | One-release rollback window. |

No Nix module option changes are needed; existing `home.opencode.agentOverrides` and generated runtime configuration remain the interface.

## Data Flow

```
main: new/merge/clean ──> selector + clean gate ──> lifecycle lock ──> record/worktree
worktree: check/ready/status ──> ResolveTaskID(stateDir, cwd) ──> matching record ──> guarded action
managed legacy form ──> stderr hint + argument adapter ──> same canonical handler
```

`ResolveTaskID` reads valid common-dir records and returns only an exact path match. No match is `not inside a managed worktree`; malformed relevant state fails, never guesses. Subdirectories remain unsupported. `check` retains its four allowlisted forms, option denial, and capped builds; `ready` retains clean/metadata checks; `status` is lock-free and read-only. Old all-record `inspect` is adapter-only.

## Interfaces / Contracts

| Canonical command | Admission and behavior | Legacy adapter mapping |
|---|---|---|
| `new <id> [--base <branch>]` | Clean attached main; existing create/lock/launch behavior. | `managed start ...` |
| `check <check> [target]` | Exact worktree cwd; infer ID. | `managed check <id> ...` retains named-record execution. |
| `ready` | Exact assigned worktree cwd; infer ID. | `managed ready <id>` |
| `status` | Exact managed-worktree cwd; infer ID, read-only. | `managed inspect [id]` retains its former record/list output. |
| `merge <id> --validate <check\|build> [--activate <system\|home>]` | Clean attached main; non-FF, rollback, explicit activation. | `managed integrate ...` |
| `clean <id>` | Integrated-or-abandoned only. | `managed cleanup ...` |
| `abandon <id>`, `recover-lock` | Unchanged. | Same legacy verb. |

The adapter writes one stderr hint such as `code-work managed is deprecated; use code-work <canonical form>`, is absent from `--help`, preserves exit codes, and is deleted in the next release. Existing legacy lifecycle commands and the archived source contract are untouched.

## File Changes

| File | Action | Description |
|---|---|---|
| `pkgs/nixos-scripts/cmd/code-work/{main,managed,main_test}.go` | Modify | Dispatch, help, adapters, and fixture tests. |
| `pkgs/nixos-scripts/internal/managedworktree/{managedworktree,managedworktree_test}.go` | Modify | Resolver and tests. |
| `shared/opencode/local-agent-overlays.json` | Modify | Canonical and temporary check permissions. |
| `shared/opencode/agents.nix` | Modify | Canonical prompt. |
| `linux/home/shell.nix` | Modify | Direct verb routing. |
| `docs/managed-agent-worktrees.md` | Modify | Contract and migration note. |

## Testing Strategy

| Layer | What to test | Approach |
|---|---|---|
| Unit | Resolver, records, IDs, transitions, locks, parser. | Go table tests. |
| Command | Admission, legacy non-match, denial-before-exec, retention, shim output. | Temp Git repo; fake `nix`/`opencode`. |
| Declarative | Both permissions, prompt, wrapper, Linux/Darwin agent output. | Generated config and targeted evals. |

## Threat Matrix

| Boundary | Applicability | Design response | Planned RED tests |
|---|---|---|---|
| Documentation-like paths | N/A: no executable classification. | N/A | N/A |
| Git repository selection | Applicable: cwd selects record/main gate. | Exact path; reject main, legacy, relative/absolute and `git -C` mismatch. | One fixture per selector. |
| Commit state | Applicable: ready and merge. | Preserve clean requirements and rollback. | Staged, `commit -a`, empty index. |
| Push state | N/A: no push surface. | Push remains denied. | N/A |
| PR commands | N/A: no PR surface. | N/A | N/A |

## Migration / Rollout

Ship dispatch, wrapper, prompt, both allowlist entries, and docs atomically. Rebuild and evaluate Linux/Darwin. Next release removes the shim parser, old permission, and migration note together. Rollback leaves records, branches, locks, and worktrees intact.

## Open Questions

None.
