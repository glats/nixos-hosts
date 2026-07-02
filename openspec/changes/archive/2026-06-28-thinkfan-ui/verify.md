# Verification: thinkfan-ui Packaging for NixOS

## Status: PASSED ✅

All build, evaluation, and integration checks have passed.

## Build Verification

| Check | Result | Evidence |
|-------|--------|----------|
| `nix build .#packages.x86_64-linux.thinkfan-ui` | ✅ PASS | Successful build; `result/bin/thinkfan-ui` is a `makeWrapper` script |
| `nix flake check --no-build` | ✅ PASS | No evaluation errors across all hosts (rog, thinkcentre, t14, mact2) |
| `nix build .#nixosConfigurations.t14.config.system.build.toplevel` | ✅ PASS | t14 system closure builds successfully |
| `result/share/applications/thinkfan-ui.desktop` | ✅ PASS | Desktop file installed from upstream `linux_packaging/` |
| `result/share/icons/hicolor/scalable/apps/thinkfan-ui.svg` | ✅ PASS | SVG icon installed from upstream `linux_packaging/` |

## Git History (8 commits on master, pushed)

| Commit | Purpose |
|--------|---------|
| `3bc3c4b` | **feat(pkgs): add thinkfan-ui package** — initial derivation + flake input + overlay + package registry |
| `b863e9e` | **fix(t14): enable pkexec setuid wrapper** — `security.wrappers.pkexec` for fan write permissions |
| `ed02b74` | **fix(t14): start thinkfan-ui --hide** — XDG autostart uses `--hide` for tray-only startup |
| `1239682` | **fix(thinkfan-ui): add hicolor-icon-theme** — tray icon resolution |
| `80392ba` | **fix(thinkfan-ui): copy hicolor index.theme** — QIcon.fromTheme workaround |
| `ba20e51` | **fix(thinkfan-ui): gtk-update-icon-cache** — icon cache regeneration |
| `f1b2100` | **fix(thinkfan-ui): bypass QIcon.fromTheme** — direct SVG path via `QIcon(path)` |
| `c3bf76c` | **fix(thinkfan-ui): add qtsvg to buildInputs** — SVG plugin in `QT_PLUGIN_PATH` |

## Final Implementation State

| File | Status | Description |
|------|--------|-------------|
| `flake.nix` | ✅ | `thinkfan-ui-src` input (github:zocker-160/thinkfan-ui, flake=false) |
| `pkgs/thinkfan-ui/default.nix` | ✅ NEW | `stdenv.mkDerivation` + `makeWrapper` + `wrapQtAppsHook`; `QIcon(path)` with SVG; `qtsvg` in buildInputs; desktop file + SVG icon from `linux_packaging/` |
| `overlays/linux.nix` | ✅ | `thinkfan-ui = final.callPackage ...` registration |
| `lib/packages.nix` | ✅ | `thinkfan-ui` in `linuxPackages` |
| `hosts/t14/default.nix` | ✅ | `boot.extraModprobeConfig = "options thinkpad_acpi fan_control=1"` + `security.wrappers.pkexec.enable = true` |
| `hosts/t14/home/omarchy.nix` | ✅ | `home.packages` + `xdg.configFile."autostart/thinkfan-ui.desktop"` with `--hide` for tray autostart |

## Key Discoveries Verified

1. **QIcon.fromTheme() is fragile on NixOS** — icon themes across multiple store paths don't merge. Fixed by using `QIcon(path_to_svg)` directly + adding `qtsvg` to `buildInputs`.
2. **qtsvg in buildInputs** — `wrapQtAppsHook` adds the SVG plugin to `QT_PLUGIN_PATH` only when `qtsvg` is in `buildInputs`.
3. **security.wrappers.pkexec defaults to enable=false** — must explicitly set `enable = true` even when polkit is enabled.
4. **thinkfan-ui --hide flag** — undocumented CLI flag for tray-only startup, used in XDG autostart.
5. **Wayland tray works** — via StatusNotifierItem + waybar tray module.

## Cleanup / Deletions

- `sdd/explore/thinkfan-gui.md` — moved to archive
- `sdd/propose/thinkfan-ui.md` — moved to archive
- `sdd/spec/thinkfan-ui.md` — moved to archive
- `sdd/designs/thinkfan-ui.md` — moved to archive
- `sdd/tasks/thinkfan-ui.md` — moved to archive
