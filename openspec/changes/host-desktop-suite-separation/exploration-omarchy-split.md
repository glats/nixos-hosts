# Exploration: Omarchy-Nix ↔ NixOS Split for t14 GNOME Apps

**Date**: 2026-06-27
**Project**: nixos-hosts
**Artifact type**: exploration (architecture) — focused deep-dive
**Parent change**: [`host-desktop-suite-separation`](./exploration.md)
**Sibling exploration**: [`exploration-omarchy-gnome.md`](./exploration-omarchy-gnome.md) (what GNOME apps to add)

This artifact focuses on **the split line**: what lives in
`github.com/glats/omarchy-nix` vs what stays in the
`/home/glats/.nixos` flake. It also audits the current
**duplication/overlap** between the two and answers "does omarchy-nix
need a new option for t14?".

---

## 1. Omarchy-Nix Repo Structure (current pinned revision)

**Pinned revision** (in `/home/glats/.nixos/flake.lock`):
- Owner: `glats` — **fork maintained by the nixos-hosts owner** of
  `mrosseel/omarchy-nix`
- Revision: `d6f01639b552b9f0ad29946bf2b2401a81ce1842`
- NarHash: `sha256-VjSvMGcm9DA/3boE4yJtQfyymZ1G6/veXo85s4HuBqU=`
- Last modified: 2026-06-28
- Source on disk: cloned to `/tmp/opencode/omarchy-nix` (also at
  `/nix/store/vngsq6mhh0v1vx7hwcnl070rllfpw304-source/`)

**Top-level layout** (5 modules + bin scripts + themes + config):

```
omarchy-nix/
├── flake.nix                      # Module output declarations
├── config.nix                     # All `omarchy.*` options
├── modules/
│   ├── packages.nix               # ★ SINGLE system-packages list (148 lines)
│   ├── custom-base16-schemes.nix  # Theme color schemes
│   ├── themes.nix                 # Theme → base16 mapping
│   ├── nixos/                     # NixOS module (system-level)
│   │   ├── default.nix            # Imports the 12 nixos submodules
│   │   ├── system.nix             # services, packages, PATH, fonts
│   │   ├── hyprland.nix           # xdg.portal.extraPortals = [ gtk ]
│   │   ├── 1password.nix
│   │   ├── browser-policies.nix
│   │   ├── containers.nix
│   │   ├── fido2.nix
│   │   ├── firewall.nix
│   │   ├── gaming.nix
│   │   ├── hardware.nix
│   │   ├── nvidia.nix
│   │   ├── theme-switcher-sudo.nix
│   │   └── voxtype.nix
│   └── home-manager/              # Home-Manager module (user-level)
│       ├── default.nix            # Imports 30+ submodules + dconf
│       ├── hyprland/              # bindings, autostart, input, looknfeel
│       ├── theme-generator.nix
│       ├── evince.nix             # Adds evince to home.packages
│       ├── light-theme-monitor.nix
│       └── … (one file per feature)
├── bin/                           # 150+ shell scripts deployed to ~/.local/share/omarchy/bin
├── default/                       # Static config (deployed via home.file)
│   ├── hypr/apps/system.conf      # ★ Window rules for GNOME classes
│   ├── nautilus-python/extensions/localsend.py
│   └── … (bash, walker themes, elephant menus, etc.)
├── config/                        # Static themes, walker, webapp-icons
├── packages/                      # Custom Nix derivations (plymouth, voxtype, etc.)
└── walker-theme/
```

### 1.1 Module interface (omarchy.* options)

`flake.nix:24-40` exposes `nixosModules.default` which calls
`import ./modules/nixos/default.nix inputs` and merges
`options.omarchy = (import ./config.nix lib).omarchyOptions`.

`flake.nix:42-58` exposes `homeManagerModules.default` which mirrors
the structure for Home Manager. It also copies `osConfig.omarchy` into
HM config via `lib.mkIf (osConfig ? omarchy) { omarchy =
osConfig.omarchy; }` — this is the bridge that makes the same
`omarchy = { theme = "glats"; … }` block work on both sides.

**Top-level options** (from `config.nix`):

| Option | Type | Default | Notes |
|--------|------|---------|-------|
| `omarchy.username` | str | required | Login user |
| `omarchy.full_name` | str | required | Identity |
| `omarchy.email_address` | str | required | Identity |
| `omarchy.theme` | enum (22 themes + glats) | `tokyo-night` | Drives dconf + GTK + walker |
| `omarchy.monitors` | listOf str | `[]` | Hyprland `monitor =` |
| `omarchy.scale` | int | 2 | Display scale |
| `omarchy.browser` | enum `chromium`/`brave` | `chromium` | Drives `$browser` var |
| `omarchy.terminal` | enum `ghostty`/`alacritty`/`kitty` | `ghostty` | Drives `$terminal` var |
| `omarchy.quick_app_bindings` | listOf str | 18 webapp + 9 app binds | `SUPER+SHIFT+F` → `$fileManager` |
| `omarchy.seamless_boot` | submodule | `{}` | Plymouth + auto-login |
| `omarchy.office_suite.enable` | bool | false | Adds `libreoffice-fresh` |
| `omarchy.gaming` | submodule (10 sub-flags) | `{}` | Steam, Heroic, Lutris, etc. |
| `omarchy.nvidia.enable` | bool | false | GPU driver |
| `omarchy.fido2_auth` | submodule | `{}` | U2F / fingerprint |
| `omarchy.firewall` | submodule | `{}` | allow_ssh, allowed_tcp_ports, etc. |
| `omarchy.voxtype.enable` | bool | false | Dictation |
| `omarchy.wifi.backend` | enum `nm-iwd`/`standalone-iwd` | `nm-iwd` | iwd standalone mode |
| `omarchy.hardware` | submodule | `{}` | asus_b9406, asus_z13, intel_ptl_fred |
| `omarchy.light_theme_detection` | submodule | `{}` | Auto light/dark switch |
| `omarchy.primary_font` | str | `Liberation Sans 11` | (unused?) |

**Pattern**: every opt-in feature (office, gaming, voxtype, nvidia,
fido2) is a bool submodule with `enable = false` default.

### 1.2 Where packages are defined (the answer to the user's question)

**Single source of truth**: `modules/packages.nix` (148 lines).

```nix
# modules/packages.nix (excerpt)
{ systemPackages = with pkgs; [
    # Base system tools
    git vim libnotify pavucontrol brightnessctl ffmpeg
    nautilus                                          # line 17
    hyprshot hyprpicker hyprsunset
    alejandra pamixer playerctl
    bibata-cursors gnome-themes-extra blueman         # line 25-26
    clipse xdg-utils xdg-terminal-exec

    # Terminal emulators
    ghostty alacritty kitty

    # Screenshot and recording
    satty wf-recorder gpu-screen-recorder slurp

    # Audio
    wiremix swayosd swaybg

    # Shell tools
    fzf zoxide ripgrep eza fd jq curl unzip wget gnumake

    # TUIs
    lazygit lazydocker btop powertop fastfetch gum
    bluetui impala inxi

    # Screensaver
    terminaltexteffects

    # GUIs
    (if cfg.browser == "brave" then brave else chromium)
    obsidian vlc mpv gnome-calculator loupe            # line 83-84
    krita pinta xournalpp localsend

    # Video
    obs-studio
  ]
  ++ lib.optionals (pkgs ? kdenlive) [ kdenlive ]
  ++ lib.optionals cfg.office_suite.enable [ libreoffice-fresh ]
  ++ lib.optionals cfg.voxtype.enable [ voxtype wtype ]
  ++ [
    signal-desktop typora dropbox spotify
    github-desktop gh
    docker-compose docker-buildx
    mariadb.client postgresql.lib
    ffmpegthumbnailer sushi                          # line 129-130
    gnome-keyring libsecret                          # line 133-134
    kdePackages.qtwayland kdePackages.qtstyleplugin-kvantum
  ];
}
```

**How it is consumed** (in `modules/nixos/system.nix:133`):
```nix
environment.systemPackages = packages.systemPackages ++ [
  inputs.walker.packages.${pkgs.stdenv.hostPlatform.system}.default
  elephantCombined
];
```

There is **no separate `defaultPackages`/`extraPackages`/`minimal` mode**
in omarchy-nix. It's "all or nothing". Opt-ins are
`lib.optionals` per-feature.

### 1.3 GNOME packages currently shipped by omarchy-nix

| Package | Where in `modules/packages.nix` | Notes |
|---------|-------------------------------|-------|
| `nautilus` | line 17 | Primary file manager (`SUPER+SHIFT+F`) |
| `gnome-themes-extra` | line 25 | Adwaita/Adwaita-dark for libadwaita |
| `gnome-calculator` | line 83 | `SUPER+R` + `XF86Calculator` |
| `loupe` | line 84 | Modern GNOME image viewer |
| `sushi` | line 130 | Nautilus spacebar previewer |
| `ffmpegthumbnailer` | line 129 | Video thumbs in Nautilus |
| `gnome-keyring` | line 133 | Service enabled in `system.nix:208` |
| `libsecret` | line 134 | Required by Remmina, Brave, flatpak |
| `pavucontrol` | line 14 | GNOME volume control |
| `blueman` | line 26 | GNOME bluetooth (autostart hidden) |
| `evince` | `modules/home-manager/evince.nix` → `home.packages` | PDF viewer (HM not system) |

**Total: 11 GNOME-origin packages, all already on t14 through
omarchy-nix.**

### 1.4 GNOME packages NOT in omarchy-nix (but in upstream Arch)

From sibling exploration
[`exploration-omarchy-gnome.md`](./exploration-omarchy-gnome.md):

| App | In Arch Omarchy? | In omarchy-nix? | Tier 1/2/3 |
|-----|------------------|-----------------|------------|
| `gnome-disk-utility` | **YES** | **NO (dropped)** | **Tier 1 (port fix)** |
| `gnome-system-monitor` | NO | NO | Tier 1 (t14 deviation) |
| `gnome-control-center` | NO | NO | Tier 2 (opt-in) |
| `gnome-screenshot` | NO (satty instead) | NO | Tier 3 |
| `gnome-terminal` | NO (ghostty/etc.) | NO | Tier 3 |
| `gnome-console` | NO | NO | Tier 3 |
| `gnome-calendar` | NO (HEY webapp) | NO | Tier 3 |
| `gnome-text-editor` | NO (nvim) | NO | Tier 3 |

### 1.5 Where omarchy-nix exposes package list / doesn't expose it

omarchy-nix does **NOT** expose a `omarchy.packages` option that lets
the consumer add to the list. The list is hard-coded in
`modules/packages.nix`. The only opt-ins are boolean submodules
(`office_suite.enable`, `gaming.*.enable`, `voxtype.enable`, `nvidia.enable`).

This is a **deliberate design choice** per CLAUDE.md:

> "Stay as close as possible to Omarchy. Mirror the original
> implementation unless absolutely necessary to deviate."

So the "split" question is really: **what 1-2 GNOME apps belong in
omarchy-nix's hard-coded list vs what the consumer adds to
`environment.systemPackages` in their host config**.

---

## 2. t14 Nautilus Dark Mode — All Config Locations (with line numbers)

### 2.1 The actual problem being solved

Nautilus (libadwaita 1.8.x) on Hyprland needs:
1. `org.freedesktop.portal.Settings` D-Bus interface to be **registered**
   (xdg-desktop-portal-gtk must be in the portal stack)
2. The patched xdg-desktop-portal that **allows non-flatpak callers**
3. GTK4 `settings.ini` to contain `gtk-interface-color-scheme=dark` (string)
4. dconf `org/gnome/desktop/interface` `color-scheme = prefer-dark`

### 2.2 Every file that touches Nautilus dark mode

| File:line | Config | Why needed |
|-----------|--------|-----------|
| `patches/xdg-desktop-portal/settings-allow-unsandboxed.patch` (30 lines) | nixpkgs overlay patch | xdp 1.20+ refuses Settings.Read from non-flatpak callers (no `/proc/PID/root/.flatpak-info`). Hyprland apps (incl. Nautilus) are NOT flatpak. |
| `hosts/t14/default.nix:82-90` | `nixpkgs.overlays` applying the patch | Loads the patch above into the system |
| `hosts/t14/default.nix:151-172` | `xdg.portal.extraPortals` (system-level) | Writes a custom `gtk.portal` file with `UseIn=gnome;hyprland` so the portal uses gtk backend for Settings interface |
| `hosts/t14/default.nix:174-180` | `xdg.portal.config.hyprland` (with `lib.mkForce`) | Forces `default = [ "hyprland" "gtk" ]` and `org.freedesktop.impl.portal.Settings` → `gtk` |
| `hosts/t14/default.nix:217-227` | `xdg.portal.extraPortals` (HM-level) | **CRITICAL**: HM's xdg.portal module sets `NIX_XDG_DESKTOP_PORTAL_DIR` to user profile, so the system-level .portal is invisible to the running portal. Re-deploys the same .portal to user profile. |
| `hosts/t14/home/omarchy.nix:160` | `gtk.colorScheme = "dark"` | HM GTK3+GTK4 dconf color-scheme |
| `hosts/t14/home/omarchy.nix:164` | `gtk.gtk4.extraConfig."gtk-interface-color-scheme" = "dark"` | **CRITICAL FIX**: HM 26.05 writes `gtk-interface-color-scheme=2` (integer) but GTK4 wants `"dark"` (string). Without this, libadwaita ignores the preference. |
| `hosts/t14/home/omarchy.nix:151-154` | `gtk.iconTheme = { name = "Papirus-Dark"; … }` | Omarchy doesn't set icon theme; t14 overrides for Papirus consistency |

### 2.3 t14 Hyprland binding for Nautilus

| File:line | Config |
|-----------|--------|
| `hosts/t14/home/hypr/bindings.nix:43` | `bindd = SUPER ALT SHIFT, F, File manager (cwd), exec, uwsm-app -- nautilus --new-window "$(omarchy-cmd-terminal-cwd)"` |

**Note**: t14 mirrors upstream omarchy-nix's `SUPER+SHIFT+F` →
`$fileManager` binding (defined in
`modules/home-manager/hyprland/configuration.nix:20` as
`"~/.local/share/omarchy/bin/omarchy-launch-or-focus nautilus
'nautilus --new-window'"`). The `SUPER+ALT+SHIFT+F` binding in t14
opens Nautilus in the current working directory — a t14-only addition
that omarchy-nix doesn't have.

### 2.4 What omarchy-nix already provides (no t14 override needed)

omarchy-nix already does the following for Nautilus dark mode out of
the box (so t14 does NOT need to repeat them):

| File:line | What omarchy-nix does |
|-----------|----------------------|
| `modules/packages.nix:25` | Installs `gnome-themes-extra` (Adwaita/Adwaita-dark) |
| `modules/home-manager/default.nix:232-234` | `dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark"` |
| `modules/home-manager/default.nix:240-243` | `gtk.theme = { name = "Adwaita-dark"; package = pkgs.gnome-themes-extra; }` |
| `modules/home-manager/default.nix:239` | `gtk4.theme = null` (silences HM warning; t14 needs to set it explicitly because the fix below) |
| `modules/nixos/hyprland.nix:48` | `xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ]` (installs the portal implementation, but the .portal file is auto-generated without `UseIn=…`) |
| `modules/nixos/hyprland.nix:50-51` | `xdg.portal.config.hyprland.default = [ "hyprland" "gtk" ]` (same setting t14 mkForces) |

### 2.5 The user's stated custom dark mode config to preserve

The user said: **"they have custom nautilus dark mode config that must
be preserved"**. The current custom config is the t14-only deltas
above, namely:

1. `patches/xdg-desktop-portal/settings-allow-unsandboxed.patch` (NixOS-side patch)
2. `hosts/t14/default.nix:82-90` (overlay that loads the patch)
3. `hosts/t14/default.nix:151-180` + `217-227` (custom .portal file with `UseIn=gnome;hyprland` at both system and HM levels)
4. `hosts/t14/home/omarchy.nix:160-164` (HM GTK4 string fix for `gtk-interface-color-scheme`)
5. `hosts/t14/home/omarchy.nix:151-154` (Papirus-Dark icon theme override)

**Items 1, 3, 4 are t14-internal workarounds for upstream omarchy
limitations. They MUST stay in the NixOS config** — pushing them to
omarchy-nix would be a behavior change for ALL omarchy-nix users
(currently 1: glats), not a benefit.

---

## 3. Recommended Split (What Goes Where)

### 3.1 What SHOULD be pushed to `omarchy-nix` (upstream of t14)

Based on the "stay as close to Omarchy as possible" CLAUDE.md
principle and the tier analysis in the sibling exploration:

| Package | Why push to omarchy-nix |
|---------|------------------------|
| `gnome-disk-utility` | **Already in upstream Arch Omarchy** (omarchy-nix dropped it accidentally). This is a **port fix**, not a deviation. Matches CLAUDE.md principle #1. |

**That's the only package that should be pushed upstream.**

### 3.2 What SHOULD STAY in the NixOS config (t14-specific deviations)

| Item | Why stay in NixOS |
|------|-------------------|
| `gnome-system-monitor` | **Not in upstream Arch Omarchy**. It's a t14 deviation. The user wants it but it's not part of the Omarchy set. Goes in `hosts/t14/default.nix` `environment.systemPackages` (or a new t14-specific profile). |
| `patches/xdg-desktop-portal/settings-allow-unsandboxed.patch` | t14-specific patch (omarchy-nix upstream may not need it if it relies on gdm/X11). Stay as `nixpkgs.overlays` in `hosts/t14/default.nix`. |
| Custom `gtk.portal` with `UseIn=gnome;hyprland` | t14-specific portal override. Upstream omarchy-nix's `extraPortals = [ xdg-desktop-portal-gtk ]` is correct for gdm/X11 but Hyprland needs the explicit `UseIn=`. Stay as t14 override. |
| `xdg.portal.config.hyprland` `lib.mkForce` overrides | t14 needs `gtk` in default for Nautilus Settings. Omarchy-nix already sets this to `[ "hyprland" "gtk" ]`, but t14 needs `lib.mkForce` because the HM module tries to override it. Stay as t14 override (already there). |
| `xdg.portal.extraPortals` (HM-level, `home-manager.users.glats`) | t14-specific because HM's xdg.portal module sets `NIX_XDG_DESKTOP_PORTAL_DIR` to user profile, so the system-level .portal is invisible. Upstream omarchy-nix doesn't use HM-integrated xdg-portal the same way. Stay as t14 override. |
| `gtk.gtk4.extraConfig."gtk-interface-color-scheme" = "dark"` (HM) | HM 26.05 bug. t14-specific fix. Could be pushed upstream as a `omarchy.gtk4_color_scheme` opt-in, but it's tiny (1 line) and only relevant for the few users on HM 26.05. Stay as t14 override. |
| `gtk.iconTheme = { name = "Papirus-Dark"; … }` (HM) | User preference (t14 only). Stay. |
| `bindd = SUPER ALT SHIFT, F, File manager (cwd), exec, uwsm-app -- nautilus …` | t14-only binding. Not in upstream omarchy. Stay. |

### 3.3 What should be DELETED from the NixOS config (duplicates of omarchy-nix)

These packages/services are **already provided by omarchy-nix** and
the NixOS config redundantly installs/enables them. They are
duplicates on t14 specifically:

| Duplicated item | Currently in NixOS | Already in omarchy-nix | Risk if both keep |
|-----------------|--------------------|-----------------------|-------------------|
| `gnome-themes-extra` | `modules/base/profiles/base.nix:105` | `modules/packages.nix:25` | **None** (Nix deduplicates same derivation). Dead weight in `modules/base/profiles/base.nix` only. |
| `libsecret` | `modules/base/profiles/base.nix:92` | `modules/packages.nix:134` | None. Dead weight. |
| `services.gnome.gnome-keyring.enable = true` | `modules/hardware/keyring.nix:11` | `modules/nixos/system.nix:208` | **Idempotent** (NixOS option resolves to true either way). But `modules/hardware/keyring.nix` also sets `security.pam.services.{lightdm,login,xrdp-sesman,sshd}.enableGnomeKeyring = true` — those are MATE/XRDP-specific and **must stay**. |

**Proposed action**: For t14 (which imports omarchy-nix), the
`gnome-themes-extra` and `libsecret` lines in
`modules/base/profiles/base.nix` could be removed (they're already in
omarchy-nix). But the same `modules/base/profiles/base.nix` is also
used by rog/thinkcentre (which do NOT use omarchy-nix), so these
duplications are **necessary** at the base profile level.

**Cleaner solution**: leave `modules/base/profiles/base.nix` alone
(both rog/thinkcentre need it). Accept the duplicate in Nix store
output (Nix deduplicates by hash). The duplication is a ~0 cost
cosmetic issue.

**Better solution** (from the parent exploration, Approach A): split
`modules/base/profiles/base.nix` into:
- `modules/base/profiles/shared.nix` (CLI utilities, networking — both suites use)
- `modules/base/profiles/mate.nix` (MATE pkgs + materia-theme)
- `modules/base/profiles/gnome.nix` (`gnome-themes-extra` + `libsecret` + adwaita-icon-theme + keyring)

Then each host declares `my.desktop.suite = "mate" | "gnome";` and the
matching profile is composed. This is the parent change's recommended
approach.

### 3.4 Does omarchy-nix need a new option for t14?

**For the GNOME-apps split (Tier 1 + Tier 2):** No. Just adding
`gnome-disk-utility` to `modules/packages.nix:25` (next to
`gnome-themes-extra`) is the minimal change. It follows the
"hard-coded systemPackages" pattern that omarchy-nix already uses.

**If we want to make `gnome-disk-utility` opt-in** (Tier 2, mirroring
`office_suite.enable`): then yes, we'd add a new
`omarchy.gnome_apps.enable` (or `omarchy.disk_utility.enable`)
submodule. But this adds API surface for one package. Recommendation:
**don't add the option, just add the package to the main list.**

**If we want a `my.desktop.suite` option in nixos-hosts** (parent
change's Approach A): that's separate. It controls which
`modules/base/profiles/*.nix` is composed for the host, not
omarchy-nix's options. They're orthogonal — t14 has both
`my.desktop.suite = "gnome";` (NixOS side) AND consumes omarchy-nix
(which already includes GNOME apps in its baseline).

### 3.5 Overlap summary (final)

| Item | Source of truth (today) | After split |
|------|------------------------|-------------|
| `nautilus` | omarchy-nix `modules/packages.nix:17` | omarchy-nix (unchanged) |
| `gnome-themes-extra` | BOTH (`modules/base/profiles/base.nix:105` + omarchy-nix) | omarchy-nix only (parent change de-dupes via `gnome.nix` profile) |
| `libsecret` | BOTH | omarchy-nix only (parent change de-dupes) |
| `gnome-keyring` | BOTH (system service) | omarchy-nix (system service); NixOS keeps PAM config (MATE/XRDP specific) |
| `gnome-calculator` | omarchy-nix | omarchy-nix (unchanged) |
| `loupe` | omarchy-nix | omarchy-nix (unchanged) |
| `sushi` | omarchy-nix | omarchy-nix (unchanged) |
| `ffmpegthumbnailer` | omarchy-nix | omarchy-nix (unchanged) |
| `pavucontrol` | omarchy-nix | omarchy-nix (unchanged) |
| `blueman` | omarchy-nix | omarchy-nix (unchanged) |
| `evince` | omarchy-nix (home.packages) | omarchy-nix (unchanged) |
| **`gnome-disk-utility`** | **NOT INSTALLED** | **omarchy-nix `modules/packages.nix`** (new — port fix) |
| **`gnome-system-monitor`** | **NOT INSTALLED** | **NixOS `hosts/t14/default.nix`** (t14 deviation) |
| xdg-desktop-portal patch | NixOS `patches/` | NixOS (t14-only workaround) |
| xdg.portal.extraPortals (HM) | NixOS `hosts/t14/default.nix` | NixOS (t14-only override) |
| `xdg.portal.config.hyprland` mkForce | NixOS | NixOS (t14-only override) |
| GTK4 color-scheme string fix | NixOS `hosts/t14/home/omarchy.nix:164` | NixOS (HM 26.05 bug workaround) |
| Papirus-Dark icon theme | NixOS `hosts/t14/home/omarchy.nix:151-154` | NixOS (user preference) |
| `SUPER+ALT+SHIFT+F` Nautilus cwd | NixOS `hosts/t14/home/hypr/bindings.nix:43` | NixOS (t14-only binding) |

**Net: 1 package (`gnome-disk-utility`) pushed upstream to omarchy-nix.
1 package (`gnome-system-monitor`) added to t14 host config. All
existing t14 workarounds preserved.**

---

## 4. Affected Areas

### 4.1 omarchy-nix repo (changes)

| File | Change |
|------|--------|
| `modules/packages.nix` | Add `gnome-disk-utility` next to `gnome-themes-extra` (line ~26) — single-line addition. |
| `flake.lock` (in nixos-hosts) | Auto-updated by `nix flake update omarchy-nix` after the upstream PR is merged. |

### 4.2 nixos-hosts repo (changes)

| File | Change |
|------|--------|
| `hosts/t14/default.nix` | Add `gnome-system-monitor` to `environment.systemPackages` (or to a new `modules/base/profiles/gnome.nix` if parent change's Approach A is taken). |
| `hosts/t14/home/hypr/looknfeel.nix` (optional) | Add window rule to make `gnome-disk-utility` and `gnome-system-monitor` float (they're typically dialog-like). Pattern matches omarchy's `default/hypr/apps/system.conf:6-8`. |
| `flake.lock` | Auto-updated when the upstream omarchy-nix is bumped. |
| `modules/hardware/keyring.nix` | NO change (still needed for MATE/XRDP hosts; harmless duplicate on t14). |
| `patches/xdg-desktop-portal/settings-allow-unsandboxed.patch` | NO change (preserves the custom dark mode fix). |
| `hosts/t14/home/omarchy.nix:160-164` | NO change (preserves the GTK4 color-scheme string fix). |
| `hosts/t14/home/hypr/bindings.nix:43` | NO change (preserves the t14-only cwd binding). |

---

## 5. Risks

- **Upstream sync drift**: omarchy-nix is an "active porting project"
  (per CLAUDE.md) that periodically rebases against
  `basecamp/omarchy`. If upstream Arch Omarchy adds another GNOME app
  that omarchy-nix drops (e.g. `gnome-text-editor`), the same
  "is-it-in-Arch?" check needs to be repeated. The
  `sdd/omarchy-arch-to-nixos-drift` change (per Engram #152) appears
  to already track this; the new `gnome-disk-utility` add fits
  naturally into that change or as a separate one-line PR.

- **Hyprland window rule conflict**: The proposed Hyprland float rule
  for `gnome-disk-utility` and `gnome-system-monitor` should be added
  to `hosts/t14/home/hypr/looknfeel.nix` (not `default/hypr/apps/`).
  Reason: omarchy-nix's `default/hypr/apps/system.conf` is
  *deployed as-is* via `home.file` (no per-host override mechanism);
  t14 needs to add (not replace) the rules.

- **Double-install of `gnome-themes-extra` and `libsecret`** in
  `modules/base/profiles/base.nix` is cosmetic. Removing them
  requires the parent change's `gnome.nix` profile to be created
  first. Without that, rog/thinkcentre would lose them.

- **HM 26.05 `gtk-interface-color-scheme` string fix** is brittle —
  if HM upstream fixes the bug in 26.06, the `gtk.gtk4.extraConfig`
  override may stop being needed (or may start conflicting). The
  proposal phase should not push this to omarchy-nix upstream (too
  HM-version-specific).

- **Patched xdg-desktop-portal** is an in-repo patch that needs to be
  re-applied on every nixpkgs bump (or it silently breaks the dark
  mode). This is fragile but unavoidable until upstream
  xdg-desktop-portal accepts a `ALLOW_UNSANDBOXED` env var. Not in
  scope for this change.

---

## 6. Ready for Proposal

**Yes.** The split is clear:

1. **Push to omarchy-nix**: `gnome-disk-utility` (one-line add to
   `modules/packages.nix`). Rationale: it's in upstream Arch Omarchy
   and was dropped accidentally in the port. CLAUDE.md mandates
   matching upstream unless there's a reason to deviate.
2. **Add to t14 host config**: `gnome-system-monitor` (one-line add
   to `hosts/t14/default.nix` `environment.systemPackages`, or to a
   new `modules/base/profiles/gnome.nix` if parent change's Approach
   A is taken). Rationale: t14 deviation, not in upstream.
3. **Preserve all existing t14 dark mode workarounds**: the patch,
   the `UseIn=gnome;hyprland` .portal file, the GTK4 string fix, the
   Papirus-Dark override, the `SUPER+ALT+SHIFT+F` cwd binding. None
   of these should move upstream.
4. **No new option needed in omarchy-nix**. The current pattern of
   hard-coded `systemPackages` works for one Tier 1 add.

### 6.1 Recommended delivery plan

| Step | Repo | Effort | Type |
|------|------|--------|------|
| 1. Open PR against `omarchy-nix` adding `gnome-disk-utility` to `modules/packages.nix` | omarchy-nix | 1 line + 1 line test in CLAUDE.md sync section | Upstream PR |
| 2. Wait for omarchy-nix merge, then `nix flake update omarchy-nix` in nixos-hosts | nixos-hosts | 0 lines | Lock bump |
| 3. Add `gnome-system-monitor` to t14 host config | nixos-hosts | 1-5 lines | Local |
| 4. (Optional) Add Hyprland float rules for both new apps in `looknfeel.nix` | nixos-hosts | 5-10 lines | Local |
| 5. Run `nix flake check --no-build` + `format-nix` | nixos-hosts | 0 lines | Validation |

**Estimated diff**: 1 line in omarchy-nix + 1-5 lines in nixos-hosts
+ 5-10 lines optional Hyprland rules. Well under the 400-line single-PR
budget. **No chained PRs needed.**

### 6.2 Open questions to resolve in the proposal phase

1. **Confirm `gnome-disk-utility` push to omarchy-nix upstream**: the
   CLAUDE.md principle strongly supports it (it IS in upstream Arch
   Omarchy). But the user may prefer a one-PR approach (everything in
   nixos-hosts) to avoid the upstream-PR latency.
2. **Tier 2 `gnome-control-center`**: not proposed for omarchy-nix
   (heavy dependency tree, omarchy's design is TUI). The user can
   decide to add it locally on t14 if desired.
3. **Should the Hyprland float rules for new apps be in
   `looknfeel.nix` (t14 override) or in the upstream
   `default/hypr/apps/system.conf` (omarchy-nix)**? Recommended:
   t14 override (per-host, easier to revert).
4. **Should `gnome-system-monitor` go in `environment.systemPackages`
   directly in `hosts/t14/default.nix` or in a new
   `modules/base/profiles/gnome.nix` consumed via
   `my.desktop.suite = "gnome"`?** Recommended: depends on whether
   the parent change's Approach A is adopted. If yes, use
   `modules/base/profiles/gnome.nix` (cleaner). If no, inline in
   `hosts/t14/default.nix`.

---

## 7. Relevant Files

- `/home/glats/.nixos/sdd/changes/host-desktop-suite-separation/exploration.md` — parent exploration (suite split)
- `/home/glats/.nixos/sdd/changes/host-desktop-suite-separation/exploration-omarchy-gnome.md` — sibling (what GNOME apps)
- `/home/glats/.nixos/sdd/changes/host-desktop-suite-separation/exploration-omarchy-split.md` — this file (the split)
- `/home/glats/.nixos/flake.nix:19-23, 212-215` — omarchy-nix input declaration + wiring
- `/home/glats/.nixos/flake.lock` — pinned revision `d6f01639b552b9f0ad29946bf2b2401a81ce1842`
- `/home/glats/.nixos/hosts/t14/default.nix` — t14 host config (portal patches, gtk.portal override, HM extraPortals)
- `/home/glats/.nixos/hosts/t14/home/omarchy.nix:151-164` — GTK4 color-scheme string fix + Papirus icon theme
- `/home/glats/.nixos/hosts/t14/home/hypr/bindings.nix:43` — t14-only Nautilus cwd binding
- `/home/glats/.nixos/patches/xdg-desktop-portal/settings-allow-unsandboxed.patch` — Settings portal auth bypass
- `/home/glats/.nixos/modules/hardware/keyring.nix` — MATE/XRDP gnome-keyring (stays for non-omarchy hosts)
- `/home/glats/.nixos/modules/base/profiles/base.nix:92, 105` — duplicated `libsecret` + `gnome-themes-extra`
- `/home/glats/.nixos/home-linux/theme.nix:19, 46, 55, 59` — dark mode dconf + GTK3/4 prefer-dark + Qt adwaita-dark (MATE hosts only)
- `/home/glats/.nixos/lib/mkHost.nix` — host builder (no change)
- `/tmp/opencode/omarchy-nix/flake.nix` — module output declarations
- `/tmp/opencode/omarchy-nix/config.nix` — all `omarchy.*` options
- `/tmp/opencode/omarchy-nix/modules/packages.nix` — the single package list (148 lines)
- `/tmp/opencode/omarchy-nix/modules/nixos/system.nix:208` — `services.gnome.gnome-keyring.enable = true`
- `/tmp/opencode/omarchy-nix/modules/nixos/hyprland.nix:46-51` — `xdg.portal.extraPortals = [ gtk ]`
- `/tmp/opencode/omarchy-nix/modules/home-manager/default.nix:232-249` — dconf `color-scheme` + GTK Adwaita-dark
- `/tmp/opencode/omarchy-nix/modules/home-manager/hyprland/configuration.nix:20` — `$fileManager = nautilus` var
- `/tmp/opencode/omarchy-nix/modules/home-manager/hyprland/bindings.nix` (config.nix:183) — `SUPER+R` → gnome-calculator
- `/tmp/opencode/omarchy-nix/default/hypr/apps/system.conf:6-8` — Hyprland float rules for GNOME classes
- `/tmp/opencode/omarchy-nix/CLAUDE.md` — "Stay as close to Omarchy as possible" principle
