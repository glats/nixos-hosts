# Delta Spec: uniform-look-qt-gtk-adwaita-dark

## Domain: gtk-qt-theme

Cross-host GTK and Qt theme configuration for uniform dark look across
all Linux NixOS hosts.

### Context

- **rog**, **thinkcentre** (MATE): Already correct via `home-linux/theme.nix`
  (Materia-dark-compact GTK + Adwaita Dark Qt style + Papirus-Dark icons).
- **t14** (Hyprland/Omarchy): Omarchy-nix sets GTK theme to Adwaita-dark
  at priority 100; Qt defaults to Fusion. These break visual consistency
  with MATE hosts and internal app-to-app uniformity on t14 itself.

This delta introduces host-specific overrides on t14 only. No main spec
exists for this domain yet — all requirements are ADDED.

---

## ADDED Requirements

### R-GTK-T14-1: GTK theme override on t14

**Priority**: High

t14 SHALL override the omarchy-nix default `gtk.theme` so that GTK
applications use Materia-dark-compact (matching rog and thinkcentre).

- `gtk.theme` MUST use `lib.mkForce` to defeat omarchy-nix's priority-100
  definition of Adwaita-dark.
- `gtk.theme.name` MUST be `"Materia-dark-compact"`.
- `gtk.theme.package` MUST be `pkgs.materia-theme`.
- The override MUST be placed in `hosts/t14/home/omarchy.nix`, adjacent
  to the existing `gtk.iconTheme` and `gtk.colorScheme` declarations.

**Scenarios**:

```
Scenario: GTK theme resolves to Materia-dark-compact on t14
  Given the t14 Home Manager configuration at hosts/t14/home/omarchy.nix
  When  the configuration is evaluated by nix flake check --no-build
  Then  gtk.theme.name MUST equal "Materia-dark-compact"
  And   gtk.theme.package MUST equal pkgs.materia-theme
  And   gtk.theme MUST be wrapped with lib.mkForce
```

```
Scenario: MATE hosts are unaffected
  Given the rog and thinkcentre MATE configurations
  When  each is evaluated by nix flake check --no-build
  Then  gtk.theme.name MUST remain "Materia-dark-compact"
  And   no eval errors are produced (no duplicate gtk.theme definitions)
```

---

### R-QT-T14-1: Qt configuration on t14

**Priority**: High

t14 SHALL configure Qt applications to use Adwaita Dark style with GTK3
platform theme bridge, matching the configuration in `home-linux/theme.nix`.

- `qt.enable` MUST be `true`.
- `qt.platformTheme.name` MUST be `"gtk3"`.
- `qt.style.name` MUST be `"adwaita-dark"`.
- The block MUST be placed in `hosts/t14/home/omarchy.nix`, after the
  GTK theme override (R-GTK-T14-1), grouped with related theme config.

**Scenarios**:

```
Scenario: Qt Adwaita Dark style is active on t14
  Given the updated t14 configuration
  When  evaluated by nix flake check --no-build
  Then  qt.enable MUST be true
  And   qt.platformTheme.name MUST be "gtk3"
  And   qt.style.name MUST be "adwaita-dark"
```

```
Scenario: Qt file dialogs match GTK appearance
  Given a t14 system built with this delta
  When  a Qt application (e.g. qt6ct, keepassxc) opens a file dialog
  Then  the dialog SHOULD render with Materia-dark-compact theme
  And   the dialog SHOULD use the same font, decoration, and icon
        theme as GTK applications
```

---

### R-VERIFY-1: Verification of change

**Priority**: Medium

The change SHALL be verifiable through syntactic checks and visual
inspection on t14.

- `nix flake check --no-build` MUST pass for the t14 configuration.
- `nix flake check --no-build` MUST pass for rog and thinkcentre
  configurations (no regressions).
- After deployment, visual checks SHALL confirm:
  1. GTK apps show Materia-dark-compact theme.
  2. Qt apps show Adwaita Dark style.
  3. File dialogs match between GTK and Qt applications.
  4. Icon theme remains Papirus-Dark.

**Scenarios**:

```
Scenario: Flake check passes for all Linux hosts
  Given the modified hosts/t14/home/omarchy.nix
  When  nix flake check --no-build is run
  Then  the t14 configuration MUST produce no errors
  And   the rog configuration MUST produce no errors
  And   the thinkcentre configuration MUST produce no errors
```

```
Scenario: Visual verification on t14
  Given a deployed t14 system with this delta
  When  inspecting running applications
  Then  GTK apps (e.g. nautilus, gedit) MUST show Materia-dark-compact
        theme
  And   Qt apps (e.g. qt6ct, keepassxc) MUST show dark Adwaita style
  And   File dialogs from Qt apps MUST visually match GTK file dialogs
  And   Papirus-Dark icons MUST be present in both toolkits
```

---

### R-ROLLBACK-1: Rollback criteria

**Priority**: Medium

The change SHALL be fully revertible in a single git command with no
state migration or data loss.

- Rollback SHALL restore the previous GTK theme (Adwaita-dark from
  omarchy-nix) and remove the Qt block.
- Rollback SHALL NOT require any manual cleanup beyond switching the
  Home Manager generation.

**Scenarios**:

```
Scenario: Full rollback via git checkout
  Given a deployed t14 system with this delta applied
  When  git checkout -- hosts/t14/home/omarchy.nix is run
  And   nixos-build is run
  Then  gtk.theme MUST revert to omarchy-nix default (Adwaita-dark)
  And   qt.enable MUST revert to its previous value (false/unset)
  And   the rog and thinkcentre configurations MUST be unchanged
```

```
Scenario: Rollback criteria is met
  Given the delta is entirely within hosts/t14/home/omarchy.nix
  Then  rollback MUST consist of reverting only that file
  And   rollback MUST NOT require secret rotation, DB migration,
        or filesystem changes
```

---

### R-EDGE-1: Resilience to omarchy-nix upstream changes

**Priority**: Low

The override SHALL remain effective even if omarchy-nix changes its
default GTK theme in a future version.

- `lib.mkForce` SHALL be used on `gtk.theme` to guarantee the override
  survives priority changes in upstream omarchy-nix.
- This requirement is satisfied by the implementation of R-GTK-T14-1.

**Scenarios**:

```
Scenario: Upstream omarchy-nix changes gtk.theme default
  Given a future version of omarchy-nix that sets gtk.theme to
        a different value than Adwaita-dark
  When  the t14 system is rebuilt
  Then  gtk.theme.name MUST still be "Materia-dark-compact"
  And   `lib.mkForce` guarantees the override in the evaluation graph
```

```
Scenario: Upstream omarchy-nix adds Qt configuration
  Given a future version of omarchy-nix that sets qt.* options
  When  the t14 system is rebuilt
  Then  t14's qt.platformTheme and qt.style MUST NOT conflict
        (Nix merge semantics apply; mkForce may be needed if
        omarchy-nix uses non-default priorities)
```

---

## Requirements Summary

| ID | Area | Priority | Scenario Count |
|---|---|---|---|
| R-GTK-T14-1 | GTK theme override | High | 2 |
| R-QT-T14-1 | Qt configuration | High | 2 |
| R-VERIFY-1 | Verification | Medium | 2 |
| R-ROLLBACK-1 | Rollback | Medium | 2 |
| R-EDGE-1 | Upstream resilience | Low | 2 |
| **Total** | | | **10** |

## Coverage

- **C-QT-1** (Qt Adwaita Dark style): R-QT-T14-1
- **C-QT-2** (Qt GTK3 file dialogs): R-QT-T14-1, Scenario 2
- **C-GTK-1** (Materia-dark-compact on t14): R-GTK-T14-1
- **C-GTK-2** (Papirus-Dark unchanged): R-VERIFY-1, Scenario 2
- **C-CONSISTENCY-1** (All hosts uniform): R-GTK-T14-1 + R-QT-T14-1 + implicit
