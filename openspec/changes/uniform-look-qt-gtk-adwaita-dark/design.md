# SDD Design: uniform-look-qt-gtk-adwaita-dark

## 1. Architecture Overview

### Home Manager Module Merge Priority

Home Manager uses Nix's module system where each option definition carries a
**priority** (lower = stronger). The default priority is 100 (the `lib.mkDefault`
level). When two modules define the same option at the same priority, Nix raises a
**duplicate option definition** error.

The merge graph for `gtk.theme` on t14:

```
Module                                  Priority    gtk.theme value
──────────────────────────────────────  ──────────  ──────────────────────────
omarchy-nix HM default.nix              default(100) { name = "Adwaita-dark";
                                                       package = pkgs.gnome-themes-extra; }
hosts/t14/home/omarchy.nix              default(100) { name = "Materia-dark-compact";
  (without mkForce)                                   package = pkgs.materia-theme; }
  → ERROR: duplicate option definition
──────────────────────────────────────  ──────────  ──────────────────────────
hosts/t14/home/omarchy.nix              mkForce(1000) { name = "Materia-dark-compact";
  (with mkForce)                                      package = pkgs.materia-theme; }
  → RESOLVED: priority 1000 wins
```

`lib.mkForce` elevates the definition to priority **1000** (highest in the Nix
priority spectrum), which defeats omarchy-nix's default-priority (100) definition
without errors.

The Qt block (`qt.*`) has **no conflict** because omarchy-nix does not define any
Qt options. A plain (non-mkForce) definition at priority 100 works fine.

### Key Architecture Decision: mkForce on whole `gtk.theme`

| Approach | Verdict | Rationale |
|----------|---------|-----------|
| mkForce on `gtk.theme` (entire attrset) | **SELECTED** | Matches existing pattern in this file (all 9+ mkForce usages). Wraps both `name` and `package` in one declaration. |
| mkForce on `gtk.theme.name` + `gtk.theme.package` individually | Rejected | Unnecessary verbosity; omarchy-nix defines both together so mkForce on each yields same result. |
| mkDefault on `gtk.theme` | Rejected | mkDefault (priority 100) would still conflict — same priority as omarchy-nix's definition. |

---

## 2. Data Flow

### GTK Theme Resolution

```
  omarchy-nix HM module          hosts/t14/home/omarchy.nix
  ┌──────────────────────┐       ┌──────────────────────────────┐
  │ gtk.theme = {        │       │ gtk.theme = lib.mkForce {    │
  │   name = "Adwaita-   │       │   name = "Materia-dark-      │
  │   dark";             │       │   compact";                  │
  │   package = pkgs.    │       │   package = pkgs.materia-    │
  │   gnome-themes-extra │       │   theme;                     │
  │ }     (priority 100) │       │ }   (priority 1000 → WINS)   │
  └──────────────────────┘       └──────────────────────────────┘
         │                                    │
         └──────────── HM Module Merge ───────┘
                              │
                              ▼
              gtk.theme = { name = "Materia-dark-compact";
                            package = pkgs.materia-theme; }
                              │
                    ┌─────────┴─────────┐
                    ▼                   ▼
            GTK3 settings.ini    GTK4 settings.ini
            gtk-theme-name=      gtk-theme-name=
            Materia-dark-compact Materia-dark-compact
```

### Qt Configuration

```
  hosts/t14/home/omarchy.nix
  ┌───────────────────────────────┐
  │ qt = {                        │
  │   enable = true;              │
  │   platformTheme.name = "gtk3";│
  │   style.name = "adwaita-dark";│
  │ }                             │
  └───────────────────────────────┘
            │
            ▼
  HM activation writes:
    • QT_STYLE_OVERRIDE=adwaita-dark        (env var)
    • QT_QPA_PLATFORMTHEME=gtk3              (env var)
    • ~/.config/Trolltech.conf (style=gtk3)  (Qt5 fallback)
    • ~/.config/qt{5,6}ct/...                (if qtct installed)
            │
            ▼
  Qt application picks up env vars →
  Uses GTK3 bridge for platform theme →
  File dialogs render with Materia-dark-compact (via GTK3)
```

**Key insight**: The GTK3 platform theme bridge means Qt file dialogs use
the GTK theme (Materia-dark-compact) for visual rendering, while Qt widgets
(main window chrome, menus, buttons) use Adwaita Dark style. The combination
produces a visually coherent dark look because both themes share dark
palette characteristics.

---

## 3. Component Details

### 3.1 Exact Nix Expressions to Add

Insert after the existing `gtk.gtk4.extraConfig` block (line ~200 in
`hosts/t14/home/omarchy.nix`), grouped with the existing GTK config:

```nix
  # Override omarchy-nix's default GTK theme (Adwaita-dark) to Materia-dark-compact
  # to match rog and thinkcentre. lib.mkForce defeats omarchy's priority-100
  # definition. materia-theme is auto-installed by HM via gtk.theme.package.
  gtk.theme = lib.mkForce {
    name = "Materia-dark-compact";
    package = pkgs.materia-theme;
  };

  # Qt configuration: Adwaita Dark style with GTK3 platform theme bridge.
  # Matches home-linux/theme.nix used on rog and thinkcentre.
  # adwaita-qt is auto-installed by HM when qt.style.name = "adwaita-dark".
  qt = {
    enable = true;
    platformTheme.name = "gtk3";
    style.name = "adwaita-dark";
  };
```

### 3.2 Placement in File

These blocks go after the `gtk.gtk4.extraConfig` line (200) and before the
`thinkfan-ui` home.packages block (line ~206). The rationale:

- **GTK grouping**: All `gtk.*` overrides (iconTheme, colorScheme, gtk4.extraConfig,
  theme) stay adjacent for readability.
- **Qt adjacency**: Qt block follows GTK block, matching `home-linux/theme.nix`
  structure.
- **No ordering constraints**: HM module merge is order-independent for the
  same priority level, so physical placement does not affect evaluation.

### 3.3 Existing Pattern Alignment

This file already uses `lib.mkForce` extensively:

| Line | What | Reason |
|------|------|--------|
| 100 | `programs.zsh.zplug.enable` | Defeat omarchy zplug |
| 101 | `programs.starship.enable` | Defeat omarchy starship |
| 103 | `fonts.fontconfig.enable` | Defeat omarchy fontconfig |
| 110-113 | `omarchy.fonts.*` | Override omarchy font selections |
| 125 | `omarchy.rotate_on_start` | Override wallpaper rotation |
| 136 | `omarchy.fcitx5.enable` | Override fcitx5 enablement |
| 143 | `systemd.user.services.fcitx5.Service.ExecStart` | Override fcitx5 args |
| 158 | `services.hypridle.settings` | Override idle timings |
| 242 | `home.activation.copyScreensaverTxt` | Override activation order |

The new `gtk.theme` mkForce is consistent with all these existing patterns.

---

## 4. Dependencies

### 4.1 Package Resolution

| Package | How it arrives | on t14 |
|---------|---------------|--------|
| `materia-theme` | Auto-installed by HM via `gtk.theme.package` | NEW (was absent; t14 uses `gnome` suite, not `mate`) |
| `adwaita-qt` | Auto-installed by HM via `qt.style.name = "adwaita-dark"` | NEW (HM qt module adds it to `home.packages`) |

Neither package needs explicit addition to `environment.systemPackages` or
`home.packages` — Home Manager's module system handles installation
automatically when `gtk.theme.package` and `qt.style.name` are set.

### 4.2 Impact Analysis

| Host | Current State | After Change | Impact |
|------|--------------|--------------|--------|
| t14 | GTK: Adwaita-dark (omarchy) | GTK: Materia-dark-compact | Confirmed change |
| t14 | Qt: Fusion (default, unconfigured) | Qt: Adwaita Dark + GTK3 bridge | Confirmed change |
| rog | GTK: Materia-dark-compact (theme.nix) | Unchanged | Zero |
| thinkcentre | GTK: Materia-dark-compact (theme.nix) | Unchanged | Zero |
| mact2 (macOS) | No Qt/GTK HM config | Unchanged | Zero |

### 4.3 No Additional Dependencies

The change does NOT require:
- New flake inputs (materia-theme and adwaita-qt are in nixpkgs)
- New sops secrets
- New NixOS modules
- New files or directories

---

## 5. Interfaces

### 5.1 Nix Evaluation Contract

The change introduces two option definitions:

```
gtk.theme = lib.mkForce { ... }    — overrides omarchy-nix default
qt = { ... }                       — new definitions, no prior value
```

No new NixOS or HM options are created. All options are existing HM options:
- `gtk.theme` (type: `nullOr (submodule { name, package })`)
- `qt.enable` (type: `boolean`)
- `qt.platformTheme.name` (type: `enum [ "gtk2" "gtk3" "qtct" ]`)
- `qt.style.name` (type: `nullOr str`)

### 5.2 Activation Contract

On `nixos-build` (which runs `home-manager switch` under the hood):

1. HM writes `~/.config/gtk-3.0/settings.ini` with `gtk-theme-name=Materia-dark-compact`
2. HM writes `~/.config/gtk-4.0/settings.ini` with `gtk-theme-name=Materia-dark-compact`
3. HM sets environment variables: `QT_STYLE_OVERRIDE=adwaita-dark`,
   `QT_QPA_PLATFORMTHEME=gtk3`
4. `materia-theme` and `adwaita-qt` packages are linked into the HM profile
5. Running applications need restart to pick up new theme/style

---

## 6. Testing Strategy

### 6.1 Pre-deployment Verification

| Check | Command | Expected |
|-------|---------|----------|
| Flake check | `nix flake check --no-build` | All hosts pass |
| t14 eval | `nix build .#homeConfigurations.glats@t14.activationPackage --no-link` | No errors |
| rog eval | `nix build .#homeConfigurations.glats@rog.activationPackage --no-link` | No errors (regression guard) |
| thinkcentre eval | `nix build .#homeConfigurations.glats@thinkcentre.activationPackage --no-link` | No errors (regression guard) |

### 6.2 Post-deployment Visual Verification

| App | Toolkit | Expected Look | Command |
|-----|---------|---------------|---------|
| Nautilus | GTK4/libadwaita | Dark, Materia-dark-compact theme | `nautilus -w` |
| GTK3 app (e.g. gedit) | GTK3 | Dark, Materia-dark-compact theme | `gtk3-widget-factory` |
| Qt6 settings | Qt6 | Dark Adwaita style, GTK3 file dialogs | `qt6ct` |
| Qt5 settings | Qt5 | Dark Adwaita style, GTK3 file dialogs | `qt5ct` |

### 6.3 Verification via nix-instantiate (optional)

To verify the gtk.theme value without building:

```bash
nix-instantiate --eval --strict -E \
  'let hm = import <home-manager> { }; ...' \
  # OR use nix eval on the flake:
  nix eval .#homeConfigurations.glats@t14.config.gtk.theme.name
```

---

## 7. Migration

No migration needed. This is a pure config change:

- No state to migrate
- No database to update
- No files to rename
- No secrets to rotate

Running applications need to be restarted to pick up the new theme/style.
This is expected and acceptable.

---

## 8. Rollback Strategy

### Primary: git revert

```bash
git checkout -- hosts/t14/home/omarchy.nix
nixos-build
```

This restores the file to its pre-change state. The next `home-manager switch`
reverts GTK theme to omarchy-nix default (Adwaita-dark) and Qt to unconfigured
(Fusion default).

### Alternative: nixos-build rollback

If the change was already built and switched:

```bash
nixos-build rollback-to-previous
```

This switches to the previous Home Manager generation without touching the
git working tree.

### Rollback Safety Checklist

- [ ] Single file changed → single file revert
- [ ] No state migration needed
- [ ] No data loss risk
- [ ] Previous HM generation preserved (nixos-build creates a new generation)
- [ ] MATE hosts (rog, thinkcentre) are unaffected in all scenarios

---

## 9. Open Questions

| Question | Answer |
|----------|--------|
| Does omarchy-nix set `gtk.theme` as a full attrset or individual sub-options? | Full attrset `{ name, package }` at priority 100. Confirmed by the fact that defining both without mkForce produces a duplicate error. |
| Is `materia-theme` available in nixpkgs on t14? | Yes — it is an unfree-free package in nixpkgs, not gated by any allowUnfree. HM auto-installs it via `gtk.theme.package`. |
| Will existing running Qt apps pick up the new style automatically? | No — they need to be restarted. Environment variables (QT_STYLE_OVERRIDE, QT_QPA_PLATFORMTHEME) are set at process start. Existing processes inherit old values from their session. |
| Should we add `home.sessionVariables` for Qt to ensure env vars propagate to all processes? | No — HM's qt module already sets these env vars via systemd user services. Applications launched from the DE session inherit them. |
