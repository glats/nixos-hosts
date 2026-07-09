# Delta for skill-deployment

## ADDED Requirements

### Requirement: sdd-review-policy.md Deployment

`shared/opencode.nix` SHALL deploy `sdd-review-policy.md` to `~/.config/opencode/sdd-review-policy.md` using the same pattern as `sdd-orchestrator.md`:

- A `home.file` entry sourcing from `${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/sdd-review-policy.md`
- An entry in the `makeOpencodeConfigMutable` activation for-loop (line 145) for symlink-to-real-copy conversion

#### Scenario: File deployed on rebuild

- GIVEN `nixos-build switch` completes
- WHEN checking `~/.config/opencode/sdd-review-policy.md`
- THEN the file exists as a real (non-symlink) file matching the source

#### Scenario: File survives nuke and rebuild

- GIVEN `~/.config/opencode/` is fully deleted
- WHEN `nixos-build switch` runs
- THEN `sdd-review-policy.md` is present AND identical to the source in the nix store

#### Scenario: Activation loop converts symlink to real copy

- GIVEN Home Manager created a symlink at `~/.config/opencode/sdd-review-policy.md`
- WHEN `makeOpencodeConfigMutable` activation runs
- THEN the symlink is replaced with a real copy via `cp --remove-destination`

#### Scenario: Orphan cleanup does not delete the file

- GIVEN orphan cleanup runs on `skills/` and `commands/` only
- WHEN `sdd-review-policy.md` exists at `~/.config/opencode/`
- THEN the file is NOT deleted (orphan cleanup scope excludes root-level files)
