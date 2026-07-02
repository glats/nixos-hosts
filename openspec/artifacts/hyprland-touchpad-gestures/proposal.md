# Proposal: Hyprland Touchpad Gestures

## Intent

Restore 3-finger horizontal workspace swipe on t14 (Hyprland). The gesture existed in nixos-hosts `hosts/t14/home/hypr/input.nix` (added 2026-06-11, removed 2026-06-27). Rather than re-adding it per-host, make it a **default in omarchy-nix** so all Omarchy consumers get it automatically and hosts can still override.

## Scope

### In Scope
- **omarchy-nix**: Add `gesture = lib.mkDefault "3, horizontal, workspace";` to `modules/home-manager/hyprland/input.nix`
- **nixos-hosts**: Update `flake.lock` to point to the new omarchy-nix commit; rebuild t14

### Out of Scope
- Multi-finger gestures (pinch, rotate) — not requested
- Per-host gesture customization in nixos-hosts — mkDefault already allows override
- Other omarchy-nix consumers' configs — they inherit the default automatically

## Capabilities

### New Capabilities
- `touchpad-gestures`: Default 3-finger horizontal workspace swipe for Hyprland touchpad input

### Modified Capabilities
None

## Approach

Add `gesture = lib.mkDefault "3, horizontal, workspace";` to omarchy-nix's `input.nix` under the existing touchpad settings block. Use `mkDefault` (not `mkForce`) so any host can override with `mkForce` if needed — mirrors the existing pattern where t14 already uses `mkForce` for `kb_layout` and `kb_options`.

The gesture string `"3, horizontal, workspace"` is Hyprland 0.51+ syntax, replacing the deprecated `gestures:workspace_swipe*` keys. Current nixpkgs-unstable pins Hyprland ≥ 0.51, so compatibility is confirmed.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `modules/home-manager/hyprland/input.nix` (omarchy-nix) | Modified | Add one line: `gesture = lib.mkDefault "3, horizontal, workspace";` |
| `flake.lock` (nixos-hosts) | Modified | Bump omarchy-nix input to new commit |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Hyprland version mismatch (gesture syntax) | Low | nixpkgs-unstable pins Hyprland ≥ 0.51; syntax confirmed |
| Other omarchy-nix consumers get unexpected gesture | Low | mkDefault is overridable; gesture is standard touchpad UX |
| omarchy-nix repo not in workspace | Low | Clone to /tmp, edit, commit, push, clean up |

## Rollback Plan

1. Revert the omarchy-nix commit (`git revert <sha>`)
2. Update nixos-hosts `flake.lock` back to previous omarchy-nix commit (`nix flake lock --update-input omarchy-nix`)
3. Rebuild t14: `nixos-build`

## Dependencies

- omarchy-nix push access (confirmed: full clone & push)
- Hyprland ≥ 0.51 in nixpkgs-unstable (confirmed)

## Success Criteria

- [ ] `hyprctl getoption general:gesture` returns `"3, horizontal, workspace"` on t14 after rebuild
- [ ] 3-finger horizontal swipe on touchpad switches workspaces
- [ ] t14's existing `mkForce` on kb_layout/kb_options still works (no regression)
- [ ] `nix flake check --no-build` passes in nixos-hosts
