# Proposal: Remove picom compositor, enable marco compositing for xrdp hosts

## Intent

picom external compositor (xrender backend) is incompatible with xrdp's virtual X11 sessions, causing GTK apps and MATE panel to disappear or turn black. This is a documented upstream issue (yshui/picom#1433). Both rog and thinkcentre import picom and serve xrdp sessions. The fix removes picom and enables MATE's built-in marco compositor, which uses software XRender natively and works correctly in virtual X11 sessions.

## Scope

### In Scope
- Remove `home-linux/picom.nix` import from rog host modules
- Remove `home-linux/picom.nix` import from thinkcentre host modules
- Change dconf lock from `compositing-manager = false` to `compositing-manager = true` (unlocked)
- Verify via `nix flake check --no-build`

### Out of Scope
- Conditional picom wrapper (deferred — revisit only if rog HDMI console tearing is reported)
- Removing `home-linux/picom.nix` file itself (kept for potential future non-xrdp hosts)
- Any xrdp configuration changes

## Capabilities

### New Capabilities

None — this is a pure configuration change with no new system capabilities.

### Modified Capabilities

None — no existing specs define compositor behavior or xrdp desktop rendering requirements.

## Approach

**Approach A (from exploration):** Remove picom, enable marco compositing.

1. Delete line 9 (`../../../home-linux/picom.nix`) from both `hosts/rog/home/modules.nix` and `hosts/thinkcentre/home/modules.nix`
2. In `modules/base/dconf.nix`, replace the locked `compositing-manager = false` block with `compositing-manager = true` (no lock), preserving the `mkIf (config.my.desktop.suite == "mate")` gate
3. marco's built-in xrender compositor handles shadows, transparency, and tear-free rendering in software mode — exactly what xrdp provides

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `hosts/rog/home/modules.nix` | Modified | Remove picom.nix import (line 9) |
| `hosts/thinkcentre/home/modules.nix` | Modified | Remove picom.nix import (line 9) |
| `modules/base/dconf.nix` | Modified | Replace locked `false` with unlocked `true` |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| marco compositing may tear on rog direct HDMI console with NVIDIA 580.legacy | Low | Rare use case. If reported, add conditional picom wrapper for rog only (Approach B). |

## Rollback Plan

Revert the 3 files: re-add picom.nix imports to both hosts, restore dconf lock with `compositing-manager = false`. One commit revert.

## Dependencies

None — no external changes required.

## Success Criteria

- [ ] GTK apps and MATE panel render correctly in xrdp sessions on rog and thinkcentre
- [ ] `nix flake check --no-build` passes
- [ ] No picom process running in xrdp sessions on either host
- [ ] marco compositing shows shadows and transparency in xrdp sessions
