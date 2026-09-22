# Design: Add OpenCode Harness Initializer

## Technical Approach

Keep `cmd/opencode-harness-init` as a thin adapter over `internal/projectinit`. The command owns flags, output, exit status, and the concrete `openspec` subprocess. The internal package owns validation, state classification, filesystem mutation, Git-marker discovery, sequencing, and results. `shared/shell-aliases.nix` provides `ohi`. It uses the Go standard library and receives OpenSpec execution as a callback for command-free unit tests.

## Architecture Decisions

| Decision | Choice | Alternatives considered | Rationale |
|---|---|---|---|
| Command ownership | Parse flags and optional directory in `cmd/opencode-harness-init/main.go`; delegate policy to `projectinit.Init`; define `ohi` in shared aliases | Put initialization in `main`; add a CLI framework | Matches thin-entry-point practice and avoids dependencies. |
| Engram write safety | Classify first, create `.engram`, write JSON plus newline to a same-directory temporary file, set `0644`, close, then rename over `config.json` | Direct overwrite; backup/transaction framework | Rename prevents a partial config from replacing prior bytes. Temporary files are removed on failure. `--force` permits replacement; otherwise conflicts stop before mutation. |
| Git detection | Resolve the target to an absolute path and walk parents for a `.git` directory or file | Invoke `git rev-parse`; parse worktree metadata | Handles repos, worktrees, subdirectories, and non-Git directories without `git`. Detection never gates initialization. |
| OpenSpec boundary | Inject `func(string) error`; production runs `openspec init --tools opencode --force` with `Cmd.Dir` set to the target | Shell command string; internal package calling `os/exec`; OpenSpec library dependency | Fixed argv avoids shell interpretation, callback injection isolates process tests, and the Nix wrapper supplies the executable on `PATH`. Run only when `openspec/config.yaml` is absent and not disabled. |
| Mutation order | Validate and classify, run OpenSpec when needed, then write Engram config | Write Engram first; attempt rollback | OpenSpec failure leaves Engram unchanged. Upstream may leave partial output; the error is surfaced without destructive cleanup. |

## Data Flow

```text
argv -> cmd parser -> projectinit.Init -> absolute directory/name validation
                              |-> classify Engram config
                              |-> classify OpenSpec + walk parents for .git
                              |-> OpenSpec callback (unless current/skipped/dry-run)
                              `-> atomic Engram config replacement (unless current/dry-run)
result/error <- terminal rendering <- command
```

## File Changes

| File | Action | Description |
|---|---|---|
| `pkgs/nixos-scripts/cmd/opencode-harness-init/main.go` | Create | Thin CLI and concrete OpenSpec process adapter. |
| `pkgs/nixos-scripts/internal/projectinit/projectinit.go` | Create | Initialization policy, safe write, state classification, and Git discovery. |
| `pkgs/nixos-scripts/internal/projectinit/projectinit_test.go` | Create | Filesystem and process-boundary behavior tests. |
| `pkgs/nixos-scripts/default.nix` | Modify | Build the command and wrap only it with Nixpkgs `openspec` on `PATH`. |
| `shared/shell-aliases.nix` | Modify | Map `ohi` to the long command on every host. |

No Nix module options are introduced; the project design rule for an options interface is not applicable.

## Interfaces / Contracts

`Init(path string, Options) (Result, error)` is the internal boundary. `Options.OpenSpec` receives the absolute target directory. `Result` reports absolute `Path`, informational `Git`, and Engram/OpenSpec states: `created`, `current`, `conflict`, or `skipped` where applicable.

Errors wrap the failed operation (`resolve`, `read`, `parse`, `create`, `write`, `replace`, or `initialize OpenSpec`). Invalid paths/names and unforced conflicts fail before mutation. The CLI prints `error: <message>` to stderr and exits 1; usage errors use the same contract.

## Testing Strategy

| Layer | What to Test | Approach |
|---|---|---|
| Unit | Name/path validation; created/current/conflict/forced states; malformed/unreadable config; dry-run and no-openspec; OpenSpec callback success/failure; Git directory/file/ancestor/absent detection; relative and absolute targets | Table-driven tests with `t.TempDir()` and injected callbacks; assert results, errors, bytes, mode, and absence of side effects. |
| Command | Flag/usage parsing and status/errors | Helper-process tests only where internal tests cannot prove behavior. |
| Integration | Real wrapped OpenSpec availability and package wiring | `go -C pkgs/nixos-scripts test ./...`, then `nix flake check --no-build`; derivation checkPhase reruns Go tests. |

## Threat Matrix

| Boundary | Applicability | Safe/failure behavior | Planned RED tests |
|---|---|---|---|
| Documentation-like paths | N/A: no file-type classification or arbitrary execution | Only the fixed `openspec` executable is invoked | None |
| Git repository selection | Applicable | Target becomes absolute; parent markers are inspected without commands; invalid targets fail before detection | Relative target, absolute target, parent `.git` directory, worktree `.git` file, and no marker |
| Commit state | N/A: index/worktree state is neither read nor changed | No Git mutation | None |
| Push state | N/A: no remote or ref handling | No push | None |
| PR commands | N/A: no PR automation | No PR command | None |

The OpenSpec subprocess uses fixed arguments without a shell. Its non-zero exit is wrapped and stops the later Engram write; an injected failing callback is the RED test boundary.

## Migration / Rollout

No migration required. Rollback removes the command/package files and Nix registration; created project files remain user-owned. No feature flag or phased rollout is needed.

## Open Questions

None.
