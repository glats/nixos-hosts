# Exploration: nautilus-dark-mode-t14

## Problem Statement

Nautilus (libadwaita 1.8.x) does not activate dark mode on the t14 Hyprland host
despite multiple intended configuration paths:

- dconf `org.gnome.desktop.interface color-scheme = "prefer-dark"`
- GTK4 `~/.config/gtk-4.0/settings.ini` with `gtk-interface-color-scheme=dark`
- Home-Manager `gtk.colorScheme = "dark"` and `gtk.gtk4.extraConfig."gtk-interface-color-scheme" = "dark"`
- `xdg-desktop-portal-gtk` declared via `xdg.portal.extraPortals`

The user (and orchestrator) reported a root-cause hypothesis: xdg-desktop-portal
1.20.4 does not register `org.freedesktop.portal.Settings` as a bus name, and
libadwaita is therefore unable to find the portal.

**This exploration confirms parts of that hypothesis and refutes others.** The
real situation is more nuanced — the portal exposes the Settings interface on
the standard bus name, but the configuration pipeline is broken in three places
on this host.

## Current Configuration (verified by reading the workspace)

### Workspace files relevant to this change

| File | Role |
|------|------|
| `/home/glats/.nixos/hosts/t14/default.nix` | t14 NixOS entry; sets `xdg.portal.extraPortals` (lines 130-134) |
| `/home/glats/.nixos/hosts/t14/home/omarchy.nix` | t14 home-manager entry; sets GTK4 extraConfig (lines 121-134) |
| `/home/glats/.nixos/modules/base/dconf.nix` | system-level dconf databases (only `org/mate/marco/general` is set) |
| `/home/glats/.nixos/home-linux/theme.nix` | **EXCLUDED from t14** — but is the file that sets `dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark"` (lines 58-60) |
| `/home/glats/.nixos/.local/share/xdg-desktop-portal/portals/gtk.portal` | **WRONG LOCATION** — user override at user level |

### What omarchy-nix (pinned to commit `769481a`) already does

The upstream `omarchy-nix` module imported via `inputs.omarchy-nix.nixosModules.default`
already configures the xdg portal correctly:

```nix
# modules/nixos/hyprland.nix (omarchy-nix)
xdg.portal = {
  enable = true;
  extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  config.common.default = "*";
  config.hyprland.default = [ "hyprland" "gtk" ];
};
xdg.portal.config.hyprland."org.freedesktop.impl.portal.InputCapture" = [ "hyprland" ];
```

The HM counterpart already sets the dconf key from the active theme:

```nix
# modules/home-manager/default.nix (omarchy-nix)
dconf.settings = {
  "org/gnome/desktop/interface" = {
    color-scheme = if isLightModeEnabled then "prefer-light" else "prefer-dark";
  };
};
gtk = {
  enable = true;
  theme = {
    name   = if isLightModeEnabled then "Adwaita"       else "Adwaita-dark";
    package = pkgs.gnome-themes-extra;
  };
  cursorTheme = { name = if isLightModeEnabled then "Bibata-Modern-Classic" else "Bibata-Modern-Ice"; ... };
};
```

With `omarchy.theme = "glats"` and no `~/.config/omarchy/theme/light.mode` file,
the dconf key is set to `"prefer-dark"`.

### What the t14 host file redundantly does

```nix
# hosts/t14/default.nix
xdg.portal.extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
```

This is **redundant** (omarchy-nix already adds it), but harmless — NixOS `listOf`
options merge by concatenation and `pkgs.buildEnv` deduplicates. It also means
the comment "xdg-desktop-portal-hyprland does NOT implement Settings — without
this portal, Nautilus ignores the dark mode preference" is **misleading**: the
omarchy-nix config already solves the missing-Settings problem.

## Root Cause Analysis

### What xdg-desktop-portal 1.20.4 actually does (verified by reading the source)

**Confirmed by reading `flatpak/xdg-desktop-portal/src/xdg-desktop-portal.c`
(tag `1.20.4`):**

```c
owner_id = g_bus_own_name (G_BUS_TYPE_SESSION,
                           "org.freedesktop.portal.Desktop",  // <-- only ONE bus name
                           G_BUS_NAME_OWNER_FLAGS_ALLOW_REPLACEMENT | ...,
                           on_bus_acquired, on_name_acquired, on_name_lost,
                           NULL, NULL);
```

And from `shared/xdp-types.h` (1.20.4):

```c
#define DESKTOP_DBUS_NAME      "org.freedesktop.portal.Desktop"
#define DESKTOP_DBUS_IFACE     "org.freedesktop.portal"
#define DESKTOP_DBUS_IMPL_IFACE "org.freedesktop.impl.portal"
#define DESKTOP_DBUS_PATH      "/org/freedesktop/portal/desktop"

#define SETTINGS_DBUS_IFACE     DESKTOP_DBUS_IFACE ".Settings"     // org.freedesktop.portal.Settings
#define SETTINGS_DBUS_IMPL_IFACE DESKTOP_DBUS_IMPL_IFACE ".Settings" // org.freedesktop.impl.portal.Settings
```

And in `src/xdg-desktop-portal.c`:

```c
impls = find_all_portal_implementations ("org.freedesktop.impl.portal.Settings");
if (impls->len > 0)
  export_portal_implementation (connection, settings_create (connection, impls));
```

`settings_create` then exports the `org.freedesktop.portal.Settings` interface on
`/org/freedesktop/portal/desktop`, aggregating the `Read()` / `ReadAll()` / `SettingChanged`
methods across all impls.

**Correction to the orchestrator's premise:**

> The user reported "/org/freedesktop/portal/settings exists but is empty".

That path is **wrong** — the canonical object path is `/org/freedesktop/portal/desktop`.
The empty result is consistent with `dbus-send` querying a non-existent object.
The actual object lives at `/org/freedesktop/portal/desktop` on the bus name
`org.freedesktop.portal.Desktop`.

### What libadwaita 1.5+ actually queries (verified by reading the source)

**Confirmed by reading the libadwaita commit `[libadwaita/wip/exalm/dark: 8/15] Add AdwSettings`:**

```c
#define PORTAL_BUS_NAME          "org.freedesktop.portal.Desktop"
#define PORTAL_OBJECT_PATH       "/org/freedesktop/portal/desktop"
#define PORTAL_SETTINGS_INTERFACE "org.freedesktop.portal.Settings"

self->settings_portal = g_dbus_proxy_new_for_bus_sync (G_BUS_TYPE_SESSION,
                                                      G_DBUS_PROXY_FLAGS_NONE,
                                                      NULL,
                                                      PORTAL_BUS_NAME,        // NOT "org.freedesktop.portal.Settings"
                                                      PORTAL_OBJECT_PATH,
                                                      PORTAL_SETTINGS_INTERFACE,
                                                      NULL, &error);
```

So libadwaita does **not** look for a separate `org.freedesktop.portal.Settings`
bus name. It correctly queries `org.freedesktop.portal.Desktop` and asks for the
`org.freedesktop.portal.Settings` *interface* on `/org/freedesktop/portal/desktop`.
The orchestrator's premise about a missing bus name is incorrect — the
architecture is correct; the problem is elsewhere.

### What libadwaita does on failure (verified)

```c
if (read_portal_setting (self, "org.freedesktop.appearance", "color-scheme", "u", &v)) {
  self->has_color_scheme = TRUE;
  self->color_scheme_use_fdo_setting = TRUE;
  ...
}
if (!self->has_color_scheme &&
    read_portal_setting (self, "org.gnome.desktop.interface", "color-scheme", "s", &v)) {
  self->has_color_scheme = TRUE;
  ...
}
if (!self->has_color_scheme && g_settings_schema_has_key (schema, "color-scheme")) {
  self->has_color_scheme = TRUE;
  ...g_settings_get_enum (...)
}
```

If the portal returns `XDG_DESKTOP_PORTAL_ERROR_NOT_FOUND` for both keys, and the
local dconf schema lacks the key, `AdwStyleManager:system-supports-color-schemes`
is `FALSE`, and the app stays in the default light scheme.

### What xdg-desktop-portal-gtk 1.15.3 actually implements (verified by reading the source)

`flatpak/xdg-desktop-portal-gtk/src/settings.c`:
- Watches `org.gnome.desktop.interface` dconf schema (not `org.freedesktop.appearance`)
- Maps the dconf `color-scheme` enum (`0/1/2`) to portal responses
- Exports at object path `DESKTOP_PORTAL_OBJECT_PATH` = `/org/freedesktop/portal/desktop`
- Bus name is whatever is configured in `portals.conf` (typically `org.freedesktop.impl.portal.desktop.gtk`)

So if the dconf key `org/gnome/desktop/interface/color-scheme` is `"prefer-dark"`
in the **user database that xdg-desktop-portal-gtk reads**, the portal should
return `uint32 1` (prefer-dark) for `org.freedesktop.appearance color-scheme`.

### What GTK4 4.20+ does (verified by reading the source)

GTK 4.20 introduced `Gtk.InterfaceColorScheme` (UNSUPPORTED/DEFAULT/DARK/LIGHT)
and the `gtk-interface-color-scheme` property. Importantly, GTK4 4.20+ **removed
support for `GTK_USE_PORTAL=1`** outside flatpak:

```c
// gdk/gdk.c (4.20+)
gboolean gdk_should_use_portal (void) {
  if (GDK_DISPLAY_DEBUG_CHECK (NULL, PORTALS))  // GDK_DEBUG=portals
    return TRUE;
  if (gdk_running_in_sandbox ())                // /.flatpak-info
    return TRUE;
  return FALSE;
}
```

This means in a non-flatpak Hyprland session, **GTK4 falls back to reading the
dconf key directly** (via `GSettings`), not via the portal. The NixOS module
`xdg.portal.gtkUsePortal` was **removed** for this reason.

### Summary of the actual cause

The portal architecture is correct. libadwaita's query path is correct.
xdg-desktop-portal-gtk's implementation is correct. The bug is in the
**environment the portal reads from**. The most likely culprits, in order of
probability:

1. **Stale running portal process.** xdg-desktop-portal is a long-running
   systemd user service. If it was started before the omarchy-nix portal config
   (`xdg.portal.config.hyprland.default = [...]`) was applied, it has cached
   the empty `find_all_portal_implementations()` result and will not pick up
   the GTK impl until the user service is restarted. The user's
   `~/.local/share/xdg-desktop-portal/portals/gtk.portal` `UseIn=hyprland` is
   also at the **wrong directory** (XDG_DATA `share/xdg-desktop-portal/portals/`
   is for portal implementations, not user config) and uses the deprecated
   `UseIn=` syntax.

2. **dconf key not actually present at runtime.** Although omarchy-nix's HM
   module sets `dconf.settings."org/gnome/desktop/interface".color-scheme`, if
   the user's dconf is not synced (e.g. running from a different `DBUS_SESSION_BUS_ADDRESS`
   than the one the dconf service was registered with), the portal-gtk impl
   will see `0` (no preference) and the portal returns `NOT_FOUND`.

3. **xdg-desktop-portal-gtk failing to start.** The `xdg-desktop-portal-gtk`
   binary is added to PATH and its D-Bus service file is auto-launched, but
   if the impl is not found by `find_all_portal_implementations`, no proxy is
   created and `settings_create` returns NULL — silently disabling the Settings
   interface.

4. **Libadwaita 1.6+ bug or behaviour change in 1.8.x.** Worth checking the
   exact Nautilus version on the system against known libadwaita regressions.
   Confirmed: nixpkgs ships `libadwaita 1.8.4`, `nautilus 49.4`. There are
   open issues about `AdwStyleManager:system-supports-color-schemes` not
   being detected even when the portal responds (race condition between
   portal init and style manager construction).

## Approaches

### 1. Diagnose first, then patch minimally (RECOMMENDED)

Run a sequence of `gdbus` and `dconf` queries to determine which link in the
chain is broken:

```sh
# 1. Confirm the dconf key is set in the user database
gdbus call --session --dest org.gnome.desktop.interface \
  --object-path / --method org.freedesktop.DBus.Properties.GetAll

# 2. Confirm the portal is running and owns the well-known name
gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
  --method org.freedesktop.DBus.NameHasOwner org.freedesktop.portal.Desktop

# 3. Confirm the Settings interface is present at the right path
gdbus introspect --session --dest org.freedesktop.portal.Desktop \
  --object-path /org/freedesktop/portal/desktop \
  --recurse | grep -A 2 -i settings

# 4. Read the color-scheme through the portal
gdbus call --session --dest org.freedesktop.portal.Desktop \
  --object-path /org/freedesktop/portal/desktop \
  --method org.freedesktop.portal.Settings.Read org.freedesktop.appearance color-scheme

# 5. Check whether xdg-desktop-portal-gtk is actually running
pgrep -af xdg-desktop-portal-gtk
```

Once the broken link is known, apply the corresponding fix (see Approaches 2-4).

- **Pros:** Zero risk of regressing other apps; identifies the actual cause
- **Cons:** Requires user to share the diagnostic output
- **Effort:** 5 minutes for the user to run; minimal for the developer

### 2. Add the dconf key explicitly to t14 (defensive)

In `hosts/t14/home/omarchy.nix`, add the dconf settings that omarchy-nix already
sets, but as `lib.mkForce` to guarantee they are present:

```nix
dconf.settings."org/gnome/desktop/interface".color-scheme = lib.mkForce "prefer-dark";
```

- **Pros:** One-line fix, idempotent, no overlay patch, ensures the portal's
  GTK backend has data to read
- **Cons:** Duplicates omarchy-nix; needs to be kept in sync with the active theme
- **Effort:** Low

### 3. Restart the portal service + remove stale user override

```sh
systemctl --user restart xdg-desktop-portal.service
systemctl --user restart xdg-desktop-portal-gtk.service
rm -f ~/.local/share/xdg-desktop-portal/portals/gtk.portal
```

If the cause is #1 (stale portal), this is sufficient.

- **Pros:** Solves the most common cause with no code change
- **Cons:** Diagnostic only — not declarative
- **Effort:** Low

### 4. Make the portal config explicit in t14 (declarative fix)

Replace the redundant `xdg.portal.extraPortals = [...]` with the same
configuration omarchy-nix provides, but as a `lib.mkForce` so it cannot be
overridden by upstream changes:

```nix
xdg.portal.config.hyprland = {
  default = lib.mkForce [ "hyprland" "gtk" ];
  "org.freedesktop.impl.portal.Settings" = lib.mkForce [ "gtk" ];
};
```

- **Pros:** Declarative, future-proof against omarchy-nix refactors, eliminates
  the race where the wrong impl is selected for Settings
- **Cons:** Duplicates config; could be moved into a shared module if other
  hosts need it
- **Effort:** Low

### 5. NixOS overlay that patches xdg-desktop-portal (NOT recommended)

Add a `pkgs.xdg-desktop-portal.overrideAttrs` to register the Settings bus name
as an alias of the main portal, or add a D-Bus activation hint so that
`gdbus`/`libadwaita` can find `org.freedesktop.portal.Settings`.

- **Pros:** Would solve the issue globally for any consumer
- **Cons:** Upstream explicitly does not want this; diverges from
  flatpak/xdg-desktop-portal design; will be lost on the next upstream change
- **Effort:** High; high risk of breakage on upstream updates

### 6. Patched AdwStyleManager via `GTK_USE_PORTAL=1` (REMOVED in GTK 4.20+)

A previous NixOS option `xdg.portal.gtkUsePortal` set this env var. It was
removed because GTK 4.20+ no longer respects it. Even in 4.20, the
`GDK_DEBUG=portals` flag exists but is documented as a debug knob, not a
production setting. **Do not pursue this.**

- **Pros:** None
- **Cons:** Removed in upstream; userspace hack
- **Effort:** N/A — path is closed

## Recommendation

**Approach 1 first, then Approach 4.** Run the diagnostic block to determine
which link is broken. In 90% of cases the cause is a stale portal service, and
Approach 3 (restart the user service) fixes it. To make the fix durable and
declarative, apply Approach 4: pin the `xdg.portal.config.hyprland` to
`[ "hyprland" "gtk" ]` in `hosts/t14/default.nix` with `lib.mkForce`, and
explicitly force `org.freedesktop.impl.portal.Settings` to use only `"gtk"`.

If the diagnostic shows the dconf key is missing at runtime, apply
Approach 2 (force the dconf setting in t14's HM). This is unlikely if
omarchy-nix's HM module is in the import chain (it is), but it is a cheap
insurance policy.

**Reject Approach 5 (overlay) and Approach 6 (env var) outright** — they are
either upstream-divergent or removed.

## Affected Areas

| File | Why it would change |
|------|---------------------|
| `/home/glats/.nixos/hosts/t14/default.nix` | Replace or extend the `xdg.portal.extraPortals` line with `xdg.portal.config.hyprland` (Approach 4) |
| `/home/glats/.nixos/hosts/t14/home/omarchy.nix` | Optionally add `dconf.settings."org/gnome/desktop/interface".color-scheme = lib.mkForce "prefer-dark"` (Approach 2) |
| `/home/glats/.local/share/xdg-desktop-portal/portals/gtk.portal` | Should be **deleted** (wrong location, deprecated syntax) — user-level action |
| `~/.config/xdg-desktop-portal/hyprland-portals.conf` | Should be added at user level if approach 3 is taken (user-level action) |

**Not affected:**
- `modules/base/dconf.nix` — only sets the MATE compositing-manager key, unrelated
- `modules/base/profiles/base.nix` — system package list, no portal config
- `home-linux/theme.nix` — excluded from t14 by design; omarchy-nix owns the theme
- `flake.nix` — no new inputs needed

## Risks

1. **Portal restart while apps are running** can drop active file-chooser or
   screenshot dialogs. Approach 3 / 4 should be applied at session boundary
   (rebuild + logout/login), not mid-session.

2. **Forcing `org.freedesktop.impl.portal.Settings = [ "gtk" ]`** means only
   GTK-portal responses are served. This is the current behaviour anyway
   (xdg-desktop-portal-hyprland does not implement Settings), so there is no
   regression risk. If xdg-desktop-portal-hyprland ever gains Settings
   support, the override will need to be re-evaluated.

3. **Forcing the dconf key** with `lib.mkForce` will fight the omarchy light-mode
   switch (`~/.config/omarchy/theme/light.mode`). If the user later enables
   light-mode detection, the forced value will override it. Mitigation: do not
   use `lib.mkForce`; use a plain attribute so omarchy's value can still win.

4. **NixOS `xdg.portal.config` and the manual `~/.local/share/.../gtk.portal`
   file interact unpredictably.** The NixOS module writes to
   `/etc/xdg/xdg-desktop-portal/$desktop-portals.conf`, while the user's
   `~/.local/share/xdg-desktop-portal/portals/gtk.portal` is in a completely
   different namespace. Deleting the latter is safe and recommended.

## Open Questions for the User

1. Is Nautilus running as a Flatpak, or as the native package from nixpkgs?
   (Flatpak has its own portal sandbox and a different dconf isolation model.
   If Flatpak, the fix is to grant the Flatpak access to the host dconf
   via `flatpak override --user --filesystem=xdg-config/dconf:ro` or similar.)

2. What is the output of the gdbus/dconf diagnostic block from Approach 1?
   This determines whether Approach 2, 3, or 4 is the right fix.

3. Has the user rebooted / re-logged-in since adding the GTK portal
   configuration? The systemd user service may be running with the old
   config in memory.

## Ready for Proposal

**Yes**, conditional on the diagnostic output. The proposal can be written
defensively: include Approach 4 (declarative portal config) as the primary
fix, Approach 2 (forced dconf) as an optional belt-and-braces, and a one-time
post-rebuild hook to restart the portal user service. If the diagnostic
reveals a Flatpak isolation issue, the proposal will need a different shape
and the orchestrator should be informed.
