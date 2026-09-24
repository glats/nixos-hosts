# Design: Make `code-work` Cleanup Safe V2

## Technical Approach

Replace the legacy `cmdDone` cleanup transaction with an informational completion path. It retains the existing repository/worktree-marker validation, reports dirty content without failing, and prints native Git guidance: integrate first, then run `git worktree remove <path>` and `git branch -d <branch>`. It exits successfully without changing the current directory or invoking mutating Git commands. `cmdAbort` remains the sole explicit destructive path.

No Nix module option interface changes or option migration are involved.

## Architecture Decisions

| Decision | Alternatives considered | Rationale |
|---|---|---|
| Make `--done` guidance-only | Tighten upstream/ahead checks then auto-clean; converge with managed lifecycle | Any automatic cleanup still couples completion to deletion. Guidance preserves user control and the requested legacy scope. |
| Use native safe commands in guidance | Add a new cleanup command or wrapper automation | `git worktree remove` and merge-aware `git branch -d` are Git's native safe operations; no new interface is needed. |
| Preserve `--abort` unchanged | Make all cleanup non-destructive | Explicit abort is the documented discard escape hatch; changing it exceeds the correction. |
| Split shell handling | Keep combined `--done|--abort` cd-back branch | `--done` retains the worktree, so cd-back would unexpectedly move the user's shell. Abort still deletes the current directory and needs it. |

## Data Flow

```text
worktree shell ── code-work --done ──> validate worktree + marker
                                      ├─ dirty? warn, continue
                                      └─ print integrate → native remove → safe branch delete
                                              (no Git mutation; remain in worktree)

worktree shell ── code-work --abort ─> existing force remove/delete/prune ─> wrapper cd main root
```

## File Changes

| File | Action | Description |
|---|---|---|
| `pkgs/nixos-scripts/cmd/code-work/main.go` | Modify | Rewrite `cmdDone` as zero-mutation guidance; remove `hasUpstream`; update legacy help and create hints. Keep `cmdAbort`, list, prune, create, and managed lifecycle untouched. |
| `pkgs/nixos-scripts/cmd/code-work/main_test.go` | Modify | Extend the helper's real dispatch for legacy flags and add isolated lifecycle assertions. |
| `linux/home/shell.nix` | Modify | Separate `--done` from `--abort`; only abort captures the main root and cd-backs. |

## Interfaces / Contracts

No new interfaces, types, commands, state, or Nix options. Existing contracts change only as follows:

- `code-work --done` succeeds from a marked legacy worktree even if dirty or without an upstream, prints integration and native cleanup instructions, and performs no Git mutation.
- `code-work --abort` retains its existing force-remove, force-delete, prune, and wrapper cd-back behavior.

## Testing Strategy

| Layer | What to Test | Approach |
|---|---|---|
| Unit/process | `--done` safe completion | Use the existing helper subprocess with a legacy-created worktree; include unpushed committed work and optionally dirty content; assert exit 0, guidance, unchanged worktree directory, branch ref, and HEAD. |
| Unit/process | `--abort` preservation | Invoke abort in a separate legacy worktree; assert its directory and branch no longer exist. |
| Configuration | Wrapper case split | Review/evaluate the rendered Nix function: `--done` directly delegates and `--abort` alone retains root capture/cd-back. |
| Regression | Go command package | Run `go -C pkgs/nixos-scripts test ./...`. Format the touched Nix file and run the applicable Linux Home Manager evaluation if available. |

## Threat Matrix

| Boundary | Applicability | Design response | Planned RED tests |
|---|---|---|---|
| Documentation-like paths | N/A — no executable classification changes | None | None |
| Git repository selection | Applicable — commands derive main root and linked worktree from cwd | Keep existing in-worktree and marker validation; done does not chdir | Run `--done` from a linked legacy worktree and assert it survives. |
| Commit state | Applicable — dirty state moves from denial to warning | Warn but succeed; never delete dirty or committed content | Dirty legacy worktree exits 0 and remains intact. |
| Push state | Applicable — upstream gate is removed | Unpushed/no-upstream branches receive guidance, never deletion | Committed branch without upstream exits 0 and remains intact. |
| PR commands | N/A — no PR command composition or execution | Guidance mentions integration without invoking a PR tool | None |

## Migration / Rollout

No migration required. The behavioral change is immediate; updated help and post-create hints explain the manual native cleanup sequence. Revert the focused change to restore prior behavior if required.

## Open Questions

None.
