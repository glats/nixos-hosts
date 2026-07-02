# Tasks: nautilus-dark-mode-t14

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~15 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | single-pr |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Fix Nautilus dark mode on t14 | PR 1 | Single file, ~15 lines changed |

## Phase 1: Implementation

- [ ] 1.1 In `hosts/t14/default.nix`, remove the line `xdg.portal.extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];` (redundant — omarchy-nix provides this)
- [ ] 1.2 In `hosts/t14/default.nix`, add `environment.etc."xdg/xdg-desktop-portal/portals/gtk.portal".text` block with full portal definition including `DBusName`, `Interfaces` (with `Settings`), and `UseIn=gnome;hyprland`
- [ ] 1.3 In `hosts/t14/default.nix`, add `xdg.portal.config.hyprland` with `default = lib.mkForce [ "hyprland" "gtk" ]` and `"org.freedesktop.impl.portal.Settings" = lib.mkForce [ "gtk" ]`

## Phase 2: Formatting & Validation

- [ ] 2.1 Run `nix fmt -- hosts/t14/default.nix` to ensure nixfmt compliance
- [ ] 2.2 Run `nix flake check --no-build` to validate the full flake evaluates

## Phase 3: Verification Plan

- [ ] 3.1 After rebuild + re-login: `rm ~/.local/share/xdg-desktop-portal/portals/gtk.portal` (delete stale user-level override)
- [ ] 3.2 Verify portal Settings interface: `dbus-send --session --print-reply --dest=org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop org.freedesktop.portal.Settings.ReadAll array:string:"org.freedesktop.appearance"` — expect `color-scheme = uint32 1`
- [ ] 3.3 Launch Nautilus — confirm dark theme renders (dark titlebar, sidebar, content)
