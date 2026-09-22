# Proposal: Add Global openspec Binary

## Intent

OpenCode SDD subagents need bare `openspec` (e.g. `openspec list --json`) in arbitrary projects, but today it is only wrapped onto `PATH` inside the `project-init` Go binary. Expose the pinned Nixpkgs `pkgs.openspec` package to Home Manager users on every Linux and Darwin host so the CLI is available globally, independent of project initialization.

## Scope

### In Scope

- Add `pkgs.openspec` to `home.packages` in `linux/home/shell.nix`.
- Add `pkgs.openspec` to `home.packages` in `darwin/home/shell.nix`.
- Bare `openspec` resolvable on every host's interactive shell (`rog`, `thinkcentre`, `t14`, `macm5`).

### Out of Scope

- Any change to `add-project-init` or its `project-init` wrapping (separate change).
- Upstream GitHub flake; pin remains Nixpkgs `pkgs.openspec`.
- Engram/OpenSpec tooling behavior or configuration.

## Capabilities

### New Capabilities

- `openspec-global-runtime`: bare `openspec` CLI available on PATH for Home Manager users on all hosts, independent of any project.

### Modified Capabilities

None.

## Approach

Use the pinned Nixpkgs `pkgs.openspec` (v1.2.0), already an input in the flake. Append it to the existing `home.packages` lists in both shell modules. No wrapper, overlay, or new derivation. Home Manager's standard `home.packages` install makes the binary available in the user's `~/.nix-profile/bin`, which both shells prepend to `PATH`.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `linux/home/shell.nix` | Modified | Add `pkgs.openspec` to `home.packages` (`rog`, `thinkcentre`, `t14`) |
| `darwin/home/shell.nix` | Modified | Add `pkgs.openspec` to `home.packages` (`macm5`) |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Package name/attr drift from Nixpkgs | Low | Verified `pkgs.openspec` (1.2.0) exists in nixpkgs-26.05 |
| Binary collision with `project-init`-wrapped `openspec` | Low | Both resolve to the same pinned Nixpkgs derivation; no separate wrapper is introduced |

## Rollback Plan

Remove the `pkgs.openspec` line from both `home.packages` lists and re-apply. No files, secrets, or persistent state are touched; revert is a two-line source revert plus `nixos-build switch` / `darwin-rebuild switch`.

## Dependencies

- Pinned Nixpkgs `pkgs.openspec` (verified v1.2.0). No new inputs or overlays.

## Success Criteria

- [ ] `openspec list --json` resolves on the PATH of every host's Home Manager user shell.
- [ ] `nix flake check --no-build` passes.
- [ ] Linux host evaluation (`.#nixosConfigurations.<host>.config.system.build.toplevel`) and Darwin evaluation (`.#darwinConfigurations.macm5.config.system.build.toplevel`) succeed.
- [ ] No changes to `add-project-init` or `pkgs/nixos-scripts`.
