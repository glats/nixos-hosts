# Proposal: nautilus-dark-mode-t14

## Intent
Fix Nautilus dark mode on t14 (Hyprland) by ensuring xdg-desktop-portal exports the Settings interface.

## Motivation
The system's `gtk.portal` has `UseIn=gnome` (excluding Hyprland`. The user's override at `~/.local/share/xdg-desktop-portal/portals/gtk.portal` is incomplete (missing `DBusName` and `Interfaces`). As a result, `find_all_portal_implementations("org.freedesktop.impl.portal.Settings")` returns empty, the portal never exports the Settings interface on `/org/freedesktop/portal/desktop`, and libadwaita stays in light mode.

Diagnostics confirmed: dconf is correct (`prefer-dark`), GTK impl works directly, but portal Settings interface is absent.

## Scope

### Changes
- `hosts/t14/default.nix`: Remove redundant `xdg.portal.extraPortals`, add `environment.etc` for correct gtk.portal, add explicit portal config with `Settings=gtk`

### Not changed
- `hosts/t14/home/omarchy.nix` — no changes needed
- `modules/` — no new module needed
- `flake.nix` — no new inputs
- User-side cleanup: `rm ~/.local/share/xdg-desktop-portal/portals/gtk.portal`

## Affected Files

| File | Change |
|------|--------|
| `hosts/t14/default.nix` | 3 edits: (1) remove `xdg.portal.extraPortals` line, (2) add `environment.etc` block, (3) add `xdg.portal.config.hyprland` with `Settings=gtk` |

## Implementation Plan

1. In `hosts/t14/default.nix` (~line 130), replace:
```nix
  xdg.portal.extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
```
with:
```nix
  environment.etc."xdg/xdg-desktop-portal/portals/gtk.portal".text = ''
    [portal]
    DBusName=org.freedesktop.impl.portal.desktop.gtk
    Interfaces=org.freedesktop.impl.portal.FileChooser;org.freedesktop.impl.portal.AppChooser;org.freedesktop.impl.portal.Print;org.freedesktop.impl.portal.Notification;org.freedesktop.impl.portal.Inhibit;org.freedesktop.impl.portal.Access;org.freedesktop.impl.portal.Account;org.freedesktop.impl.portal.Email;org.freedesktop.impl.portal.DynamicLauncher;org.freedesktop.impl.portal.Lockdown;org.freedesktop.impl.portal.Settings;org.freedesktop.impl.portal.Wallpaper;
    UseIn=gnome;hyprland
  '';

  xdg.portal.config.hyprland = {
    default = lib.mkForce [ "hyprland" "gtk" ];
    "org.freedesktop.impl.portal.Settings" = lib.mkForce [ "gtk" ];
  };
```

2. User post-rebuild: `rm ~/.local/share/xdg-desktop-portal/portals/gtk.portal` + re-login.

## Verification

```sh
dbus-send --session --print-reply --dest=org.freedesktop.portal.Desktop \
  /org/freedesktop/portal/desktop \
  org.freedesktop.portal.Settings.ReadAll array:string:"org.freedesktop.appearance"
# Expect: color-scheme = uint32 1

# Launch Nautilus — should render in dark mode
```

## Risks

| Risk | Mitigation |
|------|------------|
| `lib.mkForce` fights omarchy-nix | Intentional — omarchy-nix only sets `default`; `Settings=gtk` is additive |
| Portal restart drops active dialogs | Apply at re-login boundary, not mid-session |
| hyprland-portal later adds Settings support | Re-evaluate `Settings=gtk` override if that happens |

## Rollback
Remove the `environment.etc` and `xdg.portal.config.hyprland` blocks, restore original `xdg.portal.extraPortals` line, rebuild.