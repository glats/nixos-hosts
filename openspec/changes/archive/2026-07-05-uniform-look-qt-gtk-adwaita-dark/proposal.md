# SDD Proposal: uniform-look-qt-gtk-adwaita-dark

## Intent

Achieve a uniform dark look across Qt and GTK applications on all Linux hosts (rog, thinkcentre, t14). On MATE hosts this is already correct via the shared `home-linux/theme.nix` module. On t14 (Hyprland/Omarchy), Qt apps use the default Fusion style and GTK uses Adwaita-dark from omarchy-nix -- both breaking visual consistency.

The fix: override omarchy-nix's GTK theme to Materia-dark-compact and add the same Qt configuration (Adwaita Dark style + GTK3 platform theme bridge) that MATE hosts already use.

## Scope

### In Scope

- **t14** (`hosts/t14/home/omarchy.nix`): override GTK theme from Adwaita-dark to Materia-dark-compact, add Qt block (style: adwaita-dark, platformTheme: gtk3)
- **adwaita-qt package**: ensure it is available on t14 (currently only in shared package list; verify activation)

### Out of Scope

- MATE hosts (rog, thinkcentre) -- already correct via `home-linux/theme.nix`
- xdg-desktop-portal configuration (separate concern)
- Cursor theme (different per host, not related to Qt/GTK look)
- `materia-theme` removal (still needed on t14 alongside MATE hosts)
- `gnome-themes-extra` removal (still pulled by omarchy-nix; harmless)
- GTK4 `extraConfig` and `extraCss` tweaks from `home-linux/theme.nix` (MATE-specific; not relevant for Hyprland)

## Capabilities

After this change, the system SHALL:

1. **C-QT-1**: t14 Qt applications SHALL render with Adwaita Dark style
2. **C-QT-2**: t14 Qt file dialogs SHALL use GTK3 theming (font, decoration, icon consistency)
3. **C-GTK-1**: t14 GTK applications SHALL use Materia-dark-compact theme (matching MATE hosts)
4. **C-GTK-2**: t14 icon theme SHALL remain Papirus-Dark (already set, unchanged)
5. **C-CONSISTENCY-1**: All three Linux hosts SHALL use the same GTK theme (Materia-dark-compact), Qt style (Adwaita Dark), and icon theme (Papirus-Dark)

## Approach

**Single file change** in `hosts/t14/home/omarchy.nix`. Two additions in the existing GTK/QT config block:

1. **Override GTK theme** -- wrap `gtk.theme` with `lib.mkForce` to defeat omarchy-nix's priority-100 definition of Adwaita-dark:
   ```nix
   gtk.theme = lib.mkForce {
     name = "Materia-dark-compact";
     package = pkgs.materia-theme;
   };
   ```

2. **Add Qt block** -- same configuration as `home-linux/theme.nix`:
   ```nix
   qt = {
     enable = true;
     platformTheme.name = "gtk3";
     style.name = "adwaita-dark";
   };
   ```

Change is placed after the existing `gtk.iconTheme` and `gtk.colorScheme` lines so all GTK-related overrides are grouped together.

## Affected Areas

| Area | Impact |
|------|--------|
| `hosts/t14/home/omarchy.nix` | +8 lines (GTK override + Qt block) |
| `pkgs` layer | None (materia-theme, adwaita-qt already in system packages) |
| MATE hosts (rog, thinkcentre) | None (already correct) |

## Risks

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Missing `lib.mkForce` on `gtk.theme` causes Nix eval error | Medium | Use `lib.mkForce` explicitly; verify with `nix flake check` |
| `adwaita-qt` not available in t14 HM activation | Low | Verify `pkgs.adwaita-qt` is in `home.packages` or system packages on t14 |

## Rollback Plan

Revert the 8-line addition in `hosts/t14/home/omarchy.nix`:

```bash
git checkout -- hosts/t14/home/omarchy.nix
nixos-build
```

No state migration or data loss -- this is purely a user-theme config change.

## Dependencies

- `materia-theme` -- already in system packages across all hosts (`modules/base/profiles/base.nix`)
- `adwaita-qt` -- already in shared packages; verify on t14

## Success Criteria

1. `nix flake check --no-build` passes for the t14 configuration
2. t14 Qt apps (e.g. `qt5ct`, `qt6ct`, `keepassxc`) show dark Adwaita style
3. t14 GTK apps show Materia-dark-compact theme
4. GTK and Qt file dialogs match visually
5. No regressions on rog or thinkcentre
