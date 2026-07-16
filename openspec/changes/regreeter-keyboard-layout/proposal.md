# Proposal: regreeter-keyboard-layout

## Intent

Add visual keyboard-layout feedback to the t14 greetd login screen. The layout toggle (Alt+Shift, es/latam) works today but with zero indication of which layout is active. A waybar-based indicator in the greeter Hyprland compositor will show "ES" or "LATAM" so users know their state before typing the password.

## Scope

### In Scope
- Greeter waybar config (minimal, `custom/kb-layout` module only) at `/etc/greetd/waybar-config`
- `omarchy-nix` submodule: `omarchy.greeter.layoutIndicator.enable` (bool, default false)
- `exec-once` line in generated greeter Hyprland config to launch waybar before regreet
- `GTK_USE_PORTAL=0` env in greeter Hyprland config to prevent GTK portal deadlocks
- Documentation update in `hosts/t14/home/omarchy.nix` architecture block

### Out of Scope
- Ctrl+Shift toggle (separate XKB option decision)
- Other hosts (rog=SDDM, thinkcentre=headless, mact2=nix-darwin)
- User session waybar changes (already has `custom/language` module)
- EWW/AGS/yad alternatives

## Capabilities

### Modified Capabilities
- `greeter-script`: REQ-GS-004 (keyboard layout at login) extended with visual feedback scenario — the indicator SHALL display the active layout name ("es" or "latam") in the greeter compositor within 2 seconds of a toggle

## Approach

**Option A: waybar in greeter mode** (recommended, per exploration analysis).

Architecture: Hyprland greeter compositor -> `exec-once` launches waybar with `/etc/greetd/waybar-config` -> custom module polls `hyprctl devices -j` -> shows active layout.

Waybar uses layer-shell (bottom bar, 24px height) — avoids overlapping ReGreet's centered login form. The custom module runs: `hyprctl devices -j | jq -r '.keyboards[] | select(.main) | .active_keymap'` on a 1-second interval. ReGreet startup delayed 0.5s to avoid waybar race.

Changes span TWO repos: `omarchy-nix` (config generation + submodule) and `nixos-hosts` (waybar config + host enablement).

## Affected Areas

| Repo | File | Change |
|------|------|--------|
| omarchy-nix | `config.nix` | New `greeter.layoutIndicator` submodule (enable bool, waybar package) |
| omarchy-nix | `modules/nixos/system.nix` | `GTK_USE_PORTAL=0`, `exec-once` for waybar, 0.5s delay before regreet |
| nixos-hosts | `hosts/t14/default.nix` | Enable `layoutIndicator`, waybar greeter config |
| nixos-hosts | `hosts/t14/home/omarchy.nix` | Architecture doc update |

## Risks

| Risk | Like. | Mitigation |
|------|-------|------------|
| waybar/regreet startup race | Med | 0.5s delay in greeter script; `exec-once` ordering guarantees waybar runs first |
| GTK portal deadlock | Low | `GTK_USE_PORTAL=0` env var |
| `jq` not in greeter closure | Low | Add `pkgs.jq` to greetd session PATH |
| layer-shell bar overlaps login form | Low | `height: 24`, bottom `dock` mode; test on t14 |

## Questions for User

1. **Alt+Shift vs Ctrl+Shift**: Codebase uses `grp:alt_shift_toggle` everywhere. User mentioned "Ctrl+Shift." Is Alt+Shift correct, or switch to `grp:ctrl_shift_toggle`?

2. **Visual style**: Bottom bar with "ES" / "LATAM" text, or top bar with an icon? Default approach is minimal text in a bottom bar matching the user session waybar style.

## Rollback Plan

Set `omarchy.greeter.layoutIndicator.enable = false` and rebuild. Removes the `exec-once` line from generated Hyprland config and the waybar config file. No state migration needed.

## Dependencies

- `omarchy-nix` repo write access (owned: `github.com/glats/omarchy-nix`)
- `pkgs.waybar` and `pkgs.jq` (already in nixpkgs unstable)

## Success Criteria

- [ ] Greeter waybar displays "es" or "latam" at login screen (t14)
- [ ] Display updates within 2s of Alt+Shift toggle
- [ ] ReGreet login form remains fully functional (no focus steal, no overlap)
- [ ] `nix flake check --no-build` passes for t14
- [ ] Non-t14 hosts unaffected
