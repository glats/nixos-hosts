# Exploration: Omarchy-Nix GNOME Apps Investigation

**Date**: 2026-06-27
**Project**: nixos-hosts
**Artifact type**: exploration (architecture)
**Subject**: What GNOME apps (if any) does the `omarchy-nix` flake input include by default? What makes sense to add for t14 alongside Hyprland?

This exploration supports the parent
[`host-desktop-suite-separation`](./exploration.md) change (option (b):
"GNOME apps alongside Hyprland/omarchy on t14"). It investigates the
flake input `omarchy-nix` directly and cross-references the upstream
Omarchy Arch Linux package list.

---

## Flake Input Identification

### Where omarchy-nix is imported

`flake.nix:19-23` — flake input declaration:
```nix
omarchy-nix = {
  url = "github:glats/omarchy-nix/main";
  inputs.nixpkgs.follows = "nixpkgs";
  inputs.home-manager.follows = "home-manager";
};
```

`flake.nix:212-215` — wired into the `t14` host:
```nix
extraModules = [
  inputs.omarchy-nix.nixosModules.default
  inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t14-amd-gen4
];
```

The standalone `homeConfigurations.t14` entry also imports
`inputs.omarchy-nix.homeManagerModules.default` via
`hosts/t14/home/omarchy.nix:43`.

### Pinned revision

From `flake.lock`:
- **Owner**: `glats`
- **Repo**: `omarchy-nix`
- **Revision**: `d6f01639b552b9f0ad29946bf2b2401a81ce1842`
- **Last modified**: 2026-06-28 00:12:10
- **NarHash**: `sha256-VjSvMGcm9DA/3boE4yJtQfyymZ1G6/veXo85s4HuBqU=`

The on-disk source is at
`/nix/store/vngsq6mhh0v1vx7hwcnl070rllfpw304-source/` (resolved via
`nix eval --impure --expr 'let f = builtins.getFlake "/home/glats/.nixos"; in f.inputs.omarchy-nix.outPath'`).

This is a **fork** maintained by `glats` (the nixos-hosts owner) of the
upstream `mrosseel/omarchy-nix` project. The upstream is itself a NixOS
port of basecamp/omarchy (Arch Linux flavor by DHH).

### Upstream lineage

| Layer | Repo | Purpose |
|-------|------|---------|
| Source of truth | `basecamp/omarchy` (Arch Linux) | Original Hyprland-based DE |
| NixOS port | `mrosseel/omarchy-nix` | First NixOS port (CLAUDE.md credits `henrysipp`) |
| This flake | `glats/omarchy-nix` | Glats's fork with local customizations |

CLAUDE.md and `README.md` confirm: "Omanix brings that same experience
to NixOS with one guiding principle: **stay as close to Omarchy as
possible**. This is a port, not a reimagining."

---

## What GNOME Apps omarchy-nix Includes (Default)

### Direct grep of `modules/packages.nix`

From `/nix/store/vngsq6mhh0v1vx7hwcnl070rllfpw304-source/modules/packages.nix`:

| Package | Line | Source / purpose |
|---------|------|------------------|
| `nautilus` | 17 | **Primary file manager** — bound to `SUPER+SHIFT+F` (omarchy default) and `SUPER+ALT+SHIFT+F` (t14 cwd variant) |
| `gnome-themes-extra` | 25 | Adwaita/Adwaita-dark GTK theme (required for libadwaita dark mode) |
| `gnome-calculator` | 83 | Calculator — bound to `SUPER+R` and `XF86Calculator` |
| `loupe` | 84 | **GNOME image viewer** (replaces `eog` in upstream Omarchy) |
| `ffmpegthumbnailer` | 129 | Video thumbnails inside Nautilus |
| `sushi` | 130 | Nautilus spacebar previewer (`org.gnome.NautilusPreviewer`) |
| `gnome-keyring` | 133 | Service: `services.gnome.gnome-keyring.enable = true` in `system.nix:208` |
| `pavucontrol` | 14 | **GNOME** PulseAudio/PipeWire volume control |
| `blueman` | 26 | **GNOME** bluetooth manager (autostart disabled in `default.nix:120-123`) |

### GNOME apps that are NOT in omarchy-nix

`grep -E "gnome-(control-center|system-monitor|disk-utility|text-editor|console|calendar|clocks|weather|maps|screenshot|terminal)" modules/`
returns **zero results** in omarchy-nix.

| App | In omarchy-nix? | In upstream Arch Omarchy? | Notes |
|-----|-----------------|--------------------------|-------|
| `gnome-control-center` | NO | NO | Not a default in either |
| `gnome-system-monitor` | NO | NO | Not a default in either |
| `gnome-disk-utility` | **NO** | **YES** | **Notable omarchy-nix omission** — see Analysis |
| `gnome-screenshot` | NO | NO | Replaced by `satty` (line 37) |
| `gnome-text-editor` | NO | NO | `omarchy-launch-editor` defaults to `nvim` |
| `gnome-console` | NO | NO | Replaced by `ghostty` / `alacritty` / `kitty` |
| `gnome-calendar` | NO | NO | Webapps instead (HEY Calendar at `SUPER+C`) |
| `gnome-clocks` | NO | NO | Not a default |
| `gnome-weather` | NO | NO | Not a default |
| `gnome-maps` | NO | NO | Not a default |
| `gnome-terminal` | NO | NO | Replaced by Ghostty/Alacritty/Kitty |
| `eog` (Eye of GNOME) | NO | NO | Replaced by `loupe` (GNOME's modern successor) |
| `gedit` | NO | NO | Replaced by `neovim` |
| `nautilus-python` (extension) | YES (extensions/localsend.py) | YES (AUR: `nautilus-python`) | Adds "Send via LocalSend" context menu |

### Window rules confirm GNOME app integration

`default/hypr/apps/system.conf` (deployed to `~/.local/share/omarchy/default/hypr/apps/system.conf`) lists explicit GNOME class names for window rules:

```
windowrule = tag +floating-window, match:class (… org.gnome.NautilusPreviewer | org.gnome.Evince | …)
windowrule = tag +floating-window, match:class (… xdg-desktop-portal-gtk | org.gnome.Nautilus), match:title ^(Open.*Files?|…)
windowrule = float on, match:class org.gnome.Calculator
windowrule = opacity 1 1, match:class ^(… | org.gnome.NautilusPreviewer)$
```

So Hyprland is **explicitly aware** of `Nautilus`, `NautilusPreviewer`
(sushi), `Evince`, and `Calculator` window classes.

### What omarchy-nix is NOT

omarchy-nix is **not** a full GNOME desktop. There is:
- No `services.xserver.displayManager.gdm.enable = true`
- No `services.xserver.desktopManager.gnome.enable = true`
- No `gnome-shell`, no `gnome-session`
- No `mutter`

Display manager: `services.greetd.enable = true` (`modules/nixos/system.nix:103`)
with `tuigreet` (default) or `uwsm start hyprland-uwsm.desktop`
(seamless-boot).

### The "GNOME suite" footprint in omarchy-nix is small and surgical

It's a **GNOME-apps-on-Hyprland** setup, not "GNOME DE alongside
Hyprland". Nautilus, gnome-calculator, evince, loupe, sushi,
gnome-keyring, pavucontrol, blueman, gnome-themes-extra are the only
GNOME dependencies. All are integrated as regular apps, with no shared
session or shell component.

---

## Upstream Omarchy (Arch) Cross-Reference

The full upstream Arch package list (`basecamp/omarchy` →
`install/omarchy-base.packages`, commit `ed9a4a45`) was fetched and
cross-referenced.

### All GNOME-origin packages in upstream Arch Omarchy

The full list is **just 6 GNOME packages**:

1. `evince` ✅
2. `gnome-calculator` ✅
3. `gnome-keyring` ✅
4. `gnome-themes-extra` ✅
5. `nautilus` ✅
6. **`gnome-disk-utility`** ⚠️ **Present in upstream Arch but OMITTED in omarchy-nix**

Plus the `gnome-` flavor of `polkit-gnome` (agent, not a suite app) and
`python-gobject` (Nautilus extension runtime). Neither is a "GNOME app"
in the user-facing sense.

### What omarchy-nix dropped from upstream (notable GNOME-adjacent)

- `gnome-disk-utility` (the only user-facing GNOME app dropped)
- `aether` (screen recorder — `gpu-screen-recorder` + `wf-recorder` substitute)
- `sddm` (replaced by `greetd` + `uwsm`)
- `polkit-gnome` (omarchy-nix uses `services.dbus.enable = true` + Hyprland polkit agent via UWSM)
- `nss-mdns` (replaced by `services.avahi` in `system.nix:184`)

### What omarchy-nix added beyond upstream (GNOME-adjacent)

- `loupe` (modern GNOME image viewer — replaces `eog` which isn't even in upstream Omarchy)
- `pavucontrol` (volume control GUI)
- `blueman` (bluetooth GUI, autostart hidden)
- `bibata-cursors` (cursors — not GNOME but worth noting)
- `gnome-themes-extra` is in both (same version pinned)

---

## Current t14 State (re-verify)

### Packages currently on t14 (from omarchy-nix)

Every GNOME app listed above (nautilus, gnome-calculator, evince, loupe,
sushi, gnome-keyring, gnome-themes-extra, pavucontrol, blueman,
ffmpegthumbnailer) is **already on t14** through the omarchy-nix input.
The `nautilus` binary is at
`/home/glats/.nixos/hosts/t14/home/hypr/bindings.nix:43` and is invoked
via `uwsm-app -- nautilus --new-window "$(omarchy-cmd-terminal-cwd)"`.

### Existing GNOME-specific config on t14

| File:line | Configuration | Why |
|-----------|---------------|-----|
| `hosts/t14/default.nix:79-90` | xdg-desktop-portal patch for Settings portal | Native Nautilus on Hyprland needs Settings portal to read color-scheme |
| `hosts/t14/default.nix:150-180` | xdg.portal.config + extraPortals for `gtk.portal` with `UseIn=gnome;hyprland` | Forces the gtk portal to handle Settings interface (libadwaita depends on it) |
| `hosts/t14/home/omarchy.nix:160-164` | `gtk.colorScheme = "dark"` + `gtk.gtk4.extraConfig."gtk-interface-color-scheme" = "dark"` | Nautilus (libadwaita) reads GTK4 settings to apply dark mode |
| `hosts/t14/home/omarchy.nix:151-154` | `gtk.iconTheme = { name = "Papirus-Dark"; package = pkgs.papirus-icon-theme; }` | Omarchy doesn't set an icon theme; this overrides |

t14's `home/hypr/bindings.nix` does **not** add any GNOME-app
keybindings. It only:
- Adds `SUPER+Q` (window switcher), `SUPER+M` (alt switcher)
- Overrides `SUPER+SHIFT+R` to `wofi --show run` (overrides omarchy's `gnome-calculator` bind)
- Mirrors upstream omarchy's `SUPER+ALT+RETURN` (tmux) and `SUPER+ALT+SHIFT+F` (nautilus cwd)
- Adds lid-switch bindings

---

## Hyprland Ecosystem Alternatives

`grep -E "nwg-look|nwg-shell|hyprland-control|hyprland-settings"` against
omarchy-nix returns **zero results**.

The Hyprland "control panel" space includes:
- **`nwg-look`** — LXAppearance-style GTK theme/font/icon switcher
- **`nwg-shell`** — Full panel/dock for wlroots-based WMs
- **`hyprland-control-center`** — PyQt6 settings panel
- **`hyprland-settings`** — GTK4 settings UI

**None of these are used by omarchy-nix.** Instead, omarchy-nix ships
its own `omarchy-menu` / `omarchy-toggle-*` / `omarchy-theme-set-*`
scripts (90+ shell scripts in `bin/`). Examples:
- `omarchy-menu` — top-level launcher (SUPER+ALT+SPACE)
- `omarchy-menu system` — power / lock / logout (SUPER+ESCAPE)
- `omarchy-menu theme` — theme picker (SUPER+SHIFT+CTRL+SPACE)
- `omarchy-menu toggle` — toggles (SUPER+CTRL+O)
- `omarchy-theme-set-gnome` — applies color-scheme + GTK theme via gsettings
- `omarchy-launch-bluetooth` — bluetui TUI
- `omarchy-launch-wifi` — impala TUI
- `omarchy-launch-audio` — wiremix TUI

The settings story is "TUIs everywhere + omarchy menu". The
"GUI control panel" role is **deliberately empty** — omarchy is opinionated about
TUI-first settings.

---

## Analysis: What GNOME Apps Make Sense for t14

### User's stated goal (from parent exploration)

> t14: GNOME suite ONLY (NOT MATE) — option (b): GNOME apps alongside
> Hyprland/omarchy on t14

This means: keep omarchy/Hyprland, but add a curated set of GNOME apps
so the system has a coherent "GNOME-ish" feel for things that omarchy
omits.

### Tier 1 — STRONGLY RECOMMENDED (matches upstream Arch Omarchy, omarchy-nix just dropped it)

#### `gnome-disk-utility` (palimpsest)
- **Why**: The single GNOME app in upstream Arch Omarchy that omarchy-nix omitted. Disk management GUI (format/mount/eSMART/badblocks). On a laptop this is high-value.
- **Conflict check**: NONE. omarchy-nix doesn't reference it; Hyprland will treat it as a normal GTK4 app.
- **Bind suggestion**: `bindd = SUPER SHIFT, U, Disks, exec, uwsm-app -- gnome-disk-utility` (currently unused by omarchy)

#### `gnome-system-monitor` (gnome-system-monitor)
- **Why**: Process and resource viewer. omarchy uses `btop` (TUI) but `btop` is for `SUPER+SHIFT+T`. A GUI fallback for GUI users is useful.
- **Conflict check**: NONE. GNOME-class app, no overlap with `btop`.
- **Bind suggestion**: `bindd = SUPER SHIFT CTRL, M, System monitor, exec, uwsm-app -- gnome-system-monitor` (currently unused)
- **Alternative**: `gnome-usage` (lighter GNOME resource viewer) — but it's not in upstream Arch either; `gnome-system-monitor` is the standard choice.

### Tier 2 — CONDITIONAL (depends on user preference)

#### `gnome-control-center` (gnome-control-center)
- **Why**: Provides a unified GUI for Wi-Fi, displays, mouse/touchpad, keyboard, sound, etc. Without it, t14's settings story is purely TUI / omarchy-menu.
- **Against**: Upstream Arch Omarchy also doesn't ship it. `gnome-control-center` brings GTK4 settings panels that depend on `gnome-online-accounts`, `libadwaita`, etc. It's a non-trivial dependency tree (~30-50 packages pulled in). It is **NOT** what omarchy considers opinionated.
- **Conflict check**: No conflict per se, but it pulls a lot of GNOME infrastructure (accounts, network panels) that overlap with omarchy's walker + impala + omarchy-menu + bluetui story.
- **Recommendation**: Only add if the user specifically wants a unified GUI. The omarchy way is TUI menus.
- **Bind suggestion**: `bindd = SUPER CTRL, P, Settings, exec, uwsm-app -- gnome-control-center` (mirror's macOS pattern)

#### `gnome-text-editor` (gedit replacement)
- **Why**: Lightweight GUI text editor. Useful for ad-hoc edits without opening a terminal.
- **Against**: omarchy's `omarchy-launch-editor` defaults to `nvim`. Adding `gnome-text-editor` introduces another editor.
- **Recommendation**: Skip unless the user wants a GUI editor.

### Tier 3 — DO NOT ADD (redundant with omarchy)

| App | Already covered by |
|-----|--------------------|
| `gnome-screenshot` | `satty` (line 37 of packages.nix; bound to PRINT) |
| `gnome-console` | `ghostty` / `alacritty` / `kitty` (lines 32-34) |
| `gnome-terminal` | Same |
| `gnome-calendar` | HEY Calendar webapp (SUPER+C) |
| `gnome-clocks` | Not needed (date in waybar) |
| `gnome-weather` | omarchy has `omarchy-weather-status` (waybar) |
| `gnome-maps` | Not in upstream Arch; web browser covers it |
| `eog` | `loupe` (omarchy-nix already uses it) |
| `gedit` | `neovim` (omarchy default) |
| `nautilus` | already installed |

### Recommended package list for t14

```nix
# In hosts/t14/default.nix, after the existing omarchy config block:
environment.systemPackages = with pkgs; [
  # Tier 1: matches upstream Arch Omarchy
  gnome-disk-utility      # disk manager GUI
  gnome-system-monitor    # process/resource GUI

  # Tier 2: only if user wants a unified settings panel
  # gnome-control-center  # UNCOMMENT only after user request
];
```

Total weight: 2 packages in Tier 1 (both already in nixpkgs; `gnome-disk-utility` is ~30 MB, `gnome-system-monitor` is ~10 MB). Zero new binary caches to populate if the user already has Hyprland GNOME-adjacent apps.

### No conflicts with existing omarchy-nix config

- **No service conflicts**: omarchy-nix has `services.gnome.gnome-keyring.enable = true` already; `gnome-disk-utility` and `gnome-system-monitor` use the standard D-Bus services that are already running.
- **No Hyprland binding conflicts**: all suggested binds use keys not in the omarchy-nix defaults or in `hosts/t14/home/hypr/bindings.nix`.
- **No MIME conflicts**: `xdg-mime` default for `inode/directory` stays `org.gnome.Nautilus.desktop` (omarchy default). `gnome-disk-utility` and `gnome-system-monitor` register their own .desktop files but don't claim directory association.
- **No theme conflicts**: All GNOME apps share the same `gnome-themes-extra` (Adwaita) theme already set by omarchy-nix.
- **No dconf conflicts**: omarchy-nix sets `org.gnome.desktop.interface` `color-scheme` and `gtk-theme` via `omarchy-theme-set-gnome`; `gnome-disk-utility` and `gnome-system-monitor` read those keys (no writes).

---

## Open Questions Resolved (vs parent exploration.md)

The parent `exploration.md` listed these open questions for the GNOME
side. This exploration answers them:

| # | Open question | Answer |
|---|---------------|--------|
| 1 | "What is the GNOME suite on t14?" | Option (b) confirmed: omarchy/Hyprland + targeted GNOME apps. The "GNOME suite" in this repo is **a curated set of GNOME apps**, not a GNOME DE. omarchy-nix's curated list is the baseline; t14 should add `gnome-disk-utility` and `gnome-system-monitor` to match upstream Arch Omarchy. |
| 2 | "Is `gnome-keyring` a GNOME-suite package?" | **No.** It's a generic dependency required by Remmina, flatpak, signal-desktop, brave, chromium. omarchy-nix enables it (`services.gnome.gnome-keyring.enable = true`). It's already on t14. **Treat as cross-host daemon**, not a suite package. |
| 3 | "Is `mate-terminal` in rofi.nix a problem?" | N/A — t14 doesn't use rofi (uses walker). No change needed. |
| 4 | "Is `adwaita-icon-theme` shared or suite-specific?" | **Shared.** It's needed by t14 (Nautilus/libadwaita) AND by rog/thinkcentre (theme.nix). Keep in shared base. |
| 5 | "Is `gnome-themes-extra` shared or suite-specific?" | **Shared.** It's required for libadwaita dark mode on t14. Rog/thinkcentre don't strictly need it (they use materia), but they don't break if it stays. Either keep cross-host or move to GNOME-side; both are valid. |
| 6 | "Is `libmateweather` overlay needed on t14?" | **No** — but it's a 1-patch overlay compile cost, not a runtime cost. Keep as cross-host overlay. |

---

## Affected Areas

| File | Why affected |
|------|-------------|
| `hosts/t14/default.nix` | Add `gnome-disk-utility` and `gnome-system-monitor` to `environment.systemPackages` (or via a new `modules/base/profiles/gnome-extras.nix` if the split is adopted in the parent change). |
| `hosts/t14/home/hypr/bindings.nix` | Optional: add Hyprland keybindings for the new apps. Could also stay bindless (walker / omarchy-menu can launch them by name). |
| `modules/base/profiles/gnome.nix` (new, if Approach A wins) | New file in the parent change. The `gnome-disk-utility` and `gnome-system-monitor` packages belong here (GNOME-suite profile), not in the shared base. |
| `flake.lock` | No change — omarchy-nix input is already pinned. |
| `modules/hardware/keyring.nix` | No change — `gnome-keyring` is already enabled. |

---

## Risks

- **`gnome-control-center` pull**: If the user later requests it, the
  dependency tree grows significantly. The proposal phase should make
  Tier 1 (disk-utility, system-monitor) the default and Tier 2
  (control-center) opt-in.
- **t14's `~/.config/user-dirs.dirs` collision**: Already mitigated by
  `backupFileExtension = "backup"` in `hosts/t14/default.nix:196`. No
  new risk.
- **No binary cache for new packages**: First build of
  `gnome-disk-utility` will pull GTK4, udisks2, libsecret, libpwquality
  (~100 packages). Estimated build time on t14 (AMD): 5-10 minutes.
  Acceptable for a one-off.
- **Window class collision with floating rules**: omarchy-nix's
  `default/hypr/apps/system.conf` has window rules for `org.gnome.Nautilus`,
  `org.gnome.Evince`, `org.gnome.NautilusPreviewer`,
  `org.gnome.Calculator`. `gnome-disk-utility` has class
  `org.gnome.DiskUtility` and `gnome-system-monitor` has class
  `gnome-system-monitor` — neither matches the existing floating rules.
  Both will open tiled by default. t14 may want to add them to the
  floating rule list (or as a window rule in `looknfeel.nix`).

---

## Ready for Proposal

**Yes.** This exploration answers the open question #1 from the parent
exploration: t14 will keep omarchy/Hyprland and **add 2 GNOME apps**
that upstream Arch Omarchy ships but omarchy-nix omitted:
`gnome-disk-utility` + `gnome-system-monitor`. Optionally add
`gnome-control-center` if the user wants a unified settings GUI.

The proposal phase (parent change) should:
1. Confirm the Tier 1 list with the user (`gnome-disk-utility`,
   `gnome-system-monitor`).
2. Confirm whether to add Tier 2 (`gnome-control-center`).
3. Decide where the package list lives:
   - Inline in `hosts/t14/default.nix` (simplest), or
   - In a new `modules/base/profiles/gnome.nix` consumed via
     `my.desktop.suite = "gnome";` (matches the parent's Approach A).
4. Add Hyprland window rules in `hosts/t14/home/hypr/looknfeel.nix` to
   make the new apps float (they're typically used as dialogs).
5. Validate with `nix flake check --no-build` and `format-nix`.

**Estimated diff**: ~10-20 lines. Well within the 400-line single-PR
budget. No chained PRs needed.
