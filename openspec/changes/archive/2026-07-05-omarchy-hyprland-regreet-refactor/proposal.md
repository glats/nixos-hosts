# Proposal: omarchy-hyprland-regreet-refactor

## Intent

Remove obsolete, redundant, and fragile custom configuration in the t14 Hyprland/ReGreet stack while preserving its working architecture. The config has accumulated technical debt across nixos-hosts and omarchy-nix repos: one obsolete env var (WLR_RENDERER_ALLOW_SOFTWARE), a redundant boot module wrapper, a 140-line embedded bash script without error handling, and a full-opacity windowrule that defeats omarchy's theme system. This change removes that debt without altering the greeter's Hyprland-based architecture, which exists to provide keyboard-layout switching at login.

## Scope

### In Scope

| File | Change |
|------|--------|
| `hosts/t14/home/hypr/looknfeel.nix` | Remove `WLR_RENDERER_ALLOW_SOFTWARE,0` (obsolete on Hyprland 0.54+ with AMD iGPU) |
| `hosts/t14/home/hypr/input.nix` | Gate full-opacity `windowrule` behind configurable boolean, remove `mkAfter` blanket |
| `modules/features/boot.nix` | Consolidate `boot-settings` into `hosts/t14/default.nix` direct options, remove wrapper module |
| `hosts/t14/home/hypr/hyprsunset.nix` | Migrate from raw config to `services.hyprsunset.settings` (requires omarchy-nix upstream PR first) |
| `hosts/t14/home/default.nix` | Simplify waybar unit using HM declarative `systemd.user.services` |
| `hosts/t14/home/omarchy.nix` | Add comments documenting the Hyprland-as-greeter-compositor architecture decision |
| omarchy-nix `system.nix` | Extract `greetd-regreet-start` script into `writeShellScriptBin`, add timeouts and `stderr` logging |

### Out of Scope

- Replacing Hyprland with cage/sway for the greeter (kb-layout switching is a hard requirement)
- Changing the greetd session file architecture
- Refactoring overlay patches (xdp/gvfs), kb-toggle scripts, mouse-wiggle, or HDM config

## Approach

**Approach C: Gradual Cleanup** -- eliminates dead code and improves maintainability without redesigning the greeter. Changes ordered from lowest to highest risk: obsolete removals, then boot consolidation, then hyprsunset migration (after omarchy-nix PR), then script extraction last.

## Rollback Plan

Each change is a separate commit. Rollback is per-commit via `git revert`:

1. **NixOS rollback**: `nixos-rebuild switch --rollback` to previous generation
2. **Greeter safety net**: Before script extraction, verify `systemd.mask=greetd.service` kernel fallback works
3. **Recovery validation**: `nixos-build dry` before each group; `nixos-build` before final switch
4. **omarchy-nix upstream**: PR merged there first; nixos-hosts flake input update follows

## Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| Greeter breakage during script extraction | High | Script extraction done last; functional changes minimal (add error handling, move to file); VT fallback tested beforehand |
| omarchy-nix upstream sync delay | Medium | nixos-hosts work independent of omarchy-nix PR except hyprsunset task |
| Boot regression from module consolidation | Low | Direct substitution; verify with `nixos-rebuild boot` + reboot |

## Success Criteria

1. `nix flake check --no-build` passes for t14 after each commit
2. `nix build .#nixosConfigurations.t14.config.system.build.toplevel` succeeds
3. `WLR_RENDERER_ALLOW_SOFTWARE,0` removed without replacement
4. Full-opacity windowrule gated behind configurable boolean (not `mkAfter`)
5. `boot-settings.enable` no longer referenced in t14 config
6. `hyprsunset` uses `services.hyprsunset.settings` declaratively
7. Greeter script exists as standalone file with 2s timeout and stderr logging
8. `nixos-build dry` reports no unintended changes to non-t14 hosts

## Affected Hosts

- **t14**: Only affected host -- uses omarchy-nix + Hyprland/ReGreet stack
- **rog**: NOT affected -- uses i3 + lightdm, no omarchy-nix dependency
- **thinkcentre**: NOT affected -- uses KDE, no Hyprland
- **mact2**: NOT affected -- macOS via nix-darwin, separate stack

## Dependencies

- omarchy-nix PR for hyprsunset HM module migration (blocks hyprsunset task only)
- `nix flake update` of omarchy-nix input after upstream PR merged
- No new nixpkgs options or packages required -- all changes use existing modules
