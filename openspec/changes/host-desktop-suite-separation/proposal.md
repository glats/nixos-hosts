# Proposal: Host Desktop Suite Separation

## Intent

Each host installs only the desktop suite it uses: rog/thinkcentre get MATE, t14 gets GNOME apps alongside omarchy/Hyprland. No package overlap. NixOS is a thin consumer of omarchy-nix — editing upstream when the port drifts from Arch Omarchy.

**Why now**: t14 currently installs 9 MATE packages + materia-theme + a MATE dconf lock it never uses (leaked via shared `modules/base/profiles/base.nix`). Meanwhile rog/thinkcentre install `gnome-themes-extra` they don't need. There is no per-host suite selector.

## Scope

### In Scope
1. New `my.desktop.suite` option (`"mate"` | `"gnome"` | `null`) defined in a shared module
2. Split `modules/base/profiles/base.nix` → shared base + `mate.nix` + `gnome.nix` suite profiles
3. Compose suite packages in `modules/base/packages.nix` via the option
4. Gate MATE dconf lock (`modules/base/dconf.nix`) on `my.desktop.suite == "mate"`
5. Each host declares its suite in `default.nix`
6. `gnome-system-monitor` added to t14 via the new gnome profile
7. **Upstream PR** to `glats/omarchy-nix`: add `gnome-disk-utility` to `modules/packages.nix`
8. Preserve all 5 t14 dark-mode workaround files unchanged

### Out of Scope
- Full GNOME DE on t14 (no gdm/gnome-shell/mutter) — t14 stays on omarchy/Hyprland
- `gnome-control-center` (Tier 2, deferred — heavy dependency tree, omarchy uses TUI)
- Moving t14 dark-mode patches to omarchy-nix upstream (they are t14-specific workarounds)
- `libmateweather` overlay relocation (1-patch compile cost, not runtime)
- `export-mate-config` script relocation in `nixos-scripts` (deferred)
- RoFI terminal re-pointing (t14 doesn't use rofi; rog/thinkcentre keep `mate-terminal`)

## Capabilities

### New Capabilities
- `desktop-suite-option`: `my.desktop.suite` option + mate/gnome profile split + per-host declaration
- `gnome-disk-utility-upstream`: PR to omarchy-nix adding `gnome-disk-utility` to its package list

### Modified Capabilities
None (no existing `openspec/specs/` to modify)

## Approach

**Approach A** from exploration (recommended): single `my.desktop.suite` option, shared base profile, two new suite profiles.

```
modules/base/profiles/
├── base.nix      # shared: CLI utils, icon themes, desktop misc (no MATE/GNOME-specific)
├── mate.nix      # NEW: atril caja engrampa eom marco pluma mate-panel mate-sensors-applet mate-user-share materia-theme
├── gnome.nix     # NEW: gnome-system-monitor (+ comment: omarchy-nix provides nautilus, calculator, evince, etc.)
├── dev.nix       # unchanged
├── media.nix     # unchanged
├── virt.nix      # unchanged
└── browsers.nix  # unchanged
```

`gnome-themes-extra` and `adwaita-icon-theme` stay in shared base (needed by both suites for libadwaita/icon fallback). `materia-theme` moves to MATE profile (only consumed by `home-linux/theme.nix` on MATE hosts).

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `modules/base/profiles/base.nix` | Modified | Remove MATE pkgs (lines 10-19), `materia-theme` (104). Keep shared pkgs. |
| `modules/base/profiles/mate.nix` | New | MATE suite packages + materia-theme |
| `modules/base/profiles/gnome.nix` | New | `gnome-system-monitor` (+ omarchy-nix baseline comment) |
| `modules/base/packages.nix` | Modified | Import suite profiles conditionally via `my.desktop.suite` |
| `modules/base/dconf.nix` | Modified | Gate marco compositing lock on `my.desktop.suite == "mate"` |
| `modules/base/options.nix` | New (or inline) | Define `my.desktop.suite` option |
| `hosts/rog/default.nix` | Modified | Add `my.desktop.suite = "mate";` |
| `hosts/thinkcentre/default.nix` | Modified | Add `my.desktop.suite = "mate";` |
| `hosts/t14/default.nix` | Modified | Add `my.desktop.suite = "gnome";` |
| `glats/omarchy-nix` `modules/packages.nix` | Modified (upstream PR) | Add `gnome-disk-utility` (~line 26) |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Hidden MATE consumer in shared HM module | Low | `home-linux/shared-modules.nix` already excludes `mate.nix` on t14 via curated import list |
| `gnome-keyring` considered "GNOME suite" by user | Low | Exploration confirmed it's a cross-host daemon (Remmina/libsecret/flatpak need it). Keep as shared. |
| omarchy-nix upstream PR not merged before nixos-hosts change | Med | nixos-hosts change is independent — `gnome-system-monitor` goes via `gnome.nix` profile regardless of upstream timing |
| First build of `gnome-disk-utility` pulls ~100 deps | Low | One-time ~5-10 min build on t14. Acceptable. |

## Rollback Plan

Revert the single nixos-hosts PR (restores `modules/base/profiles/base.nix` monolith). The upstream omarchy-nix PR is a single-line add — revert independently if needed. No data migration, no secret changes.

## Dependencies

- Upstream PR: `glats/omarchy-nix` — add `gnome-disk-utility` to `modules/packages.nix`
- After upstream merge: `nix flake update omarchy-nix` in nixos-hosts

## Delivery Plan

| # | PR | Repo | Content | Lines |
|---|----|------|---------|-------|
| 1 | Upstream PR | `glats/omarchy-nix` | Add `gnome-disk-utility` to `modules/packages.nix` | ~1 |
| 2 | Main PR | `glats/.nixos` | Suite option + profile split + host declarations + `gnome-system-monitor` | ~80-120 |
| 3 | Lock bump | `glats/.nixos` | `nix flake update omarchy-nix` (after PR #1 merges) | 0 (lock only) |

PRs #1 and #2 are independent and can proceed in parallel.

## Success Criteria

- [ ] `nix flake check --no-build` passes
- [ ] `format-nix` clean
- [ ] t14 closure contains zero MATE packages (`nix path-info` grep for `mate-`)
- [ ] rog/thinkcentre closure contains MATE packages, no `gnome-system-monitor`
- [ ] t14 closure contains `gnome-disk-utility` (after upstream merge) + `gnome-system-monitor`
- [ ] All 5 t14 dark-mode files unchanged (diff confirms)
- [ ] `my.desktop.suite` declared in each host's `default.nix`
