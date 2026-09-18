# Design: Managed Agent Worktrees

## Technical Approach

Extend the packaged Go `code-work` command with a `managed` namespace. It owns repository-local writing-task worktrees and launches a restrictive named OpenCode agent. Only a human main-checkout operation can integrate or activate; daemon concurrency and OpenCode-native worktree ownership stay unchanged.

## Architecture Decisions

| Decision | Choice | Alternatives considered | Rationale |
|---|---|---|---|
| Identity | ID `[a-z0-9][a-z0-9-]{0,62}` maps to branch `managed/<id>` and `.worktrees/managed/<id>`. | Caller branches; OpenCode names. | Reversible, collision-free repository-local mapping. |
| State and lock | JSON records plus atomic `mkdir` lock under Git common dir. | Tracked state; `flock`; Git lock alone. | Shared by linked worktrees and portable; Git lock only protects pruning. |
| Agent boundary | Named default-deny agent and allowlisted `managed check`. | Prompt-only; broad Bash; sandbox now. | Permissions and dispatcher reduce accidental mutation; containment is deferred. |
| Integration | Human `integrate <id>` holds the lock through merge, validation, and optional activation. | Agent/parallel integration; automatic cleanup. | Serial main-checkout transaction preserves diagnosis. |

No new Nix module option is needed: `home.opencode.agentOverrides` already accepts freeform agents and `runtime-config.nix` emits the resulting agent JSON.

## Data Flow

```
human: managed start <id> ──> code-work ──> git common dir state + lock
                                      ├──> managed/<id> + .worktrees/managed/<id>
                                      └──> opencode --agent managed-writing-task (worktree cwd)
agent: edit / managed check ──> local worktree only ──> ready-for-integration
human main checkout: integrate <id> ──> locked merge ──> validate/build ──> optional activate
```

`start` requires a clean attached main checkout and records ID, branch, path, base branch/commit, state, and timestamps. It reuses only matching active metadata. Transitions are `active → ready-for-integration → integrated` or `active|ready-for-integration → abandoned`; `inspect` reports facts and `recover-lock` is always explicit. Active worktrees receive `git worktree lock`; controlled cleanup unlocks, removes, and prunes.

`managed check` permits only `fmt`, `eval`, `flake-check`, and configured toplevel `build`, resolves the task worktree, and caps builds with `--max-jobs 1 --cores 1`. It rejects rebuild wrappers, activation, Home Manager, input updates, GC, profiles/generations, daemon changes, and arbitrary Nix arguments. The agent additionally denies direct mutation families, `sudo`, services, cleanup/integrate, pushes, and external directories, while allowing local edits, branch Git status/diff/commit, tests, and checks. This is not OS containment.

`integrate` rejects non-main cwd, dirty/wrong base, non-ready state, or branch mismatch. It non-fast-forward merges, runs non-activating validation/build, and activates only with the human's explicit mode. Failure aborts the merge where possible, retains evidence, and releases the lock. Success records `integrated`; human `cleanup` is separate. Nothing auto-pushes, cleans up, or activates.

## File Changes

| File | Action | Description |
|---|---|---|
| `pkgs/nixos-scripts/cmd/code-work/main.go`, `main_test.go` | Modify/Create | Managed CLI, launch, and command contracts. |
| `pkgs/nixos-scripts/internal/managedworktree/{managedworktree,managedworktree_test}.go` | Create | State, portable lock, metadata, Git lifecycle tests. |
| `shared/opencode/{agents.nix,local-agent-overlays.json}` | Modify | Generated named agent and default-deny policy. |
| `linux/home/shell.nix` | Modify | Preserve all managed arguments. |

## Interfaces / Contracts

```
code-work managed start <task-id> [--base <branch>]
code-work managed ready <task-id>
code-work managed check <task-id> <fmt|eval|flake-check|build> [target]
code-work managed integrate <task-id> --validate <check|build> [--activate <system|home>]
code-work managed inspect [<task-id>] | cleanup <task-id> | abandon <task-id> | recover-lock
```

The installed OpenCode command/agent selector is verified against the packaged version before implementation; no OpenCode-native worktree creation is called.

## Testing Strategy

| Layer | What to Test | Approach |
|---|---|---|
| Unit | IDs, metadata, transitions, locks, allowed arguments | Go table tests with fakes. |
| Integration | Git lifecycle, dirty/mismatch, failed merge/build recovery | Temp Git repos; fake Nix/OpenCode. |
| Nix eval | Named agent JSON on Linux and Darwin | Targeted host evaluation. |

## Threat Matrix

| Boundary | Applicability | Design response | Planned RED tests |
|---|---|---|---|
| Documentation-like paths | N/A: no executable-file classification. | N/A | N/A |
| Git repository selection | Applicable: linked worktree cwd. | Safe: common dir and main root agree; failure: reject relative, absolute, or `git -C` authority mismatch. | Fixtures for each selector. |
| Commit state | Applicable: agent commits and gate merges. | Safe: only clean committed task is ready; failure: staged, `commit -a`, or empty-index cases cannot transition/merge. | Fixture for each state. |
| Push state | N/A: no managed push surface. | Deny push. | N/A |
| PR commands | N/A: no managed PR surface. | None. | N/A |

## Migration / Rollout

No migration is required. Existing `code-work` lifecycle remains untouched. Rebuild the package and OpenCode Home Manager config, then opt into `managed start`. Rollback reverts the change and retains records/branches for explicit abandonment or recovery.

## Open Questions

None.
