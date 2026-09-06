# Proposal: relocate-go-module

## Intent

Move the Go module from the repo root into its own package directory — `pkgs/nixos-scripts/` — so the source, tests, and derivation co-locate as one NixOS package. The module path (`github.com/glats/nixos-scripts`) already matches the package name, so no import churn. This supersedes the bash-to-go-migration spec's "repo root MUST contain go.mod" requirement (requirement 1) with the co-located layout.

## Scope

### In Scope
- `git mv go.mod go.sum cmd internal` → `pkgs/nixos-scripts/` (module path unchanged).
- `pkgs/nixos-scripts/default.nix`: `lib.fileset` whitelist → `src = ./.;` (the module dir IS the whitelist; `secrets/` structurally unreachable).
- Update bias surfaces: `shared/rules/go-scripts.md` + repo `AGENTS.md` (Project Structure, When Coding #9, Critical Rules #8) to the new paths + `go -C pkgs/nixos-scripts test ./...` command.
- Compact openspec record (this file + tasks.md).

### Out of Scope
- DevShell with Go toolchain — deferred: `flake.nix` carries uncommitted WIP from other sessions; do not mix.
- Renaming the package (`nixos-scripts`) — name stays.
- The 2 bash exceptions in `bin/` — untouched.

## Risks

| Risk | Mitigation |
|---|---|
| Untracked files invisible to flake source (bit 3x in prior waves) | `git add` immediately after `git mv`, before any nix command. |
| Tests assume cwd | Run from module dir (`go -C pkgs/nixos-scripts test ./...`); checkPhase unaffected (buildGoModule chdirs to source root). |

## Verification

Same wave protocol: `go -C pkgs/nixos-scripts test ./... && format-nix && nix flake check --no-build && nix build .#nixos-scripts` + store source inspection (now = pkgs/nixos-scripts content) + t14 toplevel eval via flake check.
