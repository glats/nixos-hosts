# Waybar Duplicate WiFi Icons — Specification

## Purpose

Fix visual confusion on `standalone-iwd` hosts (t14) where waybar displays two adjacent wifi icons: the NM-backed `network` widget shows a wifi-off glyph (`󰤮`) because NM does not manage wlan0, while the iwd-backed `custom/iwd-wifi` widget shows actual wifi state. Additionally fix CSS clipping of the iwd-wifi widget into adjacent modules.

## Requirements

### Requirement: Disconnected Icon Clarity

The `network` module `format-disconnected` MUST use `󰌙` (U+F0319, nf-md-lan_disconnect) instead of `󰤮` (U+F092E, nf-md-wifi-off).

This ensures the disconnected state does not imply wifi is off when the widget cannot report wifi state on `standalone-iwd` hosts.

#### Scenario: standalone-iwd host with wifi connected, no ethernet

- GIVEN the host uses `standalone-iwd` wifi backend (t14)
- AND wlan0 is managed by iwd, not NetworkManager
- AND wifi is connected to an SSID
- AND no ethernet interface is active
- WHEN waybar renders the `network` module
- THEN it SHALL display `󰌙` (LAN disconnect icon)
- AND the `custom/iwd-wifi` module SHALL display the connected SSID

#### Scenario: standalone-iwd host with ethernet connected

- GIVEN the host uses `standalone-iwd` wifi backend
- AND an ethernet interface is active and connected
- WHEN waybar renders the `network` module
- THEN it SHALL display `󰀂` (ethernet icon)
- AND the `custom/iwd-wifi` module SHALL display wifi state independently

#### Scenario: standalone-iwd host with no network

- GIVEN the host uses `standalone-iwd` wifi backend
- AND no ethernet is connected
- AND wifi is disconnected
- WHEN waybar renders both modules
- THEN `network` SHALL display `󰌙` (LAN disconnect)
- AND `custom/iwd-wifi` SHALL display `󰤮` (wifi-off)
- AND the two icons SHALL be visually distinct (different glyphs)

### Requirement: IWD-WiFi Widget CSS Spacing

The `#custom-iwd-wifi` CSS selector MUST be included in the right-side module group that sets `min-width: 12px; margin: 0 7.5px`.

#### Scenario: iwd-wifi widget does not clip into adjacent modules

- GIVEN waybar is rendered on any host with `custom/iwd-wifi` in `modules-right`
- WHEN the `custom/iwd-wifi` module displays its icon
- THEN it SHALL have `min-width: 12px` and `margin: 0 7.5px`
- AND it SHALL NOT visually overlap or clip into the `pulseaudio` module

### Requirement: nm-iwd Hosts Unaffected (Regression Guard)

Hosts using the `nm-iwd` wifi backend MUST NOT regress. The `network` module SHALL continue to display wifi signal-strength icons (`format-icons`) when wifi is connected via NetworkManager.

#### Scenario: nm-iwd host with wifi connected

- GIVEN the host uses `nm-iwd` wifi backend (rog, thinkcentre)
- AND wifi is connected via NetworkManager
- WHEN waybar renders the `network` module
- THEN it SHALL display the appropriate signal-strength icon from `format-icons`
- AND the `format-disconnected` glyph change SHALL only apply when disconnected

### Requirement: Nerd Font Glyph Availability

All glyphs referenced in the waybar config MUST be available in the configured Nerd Font.

#### Scenario: All icons render without missing-glyph placeholders

- GIVEN the waybar config uses `󰌙` (U+F0319), `󰤮` (U+F092E), and `󰀂` (U+F0302)
- WHEN waybar renders on any host
- THEN each glyph SHALL render as its intended icon
- AND no missing-glyph placeholders SHALL appear

## Dependencies

- omarchy-nix repo: `config/waybar/config` (line 86) and `config/waybar/style.css` (lines 32-36)
- nixos-hosts repo: `flake.lock` must bump omarchy-nix rev after fix lands
- Nerd Font (via omarchy font configuration) MUST include Material Design Icons codepoints U+F0319, U+F092E, U+F0302
