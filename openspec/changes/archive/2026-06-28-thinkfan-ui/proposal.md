# Proposal: thinkfan-ui Packaging for NixOS

## Intent

Package [thinkfan-ui](https://github.com/zocker-160/thinkfan-ui) (AUR: `thinkfan-gui`) as a local Nix derivation so the user can control fan speed on the ThinkPad T14 AMD Gen 4 via a GUI. thinkfan-ui writes directly to `/proc/acpi/ibm/fan` — it is NOT a wrapper around the thinkfan daemon and the two are mutually exclusive. No `pkgs.thinkfan-ui` exists in nixpkgs today.

## Scope

### In Scope
- Local derivation in `pkgs/thinkfan-ui/default.nix` (Python + PyQt6, wrapped with `makeWrapper`)
- Flake input `thinkfan-ui-src` pointing at upstream GitHub
- Overlay registration in `overlays/linux.nix`
- Package registration in `lib/packages.nix`
- Kernel module parameter `options thinkpad_acpi fan_control=1` on t14 host
- Expose `pkgs.thinkfan-ui` in t14 home.packages via `hosts/t14/home/omarchy.nix`

### Out of Scope
- Alternative tool `thinkpad-fan-control` (different project)
- Enabling `services.thinkfan` (mutually exclusive with thinkfan-ui)
- NixOS service module (thinkfan-ui is a desktop GUI, not a daemon)
- Hosts other than t14 (rog is ASUS, thinkcentre has no thinkpad_acpi)
- Polkit rules for passwordless fan control (out of scope for initial packaging)

## Capabilities

### New Capabilities
- `thinkfan-ui-packaging`: Local Nix derivation wrapping the upstream PyQt6 GUI with proper runtime dependencies (PyQt6, lm-sensors, polkit)

### Modified Capabilities
None

## Approach

Follow the `asus-fan-control` precedent already established in this repo:

1. **Flake input**: Add `thinkfan-ui-src` (flake=false, GitHub URL) in `flake.nix`
2. **Derivation**: `pkgs/thinkfan-ui/default.nix` using `python3.pkgs.buildPythonApplication` or `stdenv.mkDerivation` + `makeWrapper`. Wrap with PyQt6, lm-sensors (`sensors` binary), and polkit in PATH. Use `wrapQtAppsHook` for Qt plugin discovery
3. **Overlay**: Register in `overlays/linux.nix` alongside `asus-fan-control`
4. **Package registry**: Add to `lib/packages.nix` `linuxPackages`
5. **Kernel param**: Add `boot.extraModprobeConfig = "options thinkpad_acpi fan_control=1";` in `hosts/t14/default.nix`
6. **Home packages**: Add `pkgs.thinkfan-ui` to `home.packages` in `hosts/t14/home/omarchy.nix`

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `flake.nix` | Modified | Add `thinkfan-ui-src` input |
| `pkgs/thinkfan-ui/default.nix` | New | Derivation (~60-80 lines) |
| `overlays/linux.nix` | Modified | Add `thinkfan-ui` to overlay |
| `lib/packages.nix` | Modified | Register in `linuxPackages` |
| `hosts/t14/default.nix` | Modified | Add `boot.extraModprobeConfig` for thinkpad_acpi |
| `hosts/t14/home/omarchy.nix` | Modified | Add to `home.packages` |

## Dependencies

- `python3` + `python3.pkgs.pyqt6` — GUI framework
- `lm-sensors` — provides `sensors` binary for CPU temp reading
- `polkit` — runtime dependency for privilege escalation when writing to `/proc/acpi/ibm/fan`
- `wrapQtAppsHook` — Qt plugin path resolution at build time
- `makeWrapper` — PATH construction for runtime deps

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Wayland/X11 tray icon issues | Medium | App supports `--no-tray` flag; test on Hyprland |
| `thinkpad_acpi` module not loading fan_control | Low | T14 AMD Gen 4 uses `thinkpad_acpi`; verify at runtime with `cat /proc/acpi/ibm/fan` |
| Upstream repo unmaintained | Low | Last commit 2024; AUR package active; PyQt6 rewrite is current |
| PyQt6 wrapper misses Qt plugins | Medium | Use `wrapQtAppsHook` (standard nixpkgs pattern for Qt apps) |

## Rollback Plan

1. Remove `thinkfan-ui-src` input from `flake.nix`
2. Delete `pkgs/thinkfan-ui/` directory
3. Remove overlay entry, package registration, and t14 host references
4. Remove `boot.extraModprobeConfig` line from t14 (or comment it out)
5. Run `nixos-build` — system reverts to previous state with no fan control GUI

Single commit revert via `git revert`.

## Success Criteria

- [ ] `nix build .#packages.x86_64-linux.thinkfan-ui` succeeds
- [ ] `thinkfan-ui` launches on t14 Hyprland session without errors
- [ ] `sensors` output visible in GUI (CPU temp reading works)
- [ ] Fan speed can be set manually via GUI (writes to `/proc/acpi/ibm/fan`)
- [ ] `nix flake check --no-build` passes

## Review Workload

- **Estimated lines**: ~250-350 (6 files, single derivation + wiring)
- **400-line budget risk**: Low — well within budget
- **Chained PRs recommended**: No — single cohesive change
- **Decision needed before apply**: No
