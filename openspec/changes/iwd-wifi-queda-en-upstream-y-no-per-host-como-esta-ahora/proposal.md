# Proposal: iwd-wifi waybar indicator → upstream omarchy-nix

## Intent

The iwd-wifi waybar indicator script lives inline in `hosts/t14/home/default.nix` (nixos-hosts) but is deployed unused — never wired into the waybar bar. Moving it upstream to omarchy-nix makes it a shared asset via the existing `recursive = true` waybar mechanism, and wiring the `custom/iwd-wifi` block into the static waybar config activates it. This eliminates per-host duplication and delivers the actual UX improvement.

## Scope

### In Scope
- Extract `iwd-wifi.sh` from t14 per-host config into `config/waybar/indicators/iwd-wifi.sh` in omarchy-nix
- Add `custom/iwd-wifi` block (signal 11) + `modules-right` entry to `config/waybar/config` in omarchy-nix
- Delete per-host iwd-wifi block (lines 58-80) from `hosts/t14/home/default.nix` in nixos-hosts
- Bump `flake.lock` via `nix flake update omarchy-nix`
- Update top comment in `hosts/t14/home/default.nix`

### Out of Scope
- Conditional gating on `wifi.backend` (Approach B — deferred to follow-up)
- Other per-host scripts (kb-toggle, kb-layout, mouse-wiggle — audited, not candidates)
- Nix-based JSON generation for waybar config (preserves static-copy + U+E900 glyph pattern)

## Capabilities

### New Capabilities
- `iwd-wifi-indicator`: Waybar indicator for standalone-iwd WiFi status, deployed via omarchy-nix's waybar module with signal-based updates and `custom/iwd-wifi` bar block.

### Modified Capabilities
None — no existing specs cover waybar or wifi indicators.

## Approach

**Approach A: Static unconditional add.** Add `iwd-wifi.sh` to `config/waybar/indicators/` and wire `custom/iwd-wifi` into `config/waybar/config` unconditionally. Uses signal 11 (next free after 7-10). Script returns disconnected-icon JSON when iwd doesn't manage wlan0 — safe on `nm-iwd` systems (extra disconnected icon accepted for v1).

**Delivery: Direct commits on main.** No feature branches, no PRs. omarchy-nix commits first, then nixos-hosts flake lock bump + cleanup.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `config/waybar/indicators/iwd-wifi.sh` (omarchy-nix) | New | Script extracted from t14 per-host config |
| `config/waybar/config` (omarchy-nix) | Modified | Add `custom/iwd-wifi` block (signal 11) + `modules-right` entry |
| `hosts/t14/home/default.nix` (nixos-hosts) | Modified | Delete lines 58-80, update top comment |
| `flake.lock` (nixos-hosts) | Modified | Bump omarchy-nix input |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Two wifi icons on `nm-iwd` systems | Certain | Accepted v1 trade-off; Approach B follow-up deferred |
| `wlan0` hard-coded | Low | Matches `system.nix:230` convention; document in script header |
| Signal 11 collision | Low | Next free; commit to omarchy-nix first to establish |

## Rollback Plan

1. **omarchy-nix**: `git revert` the commit on main — removes script + config block.
2. **nixos-hosts**: `git revert` the deletion commit + `nix flake update omarchy-nix` to pin previous.
3. Reverts are independent and order-agnostic.

## Dependencies

- omarchy-nix commits must land on main BEFORE nixos-hosts flake lock bump
- `nix flake update omarchy-nix` requires omarchy-nix main to be current

## Success Criteria

- [ ] `iwd-wifi.sh` exists at `config/waybar/indicators/iwd-wifi.sh` in omarchy-nix and is executable
- [ ] `custom/iwd-wifi` block present in `config/waybar/config` with signal 11
- [ ] `custom/iwd-wifi` listed in `modules-right`
- [ ] iwd-wifi block removed from `hosts/t14/home/default.nix`
- [ ] `nix flake check --no-build` passes in nixos-hosts
- [ ] `format-nix` clean
- [ ] Visual confirmation: iwd-wifi indicator appears on t14 waybar after rebuild
