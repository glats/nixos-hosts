# Specification: nautilus-dark-mode-t14

## Purpose

Ensure Nautilus and GTK4/libadwaita apps render dark on t14 (Hyprland) by guaranteeing xdg-desktop-portal exports the Settings interface with a working GTK backend.

## Functional Requirements

### FR1: Portal Settings Interface Present

After rebuild + re-login, `org.freedesktop.portal.Settings` MUST exist on `/org/freedesktop/portal/desktop` via bus `org.freedesktop.portal.Desktop`.

#### Scenario: Interface introspection
- GIVEN the fix is applied and user has re-logged
- WHEN introspecting bus `org.freedesktop.portal.Desktop` at path `/org/freedesktop/portal/desktop`
- THEN the `org.freedesktop.portal.Settings` interface MUST be listed

### FR2: Portal Returns Dark Preference

`Settings.ReadAll` MUST return `color-scheme = uint32 1` for namespace `org.freedesktop.appearance`.

#### Scenario: ReadAll confirms dark
- GIVEN the fix is applied and user has re-logged
- WHEN calling `dbus-send ... org.freedesktop.portal.Settings.ReadAll array:string:"org.freedesktop.appearance"`
- THEN response MUST include `uint32 1` for `color-scheme`

### FR3: Nautilus Renders Dark

Nautilus MUST render in dark mode when launched.

#### Scenario: Dark Nautilus window
- GIVEN the portal returns `color-scheme = prefer-dark`
- WHEN Nautilus launches
- THEN the window MUST use dark-themed colors (dark titlebar, sidebar, content)

### FR4: Portal Config Pins Settings to GTK

`/etc/xdg/xdg-desktop-portal/hyprland-portals.conf` MUST include `org.freedesktop.impl.portal.Settings=gtk`.

#### Scenario: Config file verification
- GIVEN the system has been rebuilt
- WHEN reading the config file
- THEN it MUST contain `org.freedesktop.impl.portal.Settings=gtk` under the Hyprland section

## Non-Functional Requirements

### NFR1: No Regression for Other GTK4 Apps

Other GTK4/libadwaita apps MUST also get dark mode and MUST NOT lose functionality.

#### Scenario: All apps follow color-scheme
- GIVEN portal returns dark preference
- WHEN another GTK4/libadwaita app launches
- THEN it MUST render dark

### NFR2: No Regression for Other Portal Features

FileChooser, ScreenCast, InputCapture, and other portal features MUST continue working.

#### Scenario: Non-Settings features unaffected
- GIVEN only `Settings` is pinned to GTK
- WHEN a Hyprland portal feature is requested
- THEN it MUST be handled by the Hyprland backend

### NFR3: Fix Survives Rebuilds

Config MUST persist across `nixos-rebuild` and not be overwritten by omarchy-nix updates.

#### Scenario: mkForce preserves override
- GIVEN `lib.mkForce` is used for `Settings=gtk`
- WHEN omarchy-nix updates and system rebuilds
- THEN `Settings=gtk` MUST remain in the config

## Edge Cases

### Light Mode Switching
- GIVEN Settings interface works with `Settings=gtk`
- WHEN dconf changes to `"prefer-light"`
- THEN `ReadAll` returns `uint32 2`
- AND Nautilus renders light

### Rollback
- GIVEN the fix is removed and system rebuilt
- WHEN querying the portal
- THEN the Settings interface MUST be absent (acceptable regression to prior state)
