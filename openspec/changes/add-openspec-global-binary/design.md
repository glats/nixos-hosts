# Design: Add Global openspec Binary

## Technical Approach

Add the lock-selected `pkgs.openspec` derivation to the existing `home.packages` list in each platform shell module. Home Manager then links the executable into the user's profile, so existing profile PATH handling exposes bare `openspec` without a wrapper, overlay, custom derivation, or project-local setup.

```text
flake.lock → nixpkgs pkgs.openspec → platform shell module
                                      → home.packages → user profile/bin → PATH
```

## Architecture Decisions

| Decision | Alternatives considered | Rationale |
|---|---|---|
| Own the package in `linux/home/shell.nix` and `darwin/home/shell.nix` | System packages, Darwin's broad `packages.nix`, a new shared module | These two modules already own the baseline shell runtime package `pkgs.nixos-scripts` and are imported by each platform's canonical Home Manager module list. Two additive entries reach every target with no new module, registration, or system-level scope. |
| Select `pkgs.openspec` from the existing nixpkgs input | New upstream GitHub flake input, overlay, wrapper, custom derivation | The package already exists in the flake's locked nixpkgs package set on Linux and Darwin. Reusing it preserves one update boundary and the same derivation source already injected into `project-init`; another input would add lock and source-identity drift without capability. |
| Keep platform-local declarations | One cross-platform abstraction | The repository intentionally maintains separate Linux and Darwin shell modules and package lists. A shared abstraction would add a file and import wiring for one package while obscuring current ownership. |

The design intentionally names no fixed package version: verification reads the version selected by the current lock, avoiding stale documentation when `flake.lock` advances.

## Host Scope

`linux/home/shared-modules.nix` imports `linux/home/shell.nix`; `rog`, `thinkcentre`, and `t14` all compose that list, and t14's filter does not exclude the shell module. `darwin/home/shared-modules.nix` imports `darwin/home/shell.nix`, which `darwin/home/default.nix` supplies to `macm5`. This covers integrated and standalone Home Manager configurations for the declared users only; it does not install a system-wide binary for unrelated users.

## File Changes

| File | Action | Description |
|---|---|---|
| `linux/home/shell.nix` | Modify | Append `pkgs.openspec` without changing existing package entries. |
| `darwin/home/shell.nix` | Modify | Expand the package list and append `pkgs.openspec` without changing `pkgs.nixos-scripts`. |

No Nix module option or new interface is introduced. The only contract is the existing Home Manager `home.packages` list and the resulting user-profile PATH entry.

## Verification Plan

1. Format only the two touched Nix files with `nix fmt -- <paths>` and run `nix flake check --no-build`.
2. Evaluate `.#nixosConfigurations.{rog,thinkcentre,t14}.config.system.build.toplevel.drvPath`, `.#darwinConfigurations.macm5.config.system.build.toplevel.drvPath`, and all four `.#homeConfigurations.<host>.activationPackage.drvPath` targets because flake check does not cover Darwin or standalone Home Manager outputs.
3. Confirm each evaluated Home Manager package list contains the corresponding host's `pkgs.openspec` derivation, and confirm no flake input, overlay, wrapper, or `pkgs/nixos-scripts` change appears in the implementation diff.
4. After activation on each host, run `command -v openspec`, `openspec --version`, and `openspec list --json` from a directory without project initialization.

## Threat Matrix

This matrix is reviewed because the change exposes an executable on PATH, but it adds no command construction or execution logic.

| Boundary | Applicability | Design response | Planned RED tests |
|---|---|---|---|
| Documentation-like paths | N/A: no file classification or execution | None | None |
| Git repository selection | N/A: no Git or cwd selection | None | None |
| Commit state | N/A: no index/worktree behavior | None | None |
| Push state | N/A: no remote/ref resolution | None | None |
| PR commands | N/A: no command composition or PR automation | None | None |

## Migration / Rollout

No migration or phased rollout is required. Apply through the normal Home Manager-backed host activation. Roll back by removing the two added list entries and re-applying the affected Linux and Darwin configurations; no persistent data or project state is created.

## Open Questions

None.
