# Plugin Handling Specification

## Purpose

Define how OpenCode plugins are handled: always use upstream plugins from the vanilla derivation. Local plugins exist only for functionality that does NOT exist upstream (e.g., `engram.ts`). If an upstream plugin has a bug, PR to upstream instead of maintaining local overrides.

## Requirements

### Requirement: Upstream Plugins Only

The vanilla derivation MUST copy all upstream plugins from `internal/assets/opencode/plugins/` to `$out/share/gentle-ai/opencode/plugins/` without modification. The layered derivation MUST NOT modify, override, or add to the plugins directory.

#### Scenario: Vanilla includes all upstream plugins

- GIVEN upstream contains `internal/assets/opencode/plugins/background-agents.ts`
- WHEN `vanilla.nix` is built
- THEN `$out/share/gentle-ai/opencode/plugins/background-agents.ts` exists
- AND its content is byte-identical to the upstream file

#### Scenario: Layered derivation does not touch plugins

- GIVEN the layered derivation is built on top of vanilla
- WHEN inspecting the layered output's `opencode/plugins/` directory
- THEN it is identical to vanilla's `opencode/plugins/` directory
- AND no local plugin files have been added or overridden

### Requirement: Local Plugins Only for Non-Upstream Functionality

Local plugins MUST only exist for functionality that does NOT exist upstream. If a plugin exists upstream, the upstream version MUST be used. If an upstream plugin has a bug, the fix MUST be contributed upstream via PR rather than maintained as a local override. The engram plugin (`engram.ts`) now comes from the upstream `engram-src` flake input via the `engram-assets` derivation, NOT from a local file.

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

The `opencode.nix` home activation script MUST copy upstream plugins from the nix store path instead of hardcoded local file paths. This includes both `gentle-ai-assets` plugins (from `${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/plugins/`) and `engram.ts` (from `${pkgs.engram-assets}/share/engram/opencode/plugins/engram.ts`).

#### Scenario: Activation copies upstream plugins from nix store

- GIVEN the activation script runs during home-manager switch
- WHEN it copies upstream plugin files (e.g., `background-agents.ts`)
- THEN it reads from `${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/plugins/`
- AND it does NOT reference `${./opencode/plugins/...}` paths for upstream plugins

#### Scenario: Activation copies engram from nix store

- GIVEN `cfg.plugins.engram.enable = true`
- WHEN the activation script runs
- THEN it copies `engram.ts` from `${pkgs.engram-assets}/share/engram/opencode/plugins/engram.ts`
- AND it does NOT reference `${./opencode/plugins/engram.ts}`

#### Scenario: Disabled plugin is not copied

- GIVEN `cfg.plugins.backgroundAgents.enable = false` OR `cfg.plugins.engram.enable = false`
- WHEN the activation script runs
- THEN the disabled plugin is NOT copied to the runtime directory
- AND no error occurs

### Requirement: Plugin Directory Structure

The final `gentle-ai-assets` output MUST contain an `opencode/plugins/` directory with upstream plugins only. Local plugins are NOT included in the derivation output — they are copied directly by the activation script.

#### Scenario: Plugins directory contains upstream only

- GIVEN `gentle-ai-assets` is built
- WHEN inspecting the output
- THEN `$out/share/gentle-ai/opencode/plugins/` exists as a directory
- AND it contains only upstream `.ts` files (no local files)
