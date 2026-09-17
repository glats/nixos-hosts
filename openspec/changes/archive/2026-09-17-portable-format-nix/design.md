# Design: Portable Format Nix

## Technical Approach

`format-nix` will resolve its target before calling `os.Chdir`. One positional directory is authoritative; without it, the command walks from the process working directory to its filesystem parent until it finds `flake.nix`. The resolved directory must be a directory containing `flake.nix`; otherwise it exits before traversal or formatter subprocesses run. The existing recursive `.nix` walk, `.git`/`.worktrees` exclusions, temporary check copies, and per-file `nix fmt --` invocation remain unchanged.

## Architecture Decisions

| Decision | Choice | Alternatives considered | Rationale |
|---|---|---|---|
| Target authority | Positional directory wins; otherwise discover upward from cwd. | Fixed `/etc/nixos`; environment or Git root. | Matches the confirmed interface and supports independent Nix/Darwin projects without ambient configuration. |
| Project boundary | Require `flake.nix` in the explicit target or discovered ancestor. | Format arbitrary directories; nearest Git root. | Prevents accidental formatting outside a selected flake and keeps non-flake support out of scope. |
| Resolution placement | Keep parsing and resolution in `cmd/format-nix` as small testable helpers. | Reuse `internal/reporoot`; add a shared package. | `reporoot` intentionally resolves this repository through env/Git/home fallbacks, which conflicts with caller-flake semantics. |
| Formatter execution | Retain `exec.Command("nix", "fmt", "--", file)` after chdir. | Direct `nixfmt-tree`; bulk formatter call. | Preserves existing formatter selection, output, and per-file failure/check behavior. |

## Data Flow

```text
argv + cwd
    │
    ├─ explicit directory ──→ validate directory + flake.nix
    └─ no directory ────────→ cwd → parent ... → directory with flake.nix
                                           │
                                 chdir(selected root)
                                           │
                           nixFiles(".") → nix fmt -- <relative file>
```

An explicit directory is used even when cwd belongs to another flake. Discovery stops at the filesystem root. A missing/unusable target or no containing flake reports a clear error and exits 1; malformed arguments remain exit 2. Formatter failures retain the current aggregate nonzero result.

## File Changes

| File | Action | Description |
|---|---|---|
| `pkgs/nixos-scripts/cmd/format-nix/main.go` | Modify | Replace the fixed target with argument parsing, flake-root resolution, validation, and portable help text. |
| `pkgs/nixos-scripts/cmd/format-nix/main_test.go` | Modify | Add isolated temporary-tree tests for argument and target resolution while retaining traversal/check-copy coverage. |

No Nix module option is added or changed; the already-installed `nixos-scripts` binary is deployed unchanged on all hosts.

## Interfaces / Contracts

```text
format-nix [directory] [--check]
```

`--check` may accompany the optional positional target and preserves current reporting and exit semantics. Zero or one directory is accepted; unknown flags or additional positional arguments are rejected. The command does not read `NIXOS_REPO`, `NIX_PATH`, or other environment variables to select a target.

## Testing Strategy

| Layer | What to Test | Approach |
|---|---|---|
| Unit | Explicit target wins over a different cwd flake; valid explicit target; missing/non-flake explicit target. | Temporary directories with controlled `flake.nix` markers. |
| Unit | Nested cwd discovers nearest ancestor flake; no ancestor fails at root. | Inject/temporarily change cwd with cleanup; assert root or error before formatting. |
| Unit | `--check`, help, unknown arguments, and duplicate positional arguments. | Parse helper table tests; preserve existing exit contract. |
| Unit | Existing `.nix` traversal exclusions and repository-local check copies. | Retain current tests. |
| Build | Binary and all Go tests. | `go -C pkgs/nixos-scripts test ./...` and `nix build .#nixos-scripts`. |

## Threat Matrix

| Boundary | Applicability | Design response | Planned RED tests |
|---|---|---|---|
| Documentation-like paths | N/A — selection is by directory/`flake.nix`, not executable or documentation classification. | No classifier added. | None. |
| Git repository selection | N/A — no Git command or Git-root selection occurs. | Cwd ancestor walk is limited to `flake.nix`. | None. |
| Commit state | N/A — the command does not inspect or mutate Git state. | No Git integration. | None. |
| Push state | N/A — the command does not push. | No remote interaction. | None. |
| PR commands | N/A — the command does not compose PR commands. | No PR integration. | None. |

The applicable subprocess boundary is the existing `nix fmt -- <relative file>` execution: selected-root chdir confines relative discovery and temp copies; an unavailable or failing formatter sets the existing error result without selecting a fallback target. RED coverage proves resolution errors occur before any formatter execution.

## Migration / Rollout

No migration required. Rebuild `nixos-scripts`; rollback is a revert to the fixed-root command and rebuild. Existing no-argument invocations now require a containing flake rather than `/etc/nixos`.

## Open Questions

None.
