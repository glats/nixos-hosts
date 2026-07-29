# Proposal: final-cleanup

## Intent

Ship 5 independent low-risk cleanups accumulated during prior refactors. No new behavior. Each item is scoped, reversible, and trivially verifiable.

## Scope

### In Scope
1. **omarchy.nix prune** (P0) — Audit 18 mkForce overrides in `hosts/t14/home/omarchy.nix`. Remove dead ones: omarchy-nix upstream may now default `fonts.fontconfig.enable = false`, `rotate_on_start = false`, or `gtk.theme = "Materia-dark-compact"`. Keep must-haves (fcitx5, browser, zsh, starship, copyScreensaverTxt, fcitx5 ExecStart patching, CSD margin CSS). Verify: t14 builds + Hyprland login works.
2. **nix-vscode-extensions gate** (P1) — Flake input fetched on all hosts, only used by `darwin/home/vscode.nix`. Two options: (a) accept ~2s eval overhead, add comment noting darwin-only; (b) gate with `pkgs.stdenv.hostPlatform.isDarwin` in vscode.nix so linux evals skip it. Option (b) preferred — no build impact, trivially correct.
3. **providers-extra.nix → shared/** (P1) — 412-line reference file at `darwin/home/opencode/providers-extra.nix`, currently NOT imported by any config. Move to `shared/opencode/providers-extra.nix`. Update `shared/opencode/providers.nix` to merge extras when present. Both platforms gain 10 providers (groq, cerebras, mistral, openrouter, etc.). No behavior change until `activeProviderName` is set to one of them.
4. **mcps-extra.nix: homeDirectory** (P1) — Replace 2 hardcoded `/Users/jcuzmar/` paths (lines 42-43) with `${config.home.homeDirectory}`. Also `config.home.username` for the wrapper script path if non-portable. 2-line change.
5. **remote-desktop + spotlight-index audit** (P2) — Check: `linux/home/remote-desktop.nix` (316 lines, 6 hosts), `darwin/home/remote-desktop.nix` (259 lines), `darwin/home/spotlight-index.nix` (144 lines). Flag: Paths like `/home/glats` in remmina.pref + mkDesktop are portable across linux hosts. If clean, no changes.

### Out of Scope
- Adding new providers to active profile tier lists
- Refactoring omarchy.nix beyond mkForce removal
- Changing remote-desktop connection targets or credentials

## Capabilities

None — pure cleanup, no spec-level behavior change.

## Approach

1. Omarchy: diff each mkForce vs upstream omarchy-nix `homeManagerModules.default`. If upstream now defaults to same value, remove. Rebuild t14, verify Hyprland+waybar+fcitx5+Edge.
2. nix-vscode-extensions: In `darwin/home/vscode.nix`, wrap extensions block in `pkgs.stdenv.hostPlatform.isDarwin` guard.
3. providers-extra: `cp` to `shared/opencode/`, update `providers.nix` to `lib.optionalAttrs (builtins.pathExists ...)` merge. Update `format-nix` exclusions if needed.
4. mcps-extra: Edit 2 lines, `format-nix`, verify mact2 builds.
5. Audit: Read all 3 files. Report findings inline. No code changes unless issues found.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `hosts/t14/home/omarchy.nix` | Modified | Remove dead mkForce overrides |
| `darwin/home/vscode.nix` | Modified | Gate nix-vscode-extensions behind isDarwin |
| `darwin/home/opencode/providers-extra.nix` | Removed | Moved to shared/ |
| `shared/opencode/providers-extra.nix` | New | Copied from darwin/home/ |
| `shared/opencode/providers.nix` | Modified | Merge providers-extra when available |
| `darwin/home/opencode/mcps-extra.nix` | Modified | homeDirectory paths |
| `flake.nix` | Comment | (optional) add darwin-only note on input |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Omarmacy removal breaks t14 Hyprland | Low | Build-only change; rollback = restore file |
| providers-extra fails to resolve on Linux | Low | Guard with `builtins.pathExists` |
| nix-vscode-extensions gate skips darwin by accident | Low | Test vscode.nix extension list on mact2 build |

## Rollback Plan

Revert each item independently: `git checkout <file>` for the specific file. No schema or data migrations. nix flake check validates each one.

## Dependencies

- Upstream omarchy-nix `homeManagerModules.default` — read latest to compare defaults.

## Success Criteria

- [ ] `nix flake check --no-build` passes for t14, rog, mact2
- [ ] t14: `nix build .#nixosConfigurations.t14.config.system.build.toplevel` succeeds
- [ ] mact2: `nix build .#darwinConfigurations.mact2.system` succeeds
- [ ] Each mkForce removal verified against upstream default
- [ ] mcps-extra.nix has no `/Users/` hardcoded paths
- [ ] Audit report for remote-desktop + spotlight-index (pass/fail with notes)
