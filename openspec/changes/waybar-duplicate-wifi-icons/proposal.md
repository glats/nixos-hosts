# Proposal: Waybar Duplicate WiFi Icons (Revised)

## Intent

On t14 (`standalone-iwd`), waybar shows a misleading disconnected icon (`󰤮` — wifi-off) next to the iwd wifi widget that shows wifi IS connected. The `network` widget can only reflect ethernet state when NM unmanages wlan0, so its "disconnected" glyph lies about wifi. Additionally, `#custom-iwd-wifi` has no CSS rules, causing the glyph to appear clipped against `pulseaudio`. Fix the icon and the spacing — keep both widgets visible.

## Scope

### In Scope
- Change `network` widget's `format-disconnected` from wifi-off (`󰤮`) to LAN-disconnect (`󰌙`) — a generic "no network" icon
- Add `#custom-iwd-wifi` to the existing right-side CSS selector group for proper spacing
- Bump omarchy-nix flake lock in nixos-hosts after fix lands

### Out of Scope
- Removing the `network` widget entirely (user decision: keep both)
- Modifying `iwd-wifi.sh` indicator script
- Changes to `nm-iwd` hosts (they show wifi correctly via `network` widget)

## Capabilities

### New Capabilities
None — this is a fix to existing waybar config, not a new capability.

### Modified Capabilities
None — waybar has no existing spec in `openspec/specs/`.

## Approach

Two one-line changes in omarchy-nix:

1. **`config/waybar/config` line 86**: Change `"format-disconnected": "󰤮"` (U+F092E, nf-md-wifi-off) to `"format-disconnected": "󰌙"` (U+F0319, nf-md-lan_disconnect). This icon accurately represents "no ethernet" without implying wifi is off.

2. **`config/waybar/style.css` line 32-36**: Add `#custom-iwd-wifi` to the existing selector `#cpu, #battery, #pulseaudio, #custom-omarchy, #custom-update` that sets `min-width: 12px; margin: 0 7.5px;`. This gives the iwd widget the same spacing as other right-side modules.

After omarchy-nix is updated, nixos-hosts bumps the flake lock to pull the fix.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `config/waybar/config` (omarchy-nix) | Modified | Line 86: `format-disconnected` icon change |
| `config/waybar/style.css` (omarchy-nix) | Modified | Add `#custom-iwd-wifi` to right-side module group selector |
| `flake.lock` (nixos-hosts) | Modified | Bump omarchy-nix rev |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| `nm-iwd` hosts see different disconnected icon (LAN instead of wifi) | Low | Acceptable — LAN-disconnect is semantically correct for "no network" in any mode |
| CSS selector change affects other modules unintentionally | Very Low | Only adding `#custom-iwd-wifi` to existing rule — no other selectors touched |

## Rollback Plan

Revert the two lines in omarchy-nix (`format-disconnected` icon + CSS selector). Revert flake.lock bump in nixos-hosts. Rebuild.

## Dependencies

- nixos-hosts must bump omarchy-nix flake input after the omarchy-nix commit lands

## Success Criteria

- [ ] `nix flake check --no-build` passes in omarchy-nix
- [ ] Disconnected icon shows `󰌙` (LAN disconnect), not `󰤮` (wifi-off)
- [ ] `#custom-iwd-wifi` has proper spacing (12px min-width, 7.5px margins) — no clipping
- [ ] Both ethernet (from NM) and wifi (from iwd) icons visible simultaneously
- [ ] `nm-iwd` hosts unaffected — `network` widget still shows wifi icons correctly
