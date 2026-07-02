# Proposal: wayvnc remote desktop — verify & fix after migration

## Intent

The wayvnc VNC server (t14) and Remmina client (all Linux hosts) were migrated
to the upstream `omarchy-nix` wayvnc module and `home-linux/remote-desktop.nix`.
The migration is functionally complete but left a stale comment referencing two
deleted scripts. Two optional ergonomic restorations are also proposed.

## Scope

### In Scope
- Fix stale comment in `home-linux/base.nix:14` (remove dead script examples)
- Add `wayvncctl output-cycle` Hyprland keybind on t14 (optional)
- Restore `connect-wayvnc-t14` shell launcher in `home-linux/remote-desktop.nix` (optional)
- Verify with `nix flake check --no-build`

### Out of Scope
- Changes to omarchy-nix upstream modules (owned by separate repo)
- Remmina profile content or VNC server configuration (already correct)
- Firewall rules (explicitly disabled on t14 by design — trusted LAN)

## Capabilities

### New Capabilities
- `wayvncctl-keybind`: Hyprland keybind on t14 for `wayvncctl output-cycle`
  (screen output cycling for VNC viewers)

### Modified Capabilities
None — no existing spec-level behavior changes.

## Approach

1. **Stale comment fix**: Edit `home-linux/base.nix:14` to list only `openfang-start`.

2. **wayvncctl keybind**: Add `wayland.windowManager.hyprland.settings.bind` in
   `hosts/t14/home/omarchy.nix` mapping `SUPER CTRL, R` to `wayvncctl output-cycle`.
   `wayvncctl` is already in PATH via `pkgs.wayvnc` (omarchy-nix NixOS module).

3. **connect-wayvnc-t14 launcher**: Add `home.file.".local/bin/connect-wayvnc-t14"`
   in `home-linux/remote-desktop.nix` wrapping
   `remmina -c ~/.local/share/remmina/vnc-t14.remmina`. ~3 lines.

4. **Verify**: `nix flake check --no-build` to confirm all hosts evaluate.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `home-linux/base.nix` | Modified | Remove stale comment examples (lines 13-15) |
| `home-linux/remote-desktop.nix` | Modified | Add `connect-wayvnc-t14` shell launcher (optional) |
| `hosts/t14/home/omarchy.nix` | Modified | Add `wayvncctl output-cycle` keybind (optional) |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Keybind collision with omarchy default | Low | `SUPER CTRL, R` is unassigned in omarchy bindings.nix |
| `wayvncctl` unavailable at keypress time | Low | `pkgs.wayvnc` is in systemPackages via omarchy-nix NixOS module |
| Comment fix breaks documentation context | None | Only removing dead references; `openfang-start` still documented |

## Rollback Plan

All changes are single-file edits. Revert via `git revert` on the commit.
The stale comment fix is purely cosmetic and safe to revert independently.

## Dependencies

- `omarchy-nix` wayvnc module (already wired — no new dependency)
- `pkgs.wayvnc` provides both `wayvnc` and `wayvncctl` binaries

## Success Criteria

- [ ] `nix flake check --no-build` passes for all hosts (rog, thinkcentre, t14)
- [ ] `home-linux/base.nix` comment references only existing scripts
- [ ] (If keybind added) `SUPER CTRL, R` triggers `wayvncctl output-cycle` on t14
- [ ] (If launcher added) `connect-wayvnc-t14` resolves in shell and opens Remmina
