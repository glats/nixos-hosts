# Spec: host-desktop-suite-separation

## Capability: desktop-suite-option

### R1: Suite Option Declaration

The system SHALL provide a `my.desktop.suite` option (type: `enum [ "mate" "gnome" ]` or `null`, default: `null`).

#### Scenario: Host declares MATE suite

- GIVEN a host sets `my.desktop.suite = "mate"`
- WHEN the system evaluates
- THEN `environment.systemPackages` includes atril, caja, engrampa, eom, marco, pluma, mate-panel, mate-sensors-applet, mate-user-share, and materia-theme
- AND the `org/mate/marco/general` compositing-manager dconf lock IS applied

#### Scenario: Host declares GNOME suite

- GIVEN a host sets `my.desktop.suite = "gnome"`
- WHEN the system evaluates
- THEN `environment.systemPackages` includes gnome-system-monitor
- AND the MATE dconf lock IS NOT applied

#### Scenario: No suite declared

- GIVEN a host does not set `my.desktop.suite`
- WHEN the system evaluates
- THEN neither MATE nor GNOME suite packages are installed

### R2: MATE Package Isolation

MATE suite packages (atril, caja, engrampa, eom, marco, pluma, mate-panel, mate-sensors-applet, mate-user-share, materia-theme) MUST NOT reside in the shared base profile (`modules/base/profiles/base.nix`). They SHALL live in `modules/base/profiles/mate.nix`.

#### Scenario: t14 closure has zero MATE packages

- GIVEN t14 sets `my.desktop.suite = "gnome"`
- WHEN the closure is built
- THEN `nix path-info` contains zero packages matching `mate-`
- AND `materia-theme` is NOT in the closure

#### Scenario: rog closure has all MATE packages

- GIVEN rog sets `my.desktop.suite = "mate"`
- WHEN the closure is built
- THEN all 9 MATE packages and materia-theme ARE in the closure

### R3: GNOME Suite Composition

The GNOME profile (`modules/base/profiles/gnome.nix`) SHALL provide `gnome-system-monitor`. The omarchy-nix input provides the remaining GNOME baseline (nautilus, calculator, evince, loupe, sushi, etc.).

#### Scenario: t14 gets gnome-system-monitor

- GIVEN t14 sets `my.desktop.suite = "gnome"`
- WHEN the system builds
- THEN `gnome-system-monitor` IS in `environment.systemPackages`

#### Scenario: rog does not get gnome-system-monitor

- GIVEN rog sets `my.desktop.suite = "mate"`
- WHEN the system builds
- THEN `gnome-system-monitor` is NOT in `environment.systemPackages`

### R4: Shared Base Preservation

The shared base profile MUST retain: CLI utilities (fzf, bat, git, htop, etc.), icon themes (papirus, hicolor, adwaita), `gnome-themes-extra`, `gtk-engine-murrine`, desktop misc (libsecret, dex, google-cloud-sdk), and application packages (ghostty, flatpak, meld, flameshot, copyq, gpaste, conky, gparted, hexchat, popsicle, hypridle, remmina, etc.).

#### Scenario: All hosts receive shared packages

- GIVEN any host imports `modules/base/packages.nix`
- WHEN the system builds
- THEN CLI utilities, papirus-icon-theme, adwaita-icon-theme, gnome-themes-extra, and gtk-engine-murrine ARE in the closure regardless of suite value

### R5: Per-Host Suite Declaration

Each Linux host MUST declare `my.desktop.suite` in its `default.nix`.

#### Scenario: All three hosts declare suites

- GIVEN the flake evaluates
- WHEN `nix flake check --no-build` runs
- THEN rog = `"mate"`, thinkcentre = `"mate"`, t14 = `"gnome"`

### R6: t14 Dark-Mode Preservation

All five t14 dark-mode workaround files MUST remain unchanged after this change.

#### Scenario: Dark-mode config untouched

- GIVEN the change is applied
- WHEN diffing against pre-change state
- THEN these files are UNCHANGED: `patches/xdg-desktop-portal/settings-allow-unsandboxed.patch`, portal config in `hosts/t14/default.nix` (overlay lines 82-90, portal lines 151-180, HM portal lines 217-227), GTK4 fix in `hosts/t14/home/omarchy.nix` (lines 160-164), Papirus override in `hosts/t14/home/omarchy.nix` (lines 151-154)

## Capability: gnome-disk-utility-upstream

### R7: Upstream gnome-disk-utility

The `glats/omarchy-nix` repository SHALL include `gnome-disk-utility` in `modules/packages.nix` systemPackages list.

#### Scenario: omarchy-nix provides gnome-disk-utility

- GIVEN the omarchy-nix flake evaluates
- WHEN systemPackages are collected
- THEN `gnome-disk-utility` IS in the list

#### Scenario: t14 receives gnome-disk-utility after flake update

- GIVEN the omarchy-nix PR is merged and `nix flake update omarchy-nix` runs
- WHEN t14 builds
- THEN `gnome-disk-utility` IS in t14's closure

## Non-Functional Requirements

| ID | Requirement |
|----|-------------|
| NFR1 | `nix flake check --no-build` MUST pass with zero errors |
| NFR2 | `format-nix` MUST produce zero diffs after all `.nix` changes |
| NFR3 | rog/thinkcentre MUST retain identical MATE functionality (XRDP sessions, dconf, all MATE apps) post-change |
| NFR4 | `gnome-keyring` (daemon + PAM wiring) MUST remain cross-host in `modules/hardware/keyring.nix`, not in any suite profile |

## Acceptance Criteria

- [ ] `nix flake check --no-build` passes
- [ ] `format-nix` clean
- [ ] t14 closure: zero `mate-` packages, zero `materia-theme`
- [ ] rog/thinkcentre closure: all 9 MATE packages + materia-theme present, no `gnome-system-monitor`
- [ ] t14 closure: `gnome-system-monitor` + `gnome-disk-utility` present (after upstream merge + flake update)
- [ ] All 5 t14 dark-mode files unchanged
- [ ] `my.desktop.suite` declared in each host's `default.nix`
- [ ] omarchy-nix `modules/packages.nix` contains `gnome-disk-utility`
