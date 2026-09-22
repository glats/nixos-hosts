# Proposal: Add OpenCode Harness Initializer

## Intent

Formalize the `opencode-harness-init` Go binary as a tracked change so its behavior is spec'd, verified, and archived instead of silently treated as complete. It bootstraps a directory into an Engram/OpenSpec project, replacing manual setup. `ohi` is its portable shell alias.

## Scope

### In Scope

- `opencode-harness-init` Go CLI in `pkgs/nixos-scripts`, with the `ohi` shell alias: `--name`, `--dry-run`, `--force`, `--no-openspec`, optional `DIRECTORY`.
- `internal/projectinit` logic: Engram config write/read, conflict detection, Git/worktree/non-Git detection, OpenSpec trigger.
- Wire into `pkgs/nixos-scripts/default.nix` (subPackage + `wrapProgram` exposing Nixpkgs `openspec`).

### Out of Scope

- Changes to Engram or OpenSpec upstream tooling.
- Retrofitting existing repositories.
- A Home Manager/NixOS module wrapper; the binary stays a thin CLI.

## Capabilities

### New Capabilities

- `project-initialization`: Initialize a directory as an Engram/OpenSpec project safely and idempotently across Git repos, Git worktrees, and non-Git directories.

### Modified Capabilities

None.

## Approach

`opencode-harness-init` defaults to the current directory (or explicit `DIRECTORY`), derives the Engram project name from `--name` or the directory basename, and writes `.engram/config.json` with `project_name`. Git detection walks up for a `.git` directory or file (worktree marker). `openspec init --tools opencode --force` runs only when `openspec/config.yaml` is absent. A matching existing name reports `current`; a differing name reports `conflict` and errors unless `--force`. `--dry-run` previews without writing. The derivation wraps the Nixpkgs `openspec` binary on `PATH`; `ohi` is the shared zsh alias.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `pkgs/nixos-scripts/cmd/opencode-harness-init/main.go` | New | Thin CLI entry point |
| `pkgs/nixos-scripts/internal/projectinit/projectinit.go` | New | Core init, conflict, Git detection |
| `pkgs/nixos-scripts/internal/projectinit/projectinit_test.go` | New | Behavior tests |
| `pkgs/nixos-scripts/default.nix` | Modified | Register subPackage, wrap `openspec` |
| `shared/shell-aliases.nix` | Modified | Expose `ohi` as the portable shell alias |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Overwriting a conflicting Engram project name | Med | Conflict detection blocks writes unless `--force` |
| Non-idempotent `openspec init` re-run | Low | Trigger only when `openspec/config.yaml` absent |
| Worktree `.git` file mis-detected | Low | `hasGit` walks parents; worktree test covers it |
| Failed write loses existing config | Low | Temp-file + rename preserves mode and data |

## Rollback Plan

Remove `cmd/opencode-harness-init` and `internal/projectinit` from `default.nix`, remove `ohi`, and delete both source directories. The change deletes no persisted data; revert is source-only.

## Dependencies

- Nixpkgs `openspec` binary (already a `buildGoModule` input, wrapped onto PATH). No new Go dependencies.

## Success Criteria

- [ ] `go -C pkgs/nixos-scripts test ./...` passes (dry-run, conflict, worktree cases).
- [ ] `opencode-harness-init --dry-run` writes nothing and reports intended actions; `ohi` resolves to it.
- [ ] Conflicting `.engram/config.json` rejected without `--force`; matching name is a no-op.
- [ ] Initialization succeeds in a Git repo, worktree, and non-Git directory.
- [ ] `nix flake check --no-build` passes; authored changes stay under the 400-line budget.
