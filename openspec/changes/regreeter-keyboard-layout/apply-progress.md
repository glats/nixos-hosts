# Apply Progress: regreeter-keyboard-layout

## Implementation Summary

Implemented layoutIndicator submodule (omarchy.greeter.layoutIndicator) across two repos:

- **omarchy-nix**: config.nix submodule + system.nix config generation (script, waybar, env, delay)
- **nixos-hosts**: t14 enablement + architecture doc update

## Completed Tasks

### Phase 1: omarchy-nix — Submodule Definition

- [x] 1.1 **config.nix** — Added `layoutIndicator` submodule to `greeter` block after `wayvnc`. Options: `enable` (bool, default false, mkEnableOption), `style` (lines, default ""). Follows existing `wayvnc` submodule pattern.
- [x] 1.2 **Verify** — `nix flake check --no-build` passes for omarchy-nix flake (verified directly). Submodule defaults to disabled.

### Phase 2: omarchy-nix — Config Generation

- [x] 2.1 **system.nix** — Added `greetd-kb-layout` polling script (`writeShellScriptBin`). Parses `hyprctl devices -j | jq .active_keymap`, maps via shell `case`: `*Spanish*` -> "ES", `*Latino*|*Latin*` -> "LATAM", fallback -> "?". Full store paths for hyprctl and jq.
- [x] 2.2 **system.nix** — Added waybar config derivation (`pkgs.writeText` + `builtins.toJSON`): `layer: bottom`, `position: bottom`, `height: 24`, single `custom/kb-layout` module right-aligned, `interval: 1`, no tooltip.
- [x] 2.3 **system.nix** — Added waybar stylesheet derivation: sans-serif 14px, white text (#cdd6f4), translucent dark background (rgba(30,30,46,0.9)), appended `cfg.greeter.layoutIndicator.style`.
- [x] 2.4 **system.nix** — Added Hyprland template fragments: `gtkPortalEnv` (`env = GTK_USE_PORTAL,0`) and `waybarExec` (`exec-once = waybar -c /etc/greetd/waybar-config -s /etc/greetd/waybar-style.css`). Inserted before `${monitorBlock}` in template.
- [x] 2.5 **system.nix** — Added `environment.etc."greetd/waybar-config"` and `"greetd/waybar-style.css"` entries (using `.source` pointing to derivations), gated on `regreet && layoutIndicator.enable`.
- [x] 2.6 **system.nix** — Inserted `sleep 0.5` delay at Phase 0 of `greetd-regreet-start` script, gated on `layoutIndicator.enable`.
- [x] 2.7 **Verify** — `nix flake check --no-build` passes for t14 (verified via local path override). All hosts pass.

### Phase 3: nixos-hosts — Enable & Document

- [x] 3.1 **hosts/t14/default.nix** — Added `layoutIndicator.enable = true` in `omarchy.greeter` block (after `wayvnc` block).
- [x] 3.2 **hosts/t14/home/omarchy.nix** — Appended to GREETER ARCHITECTURE comment block: mentions waybar provides visual kb-layout feedback via `omarchy.greeter.layoutIndicator`.
- [x] 3.3 **Verify** — `nix flake check --no-build` for t14 (with local omarchy-nix override), rog, thinkcentre, mact2 — all pass.

## Files Changed

| File | Action | What Was Done |
|------|--------|---------------|
| `omarchy-nix/config.nix` | Modified | Added `layoutIndicator` submodule after `wayvnc` |
| `omarchy-nix/modules/nixos/system.nix` | Modified | Added script, waybar config+style derivations, gtkPortalEnv/waybarExec template fragments, environment.etc entries, startup delay |
| `nixos-hosts/hosts/t14/default.nix` | Modified | Added `layoutIndicator.enable = true` |
| `nixos-hosts/hosts/t14/home/omarchy.nix` | Modified | Updated GREETER ARCHITECTURE comment |

## Verification

| Host | Result | Notes |
|------|--------|-------|
| omarchy-nix flake | PASS | Direct `nix flake check --no-build` on local repo |
| t14 | PASS | Via local path override (pinned to github URL normally) |
| rog | PASS | No omarchy dependency on layoutIndicator |
| thinkcentre | PASS | No omarchy dependency on layoutIndicator |
| mact2 | PASS | Darwin config, no omarchy dependency |

## Deviations from Design

- Used `.source` instead of `.text` + `builtins.readFile` for `environment.etc` entries. This is cleaner (symlinks to derivation output instead of embedding), functionally equivalent, and follows standard NixOS module patterns for store-path sources.
- All other aspects match the design exactly.

## Issues

None. Implementation matches spec and design. All checks pass.

## Status

11/11 tasks complete. Ready for verify phase.
