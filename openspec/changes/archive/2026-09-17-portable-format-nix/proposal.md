# Proposal: Portable Format Nix

## Intent

Make `format-nix` usable from any Nix project, including Darwin, instead of requiring `/etc/nixos`. It must format the caller's project by default while retaining an explicit directory target and `--check` behavior.

## Scope

### In Scope
- Add one optional positional directory: `format-nix [directory] [--check]`.
- Discover the containing flake from the caller's working directory when no directory is supplied; fail clearly when none exists.
- Preserve recursive `.nix` discovery, skipped directories, formatter invocation, and check-mode exit semantics.
- Update Go unit coverage and CLI help for the portable target rules.

### Out of Scope
- A redundant `--path`/`--directory` flag or environment-variable root override.
- Changing the formatter, supporting non-flake directories, or formatting files outside the selected project.

## Capabilities

### New Capabilities
- `portable-nix-formatting`: Select a Nix project from an explicit directory or caller context and format its Nix files.

### Modified Capabilities
None.

## Approach

Refactor the Go command's target resolution before changing directory: an explicit positional directory wins; otherwise walk upward from the caller's working directory to a directory containing `flake.nix`. Validate the selected directory and retain the existing per-file `nix fmt --` workflow. Do not use `NIXOS_REPO`, `NIX_PATH`, or other Nix variables as implicit roots.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `pkgs/nixos-scripts/cmd/format-nix/main.go` | Modified | Parse target argument and resolve a containing flake. |
| `pkgs/nixos-scripts/cmd/format-nix/main_test.go` | Modified | Cover explicit, discovered, and missing-project target selection. |
| All NixOS and Darwin hosts | Modified | Installed command gains portable project selection without host configuration changes. |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Incorrect root selection formats an unintended tree | Medium | Explicit path takes precedence; discovery requires `flake.nix`; tests cover nested directories and failure. |
| CLI compatibility regression | Low | Preserve `--check`, help, exit codes, and existing file traversal behavior. |

## Rollback Plan

Revert the command and tests to the prior `/etc/nixos`-targeted implementation, then rebuild `nixos-scripts`; no persistent state or configuration migration is involved.

## Dependencies

- Existing `nix` CLI and each selected project's `flake.nix` formatter.

## Success Criteria

- [ ] From a nested directory in a flake project, `format-nix` selects that project's root and processes every eligible `.nix` file.
- [ ] `format-nix /explicit/project --check` uses the positional directory and preserves check-mode results.
- [ ] Outside a flake project without a positional directory, the command errors without formatting files.
- [ ] Go tests pass and the `nixos-scripts` derivation builds.
