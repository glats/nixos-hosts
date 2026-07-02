# Design: thinkfan-ui Packaging for NixOS

## Technical Approach

Package thinkfan-ui as a local Nix derivation following the `asus-fan-control` pattern: `stdenv.mkDerivation` + `makeWrapper` + `wrapQtAppsHook`. The derivation copies the Python source to `$out/share/thinkfan-ui/`, wraps `main.py` with a launcher that sets PYTHONPATH and PATH for runtime dependencies (PyQt6, lm-sensors), and registers it in the overlay + package registry. Host wiring adds the kernel module parameter on t14 system config and the package to home-manager.

## Architecture Decisions

### Decision: Derivation Strategy

**Choice**: `stdenv.mkDerivation` with manual Python wrapping (not `buildPythonApplication`)

**Alternatives considered**: 
- `python3.pkgs.buildPythonApplication` — rejected because thinkfan-ui has no `setup.py`/`pyproject.toml` and is a simple script collection
- `python3.pkgs.buildPythonApplication` with manual `format = "other"` — rejected because it adds complexity without benefit for a non-standard Python project

**Rationale**: Matches the `asus-fan-control` precedent in this repo. The upstream repo is a plain Python script collection (no build system), so manual wrapping is simpler and more transparent. `wrapQtAppsHook` handles Qt plugin discovery automatically.

### Decision: Source Fetching

**Choice**: Flake input `thinkfan-ui-src` with `flake = false`

**Alternatives considered**:
- `fetchFromGitHub` inside the derivation — rejected because it duplicates the flake input pattern used by `asus-fan-control` and `opencode`
- Pinned commit vs. branch tracking — chose branch tracking (`master`) to follow upstream updates; user can pin via `flake.lock` if needed

**Rationale**: Consistent with repo convention. Flake inputs are the canonical way to fetch external sources in this repo (see `asus-fan-control-src`, `pipewire-module-xrdp-src`).

### Decision: Qt Wrapper Strategy

**Choice**: `wrapQtAppsHook` in `nativeBuildInputs` + manual `makeWrapper` for the entry point

**Alternatives considered**:
- Only `wrapQtAppsHook` — rejected because it wraps binaries in `$out/bin/` automatically, but thinkfan-ui needs a custom wrapper that sets PYTHONPATH and PATH for `sensors`
- Only `makeWrapper` — rejected because it doesn't set Qt plugin paths (QT_PLUGIN_PATH, QML2_IMPORT_PATH), which breaks PyQt6 on NixOS

**Rationale**: `wrapQtAppsHook` is the standard nixpkgs pattern for Qt apps. We use it to get Qt plugin paths, then manually wrap the Python entry point to add PYTHONPATH (for PyQt6) and PATH (for `sensors`).

### Decision: Kernel Module Parameter Location

**Choice**: `boot.extraModprobeConfig` in `hosts/t14/default.nix` (system config)

**Alternatives considered**:
- `/etc/modprobe.d/thinkpad_acpi.conf` via `environment.etc` — rejected because `boot.extraModprobeConfig` is the canonical NixOS way and integrates with bootloader
- Home-manager `home.file` — rejected because kernel module params must be set at boot time, not per-user

**Rationale**: `boot.extraModprobeConfig` is the NixOS-idiomatic way to set kernel module parameters. It writes to `/etc/modprobe.d/` and is managed by the system configuration.

### Decision: Package Installation Location

**Choice**: `home.packages` in `hosts/t14/home/omarchy.nix` (home-manager)

**Alternatives considered**:
- `environment.systemPackages` in `hosts/t14/default.nix` — rejected because thinkfan-ui is a user-facing GUI app, not a system service
- Both system + home — rejected because it duplicates the package in the closure

**Rationale**: thinkfan-ui is a desktop GUI app launched by the user. Home-manager `home.packages` is the correct location for user-facing applications (matches the repo's pattern for desktop apps).

### Decision: Desktop File + Icon in Derivation

**Choice**: Install upstream's `linux_packaging/thinkfan-ui.desktop` and `linux_packaging/thinkfan-ui.svg` from the source tree into `$out/share/applications/` and `$out/share/icons/hicolor/scalable/apps/`

**Alternatives considered**:
- Write a custom `.desktop` file in the derivation — rejected because upstream already provides one that is kept in sync with the app
- Use `images/thinkfan-icon.png` instead of SVG — rejected because SVG scales correctly at any panel size and is the standard for `hicolor/scalable/`
- Skip the desktop file entirely — rejected because without it, the app is invisible to rofi/wofi and XDG autostart

**Rationale**: The upstream repo provides `linux_packaging/thinkfan-ui.desktop` (referencing `Icon=thinkfan-ui`) and `linux_packaging/thinkfan-ui.svg`. Installing both means the app appears in app launchers (rofi/wofi) and the icon resolves via standard Freedesktop icon theme lookup. This follows the same pattern as `asus-fan-control` and other nixpkgs Qt app derivations.

### Decision: Autostart Mechanism

**Choice**: Home Manager `xdg.configFile."autostart/thinkfan-ui.desktop"` in `hosts/t14/home/omarchy.nix`

**Alternatives considered**:
- Hyprland `exec-once = thinkfan-ui` — rejected because it has no tray dependency ordering, no XDG spec compliance, and won't survive compositor restarts cleanly
- Waybar tray module + exec-once — rejected because it couples autostart to waybar config and adds complexity
- System-level `services.xserver.desktopManager` — rejected because thinkfan-ui is a user app, not a system service

**Rationale**: `xdg.configFile."autostart/..."` is the established pattern in this repo (used by `mate.nix` for copyq/flameshot, `conky-*.nix` for conky, `mate-rog-autostart.nix` for hexchat). It follows the XDG Autostart spec, works with any compositor, and Hyprland respects it via `xdg-autostart-enable` (enabled by default in Hyprland). thinkfan-ui defaults to tray mode (the `--no-tray` flag disables it), so it will sit in the waybar tray after autostart.

## Data Flow

```
Flake Input (thinkfan-ui-src)
    ↓
Derivation (pkgs/thinkfan-ui/default.nix)
    ↓ [stdenv.mkDerivation]
    ↓ [unpackPhase: copy source]
    ↓ [installPhase:]
    ↓   ├─ copy src/* → $out/share/thinkfan-ui/
    ↓   ├─ copy linux_packaging/thinkfan-ui.svg → $out/share/icons/hicolor/scalable/apps/
    ↓   ├─ install .desktop → $out/share/applications/thinkfan-ui.desktop
    ↓   └─ wrapProgram: set PYTHONPATH, QT_QPA_PLATFORM, PATH
    ↓
Overlay (overlays/linux.nix)
    ↓ [final.callPackage]
    ↓
Package Registry (lib/packages.nix)
    ↓ [linuxPackages.thinkfan-ui]
    ↓
Flake Outputs (flake.nix)
    ↓ [packages.x86_64-linux.thinkfan-ui]
    ↓
Host Wiring (hosts/t14/)
    ├─ default.nix: boot.extraModprobeConfig "options thinkpad_acpi fan_control=1"
    └─ home/omarchy.nix:
         ├─ home.packages = [ pkgs.thinkfan-ui ]
         └─ xdg.configFile."autostart/thinkfan-ui.desktop" (XDG autostart → tray on login)
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `flake.nix` | Modify | Add `thinkfan-ui-src` input (GitHub URL, flake=false) |
| `pkgs/thinkfan-ui/default.nix` | Create | Derivation: copy source, install .desktop + SVG icon from `linux_packaging/`, wrap with PyQt6 + lm-sensors + Qt plugins |
| `overlays/linux.nix` | Modify | Add `thinkfan-ui = final.callPackage ../pkgs/thinkfan-ui { thinkfan-ui-src = inputs.thinkfan-ui-src; }` |
| `lib/packages.nix` | Modify | Add `thinkfan-ui = linuxPkgs.callPackage ../pkgs/thinkfan-ui { thinkfan-ui-src = inputs.thinkfan-ui-src; }` to `linuxPackages` |
| `hosts/t14/default.nix` | Modify | Add `boot.extraModprobeConfig = "options thinkpad_acpi fan_control=1";` |
| `hosts/t14/home/omarchy.nix` | Modify | Add `pkgs.thinkfan-ui` to `home.packages` + `xdg.configFile."autostart/thinkfan-ui.desktop"` for tray autostart |

## Interfaces / Contracts

### Derivation Interface

```nix
{ lib
, stdenv
, makeWrapper
, wrapQtAppsHook
, python3
, python3.pkgs.pyqt6
, lm-sensors
, thinkfan-ui-src
}:

stdenv.mkDerivation {
  pname = "thinkfan-ui";
  version = thinkfan-ui-src.rev or "unstable";
  src = thinkfan-ui-src;
  
  nativeBuildInputs = [ makeWrapper wrapQtAppsHook ];
  
  dontBuild = true;
  
  installPhase = ''
    # Copy source to $out/share/thinkfan-ui/
    mkdir -p $out/share/thinkfan-ui
    cp -r src/* $out/share/thinkfan-ui/
    
    # Install desktop file from upstream linux_packaging/
    mkdir -p $out/share/applications
    install -Dm644 linux_packaging/thinkfan-ui.desktop $out/share/applications/thinkfan-ui.desktop
    
    # Install SVG icon from upstream linux_packaging/ (Freedesktop hicolor theme)
    mkdir -p $out/share/icons/hicolor/scalable/apps
    install -Dm644 linux_packaging/thinkfan-ui.svg $out/share/icons/hicolor/scalable/apps/thinkfan-ui.svg
    
    # Create bin directory
    mkdir -p $out/bin
    
    # Wrap main.py with runtime dependencies
    makeWrapper ${python3}/bin/python3 $out/bin/thinkfan-ui \
      --set PYTHONPATH $out/share/thinkfan-ui:${python3.pkgs.pyqt6}/${python3.sitePackages} \
      --set QT_QPA_PLATFORM "wayland;xcb" \
      --prefix PATH : ${lib.makeBinPath [ lm-sensors ]} \
      --add-flags "$out/share/thinkfan-ui/main.py"
  '';
  
  meta = {
    description = "PyQt6 GUI for ThinkPad fan control";
    homepage = "https://github.com/zocker-160/thinkfan-ui";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "thinkfan-ui";
  };
}
```

### Flake Input Contract

```nix
# In flake.nix inputs:
thinkfan-ui-src = {
  url = "github:zocker-160/thinkfan-ui";
  flake = false;
};
```

### Host Wiring Contract

```nix
# In hosts/t14/default.nix:
boot.extraModprobeConfig = "options thinkpad_acpi fan_control=1";

# In hosts/t14/home/omarchy.nix:
home.packages = with pkgs; [
  # ... existing packages ...
  thinkfan-ui
];

# XDG autostart — launches thinkfan-ui on login, tray icon in waybar
xdg.configFile."autostart/thinkfan-ui.desktop".text = ''
  [Desktop Entry]
  Name=ThinkFan UI
  Comment=ThinkPad Fan Control GUI
  Exec=thinkfan-ui
  Icon=thinkfan-ui
  Terminal=false
  Type=Application
  Categories=System;Monitor;
  X-GNOME-Autostart-enabled=true
'';
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Build | Derivation builds successfully | `nix build .#packages.x86_64-linux.thinkfan-ui` |
| Build | Desktop file installed | `result/share/applications/thinkfan-ui.desktop` exists after build |
| Build | SVG icon installed | `result/share/icons/hicolor/scalable/apps/thinkfan-ui.svg` exists after build |
| Runtime | App launches on t14 Hyprland | Run `thinkfan-ui` in terminal, verify GUI appears |
| Runtime | App visible in rofi/wofi | Open launcher, type "thinkfan", verify entry appears with icon |
| Runtime | Autostart places tray icon | Logout → login, verify thinkfan-ui tray icon in waybar |
| Integration | `sensors` output visible | Check CPU temp reading in GUI |
| Integration | Fan control works | Set fan speed manually, verify `/proc/acpi/ibm/fan` changes |
| Validation | Flake check passes | `nix flake check --no-build` |
| Regression | Existing packages still build | `nix build .#packages.x86_64-linux.opencode` (spot check) |

## Migration / Rollout

No migration required. This is a new package addition with no breaking changes.

Rollout steps:
1. Add flake input + derivation + overlay + package registry (atomic commit)
2. Add host wiring (kernel param + home.packages) in separate commit
3. Run `nixos-build` on t14 to apply changes
4. Verify `thinkfan-ui` launches and can read temps
5. Test fan control (requires root or polkit rules — out of scope for initial packaging)

## Open Questions

- [ ] Does thinkfan-ui require polkit rules for passwordless fan control? (Out of scope for initial packaging, but may need follow-up)
- [ ] Should we pin the flake input to a specific commit for reproducibility? (Current design tracks `master` branch)
- [ ] Does Hyprland's built-in `xdg-autostart-enable` need explicit activation, or is it on by default? (It should be on by default — verify on t14)
