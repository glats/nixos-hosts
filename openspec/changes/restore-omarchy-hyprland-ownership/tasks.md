# Tasks: Restore Omarchy Hyprland Ownership

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~30–50 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Delivery strategy | single-pr-default |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

## Phase 1: Upstream Boundary Fix (External Prerequisite)

- [ ] 1.1 In `glats/omarchy-nix`, modify `modules/nixos/hyprland.nix` to set `programs.hyprland.package = pkgs.hyprland` and `portalPackage = pkgs.xdg-desktop-portal-hyprland`.
- [ ] 1.2 In `glats/omarchy-nix`, modify `modules/home-manager/hyprland.nix` to set `wayland.windowManager.hyprland.package = lib.mkDefault null` and `portalPackage = lib.mkDefault null`.
- [ ] 1.3 Push upstream changes and record the commit SHA.

## Phase 2: Fallback (If Upstream Delayed)

- [ ] 2.1 Create `hosts/t14/hyprland-boundary.nix` consolidating the current `programs.hyprland` force block and `wayland.windowManager.hyprland` null-bridge.
- [ ] 2.2 Import the boundary module in `hosts/t14/default.nix` and remove scattered `mkForce` lines.
- [ ] 2.3 Delete `hosts/t14/hyprland-boundary.nix` once upstream is merged.

## Phase 3: Local Cleanup

- [ ] 3.1 Bump `inputs.omarchy-nix` in `flake.nix` to the upstream boundary-fix commit SHA.
- [ ] 3.2 Delete the `programs.hyprland` force-override block from `hosts/t14/default.nix`.
- [ ] 3.3 Delete the `wayland.windowManager.hyprland` null-bridge from `hosts/t14/home/omarchy.nix`.

## Phase 4: Verification

- [ ] 4.1 Run `nix flake check --no-build` and confirm no Hyprland evaluation errors.
- [ ] 4.2 Run `nixos-build dry` and confirm no build-time errors.
- [ ] 4.3 Search `hosts/t14/` to confirm no `lib.mkForce` on `programs.hyprland.*` or `wayland.windowManager.hyprland.*` remains.
