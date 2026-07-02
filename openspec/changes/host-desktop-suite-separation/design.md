# Design: Host Desktop Suite Separation

## Technical Approach

Introduce a `my.desktop.suite` option (`"mate"` | `"gnome"`) that gates which desktop suite packages and dconf locks a host receives. Split the monolithic `modules/base/profiles/base.nix` package list into a shared base + two suite-specific profiles. Each host declares its suite in one line. Upstream `omarchy-nix` gets a one-line `gnome-disk-utility` add.

## Architecture Decisions

### Decision: Option declaration location and type

| Option | Tradeoff | Decision |
|--------|----------|----------|
| New `modules/base/options.nix` | Dedicated file, clear ownership, follows `my.shutdownDebug` pattern | **Chosen** |
| Inline in `modules/base/packages.nix` | Fewer files, but mixes option decl with consumption | Rejected |
| Inline in `modules/profiles/base.nix` | Profile chain entry, but that file is imports-only | Rejected |

**Type**: `lib.mkOption` with `type = lib.types.nullOr (lib.types.enum [ "mate" "gnome" ])`, `default = null`. Null allows future hosts that need no suite (headless servers without a DE).

### Decision: gnome-themes-extra and adwaita-icon-theme stay in shared base

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Keep in shared base | Both suites need libadwaita/icon fallback; zero runtime cost | **Chosen** |
| Move to gnome.nix profile | Cleaner separation, but rog/thinkcentre need them for GTK theme rendering | Rejected |

### Decision: materia-theme moves to MATE profile

Only consumed by `home-linux/theme.nix` which is excluded on t14. Dead weight on non-MATE hosts.

### Decision: HM shared-modules.nix — no gating needed

t14 uses its own curated import list in `hosts/t14/home/omarchy.nix` (explicitly excludes `mate.nix`, `rofi.nix`, `theme.nix`, `chrome-apps.nix`). The canonical `shared-modules.nix` list is only consumed by rog/thinkcentre via `modules/base/home-manager.nix`. No change needed.

## Data Flow

```
  hosts/{rog,thinkcentre,t14}/default.nix
    │
    │  my.desktop.suite = "mate" | "gnome"
    │
    ▼
  modules/base/options.nix          ← declares my.desktop.suite option
    │
    │  config.my.desktop.suite
    │
    ├──→ modules/base/packages.nix  ← reads option, imports matching profile
    │      │
    │      ├── import ./profiles/base.nix     (shared: CLI utils, icon themes)
    │      ├── import ./profiles/mate.nix     (if suite == "mate")
    │      ├── import ./profiles/gnome.nix    (if suite == "gnome")
    │      ├── import ./profiles/dev.nix      (always)
    │      ├── import ./profiles/media.nix    (always)
    │      ├── import ./profiles/virt.nix     (always)
    │      └── import ./profiles/browsers.nix (always)
    │      │
    │      └──→ environment.systemPackages = concat of all above
    │
    └──→ modules/base/dconf.nix     ← gates MATE lock on suite == "mate"
           │
           └──→ programs.dconf.profiles.user.databases (only if MATE)
```

## Dependency Graph (new module imports)

```
  modules/profiles/base.nix (unchanged — imports list)
    └── ../base/options.nix          ← NEW import added here
    └── ../base/packages.nix         ← existing import (now reads option)
    └── ../base/dconf.nix            ← existing import (now gated)

  modules/base/packages.nix
    ├── ./profiles/base.nix          ← existing (trimmed)
    ├── ./profiles/mate.nix          ← NEW
    ├── ./profiles/gnome.nix         ← NEW
    ├── ./profiles/dev.nix           ← unchanged
    ├── ./profiles/media.nix         ← unchanged
    ├── ./profiles/virt.nix          ← unchanged
    └── ./profiles/browsers.nix      ← unchanged
```

## File Changes

### nixos-hosts repo (`glats/.nixos`)

| File | Action | Description |
|------|--------|-------------|
| `modules/base/options.nix` | Create | Declare `my.desktop.suite` option |
| `modules/base/profiles/base.nix` | Modify | Remove MATE pkgs (lines 10-19) + `materia-theme` (line 104) |
| `modules/base/profiles/mate.nix` | Create | MATE suite packages + materia-theme |
| `modules/base/profiles/gnome.nix` | Create | `gnome-system-monitor` |
| `modules/base/packages.nix` | Modify | Conditionally import suite profiles via option |
| `modules/base/dconf.nix` | Modify | Gate MATE dconf lock on `suite == "mate"` |
| `modules/profiles/base.nix` | Modify | Add `../base/options.nix` to imports |
| `hosts/rog/default.nix` | Modify | Add `my.desktop.suite = "mate";` |
| `hosts/thinkcentre/default.nix` | Modify | Add `my.desktop.suite = "mate";` |
| `hosts/t14/default.nix` | Modify | Add `my.desktop.suite = "gnome";` |

### omarchy-nix repo (`glats/omarchy-nix`) — upstream PR

| File | Action | Description |
|------|--------|-------------|
| `modules/packages.nix` | Modify | Add `gnome-disk-utility` (~line 26, next to `gnome-themes-extra`) |

### NOT touched (dark mode preservation confirmed)

- `patches/xdg-desktop-portal/settings-allow-unsandboxed.patch`
- `hosts/t14/default.nix:82-90` (xdg-desktop-portal overlay)
- `hosts/t14/default.nix:151-180` (xdg.portal.extraPortals system-level)
- `hosts/t14/default.nix:217-227` (xdg.portal.extraPortals HM-level)
- `hosts/t14/home/omarchy.nix:151-164` (gtk.iconTheme, gtk.colorScheme, gtk4 extraConfig)

## Before/After for Each Changed File

### 1. `modules/base/options.nix` (NEW)

```nix
{ config, lib, ... }:

{
  options.my.desktop.suite = lib.mkOption {
    type = lib.types.nullOr (lib.types.enum [ "mate" "gnome" ]);
    default = null;
    description = ''
      Desktop suite to install. "mate" provides MATE DE packages + materia
      theme + dconf locks. "gnome" provides GNOME apps alongside the host's
      window manager (e.g. omarchy/Hyprland on t14). null installs no suite.
    '';
  };
}
```

### 2. `modules/base/profiles/base.nix` (MODIFY)

**Remove** lines 10-19 (MATE pkgs block) and line 104 (`materia-theme`).
**Keep** `gnome-themes-extra` (line 105) and `adwaita-icon-theme` (line 107) — shared by both suites.

Before (122 lines) → After (~110 lines). The comment header changes from:
```nix
# Base system profile
# Essential packages that every Linux host gets by default:
# - MATE desktop support (not installed by services.xserver.desktopManager.mate.enable)
# - CLI utilities (file, network, archive, process, nix tooling)
# - Desktop applications (terminals, file managers, themes, screenshot tools)
# - System utilities (git, fan control, xrdp audio passthrough module)
```
To:
```nix
# Base system profile — host-agnostic shared packages.
# Suite-specific packages (MATE, GNOME) live in profiles/mate.nix and
# profiles/gnome.nix, selected by the my.desktop.suite option.
# - CLI utilities (file, network, archive, process, nix tooling)
# - Desktop applications (terminals, themes, screenshot tools)
# - System utilities (git, fan control, xrdp audio passthrough module)
```

### 3. `modules/base/profiles/mate.nix` (NEW)

```nix
# MATE desktop suite profile.
# Selected by: my.desktop.suite = "mate";
# Provides: MATE DE packages + materia theme (consumed by home-linux/theme.nix).
{ pkgs }:
with pkgs;
[
  # MATE desktop
  atril
  caja
  engrampa
  eom
  marco
  pluma
  mate-panel
  mate-sensors-applet
  mate-user-share

  # Theme (consumed by home-linux/theme.nix on MATE hosts)
  materia-theme
]
```

### 4. `modules/base/profiles/gnome.nix` (NEW)

```nix
# GNOME desktop suite profile.
# Selected by: my.desktop.suite = "gnome";
# Provides: GNOME apps not already supplied by omarchy-nix.
# omarchy-nix baseline (already on t14 via flake input):
#   nautilus, gnome-calculator, evince, loupe, sushi, pavucontrol,
#   blueman, gnome-themes-extra, gnome-keyring, ffmpegthumbnailer
{ pkgs }:
with pkgs;
[
  gnome-system-monitor
]
```

### 5. `modules/base/packages.nix` (MODIFY)

Before:
```nix
{ config, lib, pkgs, ... }:

let
  basePkgs = import ./profiles/base.nix { inherit pkgs; };
  devPkgs = import ./profiles/dev.nix { inherit pkgs; };
  mediaPkgs = import ./profiles/media.nix { inherit pkgs; };
  virtPkgs = import ./profiles/virt.nix { inherit pkgs; };
  browserPkgs = import ./profiles/browsers.nix { inherit pkgs; };
in
{
  environment.systemPackages = basePkgs ++ devPkgs ++ mediaPkgs ++ virtPkgs ++ browserPkgs;
}
```

After:
```nix
{ config, lib, pkgs, ... }:

let
  cfg = config.my.desktop.suite;

  basePkgs = import ./profiles/base.nix { inherit pkgs; };
  devPkgs = import ./profiles/dev.nix { inherit pkgs; };
  mediaPkgs = import ./profiles/media.nix { inherit pkgs; };
  virtPkgs = import ./profiles/virt.nix { inherit pkgs; };
  browserPkgs = import ./profiles/browsers.nix { inherit pkgs; };

  suitePkgs =
    if cfg == "mate" then import ./profiles/mate.nix { inherit pkgs; }
    else if cfg == "gnome" then import ./profiles/gnome.nix { inherit pkgs; }
    else [ ];
in
{
  environment.systemPackages = basePkgs ++ suitePkgs ++ devPkgs ++ mediaPkgs ++ virtPkgs ++ browserPkgs;
}
```

### 6. `modules/base/dconf.nix` (MODIFY)

Before:
```nix
{ config, lib, pkgs, ... }:

{
  programs.dconf.profiles.user.databases = [
    {
      settings = with lib.gvariant; {
        "org/mate/marco/general" = {
          compositing-manager = false;
        };
      };
      locks = [
        "/org/mate/marco/general/compositing-manager"
      ];
    }
  ];
}
```

After:
```nix
{ config, lib, pkgs, ... }:

{
  programs.dconf.profiles.user.databases = lib.mkIf (config.my.desktop.suite == "mate") [
    {
      settings = with lib.gvariant; {
        "org/mate/marco/general" = {
          compositing-manager = false;
        };
      };
      locks = [
        "/org/mate/marco/general/compositing-manager"
      ];
    }
  ];
}
```

### 7. `modules/profiles/base.nix` (MODIFY)

Add `../base/options.nix` to the imports list (after `../base/cachix.nix`):

```diff
   imports = [
     # Base (transversal modules)
     ../base/cachix.nix
+    ../base/options.nix
     ../base/dconf.nix
```

### 8. `hosts/rog/default.nix` (MODIFY)

Add after `my.shutdownDebug.enable = true;` (line 71):

```diff
   my.shutdownDebug.enable = true;
+
+  # Desktop suite — rog uses MATE via XRDP
+  my.desktop.suite = "mate";
```

### 9. `hosts/thinkcentre/default.nix` (MODIFY)

Add after `boot-settings` block (after line 30):

```diff
   boot-settings = {
     enable = true;
     includeAcpiOsi = false;
   };
+
+  # Desktop suite — thinkcentre uses MATE via XRDP
+  my.desktop.suite = "mate";
```

### 10. `hosts/t14/default.nix` (MODIFY)

Add after `omarchy` config block (after line 148):

```diff
     firewall.enable = false;
   };
+
+  # Desktop suite — t14 uses GNOME apps alongside omarchy/Hyprland.
+  # omarchy-nix provides nautilus, calculator, evince, etc.;
+  # this adds gnome-system-monitor via modules/base/profiles/gnome.nix.
+  my.desktop.suite = "gnome";
```

### 11. omarchy-nix `modules/packages.nix` (UPSTREAM MODIFY)

Add `gnome-disk-utility` after `gnome-themes-extra` (line ~25):

```diff
     bibata-cursors gnome-themes-extra blueman
+    gnome-disk-utility
```

## Interfaces / Contracts

### New option

```nix
options.my.desktop.suite :: nullOr (enum [ "mate" "gnome" ])
```

- `"mate"`: MATE DE packages + materia-theme + dconf marco lock
- `"gnome"`: gnome-system-monitor (omarchy-nix provides the rest)
- `null`: no suite packages (default — safe for headless/future hosts)

### Profile function contract

All profile files (`base.nix`, `mate.nix`, `gnome.nix`, `dev.nix`, etc.) follow the same contract: `{ pkgs }: with pkgs; [ ... ]` — a function returning a flat package list.

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Evaluation | `nix flake check --no-build` passes | CI gate |
| Evaluation | `format-nix` clean | CI gate |
| Closure | t14 closure has zero MATE packages | `nix path-info` grep for `mate-` |
| Closure | rog/thinkcentre closure has MATE pkgs, no `gnome-system-monitor` | `nix path-info` grep |
| Closure | t14 closure has `gnome-system-monitor` + `gnome-disk-utility` (after upstream) | `nix path-info` |
| Diff | All 5 t14 dark-mode files unchanged | `git diff` confirms |
| Option | Each host declares `my.desktop.suite` | grep `default.nix` |

## Migration / Rollout

No migration required. Pure configuration change — `nixos-build switch` applies atomically. Rollback is a single `git revert`.

### Delivery plan (two repos)

| # | Repo | Content | Dependency |
|---|------|---------|------------|
| 1 | `glats/omarchy-nix` | Add `gnome-disk-utility` to `modules/packages.nix` | None |
| 2 | `glats/.nixos` | Suite option + profile split + host declarations | None (parallel with #1) |
| 3 | `glats/.nixos` | `nix flake update omarchy-nix` (lock bump) | After #1 merges |

## Open Questions

None — all resolved in exploration and proposal phases.
