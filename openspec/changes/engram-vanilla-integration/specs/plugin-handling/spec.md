# Delta for Plugin Handling

## MODIFIED Requirements

### Requirement: Local Plugins Only for Non-Upstream Functionality

Local plugins MUST only exist for functionality that does NOT exist upstream. If a plugin exists upstream, the upstream version MUST be used. If an upstream plugin has a bug, the fix MUST be contributed upstream via PR rather than maintained as a local override. The engram plugin (`engram.ts`) now comes from the upstream `engram-src` flake input via the `engram-assets` derivation, NOT from a local file.

(Previously: engram.ts was copied from local `modules/home/opencode/plugins/engram.ts`)

#### Scenario: engram.ts comes from upstream via nix store

- GIVEN `engram.ts` exists in upstream `engram-src` at `plugin/opencode/engram.ts`
- WHEN the activation script runs with `cfg.plugins.engram.enable = true`
- THEN `engram.ts` is copied from `${pkgs.engram-assets}/share/engram/opencode/plugins/engram.ts`
- AND no local `modules/home/opencode/plugins/engram.ts` file exists

#### Scenario: Upstream plugin bug is fixed upstream

- GIVEN an upstream plugin has a bug
- WHEN a fix is needed
- THEN the fix is submitted as a PR to the upstream repository
- AND no local override is created

### Requirement: Nix Store Path for Upstream Plugins

The `opencode.nix` home activation script MUST copy upstream plugins from the nix store path instead of hardcoded local file paths. This now includes `engram.ts`, which is sourced from `${pkgs.engram-assets}/share/engram/opencode/plugins/engram.ts`.

(Previously: engram.ts was copied from `${./opencode/plugins/engram.ts}` local path)

#### Scenario: Activation copies engram from nix store

- GIVEN the activation script runs during home-manager switch
- WHEN it copies the engram plugin file
- THEN it reads from `${pkgs.engram-assets}/share/engram/opencode/plugins/engram.ts`
- AND it does NOT reference `${./opencode/plugins/engram.ts}`

#### Scenario: engram toggle controls copy from nix store

- GIVEN `cfg.plugins.engram.enable = true`
- WHEN the activation script runs
- THEN it copies `engram.ts` from the nix store engram plugins directory
- AND the file is placed in `$runtime_dir/plugins/engram.ts`

#### Scenario: Disabled plugin is not copied

- GIVEN `cfg.plugins.engram.enable = false`
- WHEN the activation script runs
- THEN `engram.ts` is NOT copied to the runtime directory
- AND no error occurs
