# Tasks: OpenCode TUI Plugin Integration

## Phase 1: Flake Inputs — `flake.nix`

- [x] 1.1 Add `sub-agent-statusline-src` input fetching `github:Joaquinvesapa/sub-agent-statusline` with `flake = false`
- [x] 1.2 Add `sdd-engram-plugin-src` input fetching `github:j0k3r-dev-rgl/sdd-engram-plugin` with `flake = false`
- [x] 1.3 Add both new inputs to the `outputs` function destructuring

## Phase 2: Plugin Options — `modules/home/opencode/plugins.nix`

- [x] 2.1 Add `tuiPlugins` submodule under `home.opencode.plugins`
- [x] 2.2 Add `tuiPlugins.subAgentStatusline.enable` boolean option (default `false`)
- [x] 2.3 Add `tuiPlugins.sddEngramPlugin.enable` boolean option (default `false`)
- [x] 2.4 Add `home.opencode.activeTuiPlugins` internal option (computed list of enabled plugin names)

## Phase 3: Integration — `modules/home/opencode.nix`

- [x] 3.1 Pass `inputs` through to `mkRuntimeConfig` via closure
- [x] 3.2 Extend `tui.json` generation — add `plugins` array when tuiPlugins are enabled
- [x] 3.3 Extend `package.json` — add npm deps for enabled TUI plugins (github: protocol)
- [x] 3.4 Extend activation script — copy TUI plugin `.ts` files from nix store to plugins dir
- [x] 3.5 Extend activation script — include TUI plugin packages in `npm install`

## Phase 4: Validation

- [x] 4.1 Run `nix flake check`
- [x] 4.2 Run `format-nix`
- [x] 4.3 Run `nixos-build dry` for rog
- [x] 4.4 Run `nixos-build dry` for thinkcentre

> **Dependencies**: Phase 2 depends on Phase 1 (inputs needed by options).  
> Phase 3 depends on Phase 2 (options shape wiring). Phase 4 is last.

## Completion

**Status**: ✅ ALL 16/16 TASKS COMPLETE
**Completed**: 2026-04-28
**Verification**: 13/13 spec scenarios compliant (PASS WITH WARNINGS)
