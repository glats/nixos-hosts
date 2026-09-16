# Nix Verification Harness Specification

## Purpose

Define tree-safe formatting, non-redundant checks, coverage boundaries, and worktree safety.

## Requirements

### Requirement: RFC-166 Tree Formatting

The flake MUST expose `pkgs.nixfmt-tree` for `x86_64-linux`, `x86_64-darwin`, and `aarch64-darwin` on pinned nixos-26.05. Bare `nix fmt` MUST format applicable `.nix` files beneath the current flake tree, while `nix fmt -- <path>` MUST support targeted formatting.

#### Scenario: Format from a worktree [hosts: rog, thinkcentre, t14, mact2, macm5]

- GIVEN a checkout under `.worktrees/`
- WHEN bare `nix fmt` runs from that worktree root
- THEN applicable `.nix` files in that worktree are formatted with RFC-166 style
- AND files in the main checkout are unchanged

#### Scenario: Format one file [hosts: rog, thinkcentre, t14, mact2, macm5]

- GIVEN one touched `.nix` file
- WHEN `nix fmt -- <touched-file>` runs
- THEN that file is formatted without requiring a newer nixpkgs revision

### Requirement: Auditable Treewide Reformat

The RFC-166 migration MUST reformat every repository `.nix` file without semantic edits in one format-only commit. A later commit MUST record that format commit hash in `.git-blame-ignore-revs`.

#### Scenario: Review the migration history [hosts: rog, thinkcentre, t14, mact2, macm5]

- GIVEN the formatter migration commits
- WHEN their diffs and blame-ignore entry are inspected
- THEN the format-only commit contains only `.nix` formatting changes
- AND `.git-blame-ignore-revs` names that exact commit

### Requirement: Non-redundant Flake Checks

`checks.x86_64-linux` MUST NOT repeat the rog, thinkcentre, or t14 toplevels. A format check MUST be added only if design validation on nixos-26.05 proves deterministic fail-on-change behavior; otherwise it MUST be omitted.

#### Scenario: Evaluate tier 3 once per NixOS host [hosts: rog, thinkcentre, t14]

- GIVEN the custom toplevel checks are absent
- WHEN `nix flake check --no-build` runs
- THEN each declared `nixosConfiguration` is still evaluated through native flake checking
- AND no custom check evaluates the same host toplevel again

#### Scenario: Decide format-check admission [hosts: rog, thinkcentre, t14]

- GIVEN pinned nixos-26.05
- WHEN design validates the candidate format check
- THEN the check is present only if unchanged input passes and formatting drift fails deterministically

### Requirement: Explicit Verification Coverage and Worktree Safety

Repository guidance MUST preserve three verification tiers and state that `nix flake check` covers NixOS configurations but not `darwinConfigurations` or standalone `homeConfigurations`. It MUST require targeted evaluation of exclusions, cwd-scoped commands in worktrees, and prohibit `format-nix` there because it targets `/etc/nixos`.

#### Scenario: Verify shared changes from a worktree [hosts: rog, thinkcentre, t14, mact2, macm5]

- GIVEN shared-scope changes in a worktree
- WHEN an operator follows repository guidance
- THEN commands target the worktree flake through its current working directory
- AND Darwin and standalone Home Manager outputs receive explicit targeted evaluations

### Requirement: Retained Main-checkout Formatting Front-end

`format-nix` MUST remain a Go command for `/etc/nixos` and retain `--check` fail-on-drift behavior and key messages. It SHOULD delegate traversal to `nixfmt-tree` where behavior is equivalent, and repository configuration MUST identify it as the main-checkout front-end.

#### Scenario: Check the main checkout without mutation [hosts: rog, thinkcentre, t14]

- GIVEN unformatted `.nix` content under `/etc/nixos`
- WHEN `format-nix --check` runs
- THEN it reports formatting drift with a non-zero exit without changing tracked files
- AND no shell operational script is introduced

### Requirement: Compatibility Verification

The completed shared-scope change MUST pass the tier-3 gate from the worktree and targeted evaluations for rog, thinkcentre, t14, mact2, macm5, and every declared standalone Home Manager configuration.

#### Scenario: Complete the verification matrix [hosts: rog, thinkcentre, t14, mact2, macm5]

- GIVEN the harness and format migration are complete
- WHEN the documented tier-3 and targeted evaluation commands run from the worktree
- THEN every required evaluation succeeds against pinned nixos-26.05

## Out of Scope

The change MUST NOT add treefmt-nix, deadnix, git-hooks.nix, nix-eval-jobs, hydraJobs, statix, flake-checker, GitHub Actions CI, or a new bash operational script.
