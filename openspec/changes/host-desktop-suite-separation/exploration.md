# Exploration: Host Desktop Suite Separation

**Change**: Separate desktop environments per host — no overlap.
- t14: GNOME suite ONLY (NOT MATE)
- rog + thinkcentre: MATE suite ONLY (NOT GNOME)
- No package overlap between hosts

**Date**: 2026-06-27
**Project**: nixos-hosts
**Artifact type**: exploration (architecture)

---

## Current State

### Profile chain (system-level)

`modules/profiles/base.nix` (25 lines) is the entry profile. Its only
content is an `imports = [ ... ]` block. The chain is:

```
base.nix  →  desktop.nix  →  server.nix
```

Concrete contents:

| File | Imports |
|------|---------|
| `modules/profiles/base.nix` | base/{cachix,dconf,home-manager,logind,nh,nix,packages,polkit,shutdown-fix,sops,users,zsh}, networking/{avahi,firewall,openssh}, features/boot |
| `modules/profiles/desktop.nix` | base.nix + desktop/{fonts,i18n,kmscon}, hardware/keyring |
| `modules/profiles/server.nix` | desktop.nix + features/services/{xrdp,github-mcp-server}, networking/wol, virtualisation/docker |

The big coupling: **`modules/profiles/desktop.nix` always pulls in
`modules/base/packages.nix` (transitively via base.nix) and
`modules/hardware/keyring.nix` (directly)**, which together install
MATE-suite packages, `gnome-themes-extra`, `gnome-keyring`, and the
`org/gnome/desktop/interface` dconf settings.

### Package profile (`modules/base/profiles/base.nix`, 122 lines)

This file is the package list the user needs to split. It contains
multiple categories — some host-agnostic, some suite-specific:

| Category | Lines | Host-agnostic? |
|----------|-------|----------------|
| MATE suite (`atril caja engrampa eom marco pluma mate-panel mate-sensors-applet mate-user-share`) | 10-19 | NO — MATE-only |
| CLI utilities (fzf, bat, git, htop, …) | 21-87 | YES |
| Desktop misc (libsecret, dex, google-cloud-sdk) | 89-94 | YES |
| `ghostty windsurf flatpak meld xdg-user-dirs` | 96-101 | YES |
| `hicolor-icon-theme` | 102 | YES |
| `papirus-icon-theme` | 103 | YES (used by all) |
| `materia-theme` | 104 | NO — MATE-only (theme.nix depends on it) |
| **`gnome-themes-extra`** | 105 | **NO — GNOME-suite icon support** |
| `gtk-engine-murrine` | 106 | YES (theme dep) |
| **`adwaita-icon-theme`** | 107 | **Borderline — GNOME icon theme, but used by t14 GTK dark mode** |
| `flameshot copyq gpaste conky networkmanagerapplet gparted hexchat popsicle hypridle remmina` | 108-117 | MIXED |
| `asus-fan-control pipewire-module-xrdp` | 119-121 | YES (rog uses asus-fan; thinkcentre uses xrdp audio) |

### Per-host desktop configuration

**rog** (`hosts/rog/default.nix`)
- Imports: `modules/profiles/server.nix` (full chain: base+desktop+server)
- HM: `hosts/rog/home/modules.nix` → `home-linux/shared-modules.nix` (includes `mate.nix`) + `remote-desktop.nix` + `picom.nix` + `mate-rog-autostart.nix` + `conky-rog.nix` + `openfang.nix`
- Desktop: MATE via XRDP. `modules/features/services/xrdp.nix:127` sets
  `services.xserver.desktopManager.mate.enable = true` and runs
  `${pkgs.mate-session-manager}/bin/mate-session` in the xrdp
  per-display script.

**thinkcentre** (`hosts/thinkcentre/default.nix`)
- Imports: same as rog (server profile chain)
- HM: `hosts/thinkcentre/home/modules.nix` → `home-linux/shared-modules.nix` (includes `mate.nix`) + `remote-desktop.nix` + `picom.nix` + `conky-thinkcentre.nix`
- Desktop: MATE via XRDP (same path as rog)

**t14** (`hosts/t14/default.nix`)
- Imports: **`modules/profiles/server.nix` is NOT imported**. t14 hand-imports a subset of `modules/base/*.nix` (cachix, nix, polkit, sops, users, zsh, packages) plus `modules/desktop/{i18n,fonts,kmscon}` plus `modules/hardware/{amd-laptop,keyring}` plus `modules/features/boot.nix` plus `modules/features/services/github-mcp-server.nix` plus `modules/virtualisation/docker.nix`.
- HM: `hosts/t14/home/omarchy.nix` — does NOT use `home-linux/shared-modules.nix`. Imports `inputs.omarchy-nix.homeManagerModules.default` + a curated list of compatible shared modules (base, shell, tmux, neovim, git, gh, ssh, remote-desktop, shell-aliases, opencode, sops). **Explicitly excludes** `mate.nix`, `rofi.nix`, `theme.nix`, `chrome-apps.nix`.
- Desktop: Hyprland (via `inputs.omarchy-nix.nixosModules.default` wired in `flake.nix:212-215`).
- `modules/base/packages.nix` IS imported on t14 → t14 currently installs
  **MATE packages from `modules/base/profiles/base.nix` even though no
  MATE config exists in HM**. This is the root overlap.

### MATE-suite — all references

| File:line | Reference | Applies to | Overlap on t14? |
|-----------|-----------|------------|-----------------|
| `modules/base/profiles/base.nix:10-19` | MATE package list | All hosts via packages.nix | **YES** |
| `modules/base/profiles/base.nix:104` | `materia-theme` | All hosts; only `home-linux/theme.nix` consumes it (not on t14) | NO effect on t14 |
| `modules/base/dconf.nix:11-17` | `org/mate/marco` dconf lock | All hosts via base profile | YES (dconf key for an uninstalled DE) |
| `modules/features/services/xrdp.nix:34,57,127` | `mate-session-manager`, `xrdpMateSession`, `services.xserver.desktopManager.mate.enable` | rog + thinkcentre (server profile) | NO |
| `home-linux/mate.nix:14-248` | Full dconf config for caja, marco, panel, pluma, power-manager, screensaver, terminal | rog + thinkcentre (via shared-modules) | NO (omarchy.nix excludes it) |
| `home-linux/mate.nix:250-262` | `mate-terminal.desktop` xdg entry | rog + thinkcentre | NO |
| `home-linux/mate.nix:264-318` | copyq, flameshot, mate-screensaver, mate-power-manager autostart | rog + thinkcentre | NO |
| `home-linux/rofi.nix:112` | `terminal = "mate-terminal"` | rog + thinkcentre (via shared-modules) | NO (t14 uses walker, not rofi) |
| `home-linux/mate-rog-autostart.nix` | hexchat autostart | rog only | NO |
| `home-linux/shared-modules.nix:24` | `./mate.nix` import | All Linux HM via flake.nix / home-manager.nix | NO (t14 uses its own list) |
| `overlays/linux.nix:48-54` | `libmateweather` METAR pointer patch | All hosts (compile-time) | YES (t14 compiles it) |
| `pkgs/nixos-scripts/default.nix:42-43` | `export-mate-config` helper script | All hosts (binary in nixos-scripts) | YES (binary available on t14) |
| `hosts/rog/home/modules.nix:10` | `./mate-rog-autostart.nix` | rog only | NO |
| `hosts/t14/home/omarchy.nix:19` | comment: "mate (GNOME/MATE only — incompatible with Hyprland)" | t14 doc | (n/a) |

**Net t14 MATE footprint today (system packages only, no HM config):**
`atril caja engrampa eom marco pluma mate-panel mate-sensors-applet mate-user-share` (9 packages) + `libmateweather` (overlaid) + the dconf lock for `org/mate/marco/compositing-manager` is silently set even though t14 has no `marco`.

### GNOME-suite — all references

The "GNOME suite" footprint in the repo is small — there is **no full
GNOME DE** installed on any host today. The references are limited to
a few helper packages and keyring:

| File:line | Reference | Applies to | Needed on t14? | Needed on rog/thinkcentre? |
|-----------|-----------|------------|----------------|-----------------------------|
| `modules/hardware/keyring.nix:6,11,14-17` | `gnome-keyring` package + `services.gnome.gnome-keyring.enable` + PAM wiring for lightdm/xrdp-sesman/sshd | All hosts (keyring is in `modules/profiles/desktop.nix`) | YES (for Remmina libsecret) | YES (for Remmina libsecret) |
| `modules/base/profiles/base.nix:105` | `gnome-themes-extra` (legacy Adwaita/Icons theme fallback) | All hosts | Borderline (used by Nautilus in libadwaita) | NO (no GTK4 apps that need it) |
| `home-linux/theme.nix:58` | `dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark"` | All Linux HM via shared-modules | NO (omarchy.nix sets its own) | YES |
| `home-linux/remote-desktop.nix:8,13` | docs referencing gnome-keyring (no config) | All Linux HM | n/a | n/a |
| `modules/features/services/xrdp.nix:74,77` | gnome-keyring pattern in shell exclude list (xrdp cleanup) | rog + thinkcentre (server profile) | NO | YES |
| `hosts/t14/default.nix:10,35,169,224` | comments + `UseIn=gnome;hyprland` in xdg.portal portal file | t14 | (string match, not a package) | n/a |
| `hosts/t14/home/omarchy.nix:3,15,59` | comments referring to previous `gnome.nix` | t14 doc | (n/a) | (n/a) |
| `hosts/t14/home/hypr/bindings.nix:43` | `nautilus --new-window` exec binding | t14 | YES (Nautilus already on PATH because of `gnome-themes-extra`? No — Nautilus is not currently in package list) | NO |

**Important gap**: t14 binds a `nautilus` exec but `nautilus` is **not
currently in the package list**. This is a latent bug independent of
this change.

### Dependency graph (system + HM)

```
                                    ┌──────────────────────────────────────────────┐
                                    │ modules/profiles/                            │
                                    │                                              │
                                    │  base.nix ─┐                                 │
                                    │            ├─ desktop.nix ─┐                 │
                                    │            │                ├─ server.nix     │
                                    │            │                │   (xrdp, wol,  │
                                    │            │                │    docker,      │
                                    │            │                │    gh-mcp)      │
                                    │            │                │                │
                                    │            ▼                ▼                │
                                    │  ┌─ modules/base/packages.nix               │
                                    │  │   → profiles/{base,dev,media,virt,browsers}
                                    │  │     ┌─ profiles/base.nix                  │
                                    │  │     │  has MATE pkgs + gnome-themes-extra  │
                                    │  │     │  + materia-theme                   │
                                    │  │     └─ …                                 │
                                    │  └─ modules/base/dconf.nix                   │
                                    │     → marco compositing lock                │
                                    │  ┌─ modules/base/home-manager.nix            │
                                    │  │  → hosts/$hostname/home/modules.nix       │
                                    │  └─ modules/hardware/keyring.nix             │
                                    │     → gnome-keyring + service + PAM         │
                                    │  ┌─ modules/desktop/{fonts,i18n,kmscon}     │
                                    │  └─ modules/features/boot.nix                │
                                    └──────────────────────────────────────────────┘
                                                                  ▲
                                                                  │ imports
            ┌─────────────────────────────────────────────────────┼─────────────────────┐
            │                                                     │                     │
   hosts/rog/default.nix                          hosts/thinkcentre/default.nix     hosts/t14/default.nix
   ├─ server.nix                                  ├─ server.nix                     ├─ base/{cachix,nix,polkit,sops,users,zsh,packages}
   ├─ hardware/nvidia                             ├─ hardware/keyring               ├─ desktop/{i18n,fonts,kmscon}
   ├─ hardware/rog-shutdown                       ├─ networking/{wol,firewall,avahi,openssh}    ├─ hardware/{amd-laptop,keyring}
   ├─ hardware/asus-fan-control                   └─ services/maquilinux-mounts     ├─ networking/{openssh}
   ├─ base/shutdown-debug                                                            ├─ features/boot + services/github-mcp-server
   ├─ 19 services (arr, authelia, …)                                                  └─ virtualisation/docker
   └─ libvirt                                                                        
                                                                                     [NO server.nix, NO desktop.nix, NO wol, NO firewall]

            │                                                     │                     │
            ▼                                                     ▼                     ▼
   hosts/rog/home/modules.nix                       hosts/thinkcentre/home/modules.nix  hosts/t14/home/omarchy.nix
   ├─ shared-modules.nix (includes mate.nix)         ├─ shared-modules.nix (incl. mate)  ├─ inputs.omarchy-nix.homeManagerModules.default
   ├─ remote-desktop.nix                            ├─ remote-desktop.nix              ├─ t14/home/default.nix (Hyprland fragments)
   ├─ picom.nix                                     ├─ picom.nix                       └─ selective: base, shell, tmux, neovim,
   ├─ mate-rog-autostart.nix                        └─ conky-thinkcentre.nix                git, gh, ssh, remote-desktop, sops
   ├─ conky-rog.nix                                                                    
   └─ openfang.nix                                       [no MATE/gnome in HM because omarchy.nix is curated]
            │                                                     │
            ▼                                                     ▼
   ┌────────────────────────────────────────────────────────────────────────────┐
   │ home-linux/shared-modules.nix (CANONICAL — single source of truth)         │
   │   ./base, ./shell, ./theme, omarchy.btop, ./tmux, ./neovim,                │
   │   ./mate, ./rofi, ./git, ./gh, ./ghostty, ./kitty, ./alacritty,            │
   │   ../shared/{shell-aliases,opencode,opencode-profile},                     │
   │   ./chrome-apps, ./ssh, ../shared/sops, sops-nix.HM                         │
   │                                                                            │
   │  NOTE: t14 does NOT import this list — it uses its own curated list in     │
   │  hosts/t14/home/omarchy.nix to avoid pulling in mate/rofi/theme/chrome-apps│
   └────────────────────────────────────────────────────────────────────────────┘
```

### Critical overlap points (today)

| # | Overlap | Where | Why it exists today |
|---|---------|-------|---------------------|
| 1 | **MATE packages installed on t14** | `modules/base/profiles/base.nix:10-19` via `modules/base/packages.nix` imported by `hosts/t14/default.nix:28` | t14 imports `modules/base/packages.nix` directly (does not opt out of the base pkgs list) |
| 2 | **`gnome-themes-extra` installed on rog + thinkcentre** | `modules/base/profiles/base.nix:105` | Same base profile — no host-conditional split |
| 3 | **MATE dconf lock on t14** | `modules/base/dconf.nix:11-17` (org/mate/marco/compositing-manager) imported via `modules/profiles/base.nix:5` | t14 inherits the lock even though it has no marco |
| 4 | **`materia-theme` installed on t14** | `modules/base/profiles/base.nix:104` | Only consumed by `home-linux/theme.nix` which is excluded on t14 — dead weight on t14 |
| 5 | **`libmateweather` overlay compiled on t14** | `overlays/linux.nix:48-54` | Cross-host overlay applied via `flake.nix:29,119-121` |
| 6 | **`export-mate-config` script available on t14** | `pkgs/nixos-scripts/default.nix:42-43` | Bundled in `nixos-scripts` package distributed to all hosts |
| 7 | **`services.gnome.gnome-keyring.enable` on rog + thinkcentre** | `modules/hardware/keyring.nix:11` | Imported via `modules/profiles/desktop.nix:11` | The user wants "rog/thinkcentre = MATE only", so this might still be acceptable (keyring is a daemon, not a suite), but the user asked for **no package overlap** and `gnome-keyring` is a GNOME package. |
| 8 | **`rofi` on rog/thinkcentre points to `mate-terminal`** | `home-linux/rofi.nix:112` | Tight coupling; if MATE goes, rofi must change too |
| 9 | **HM `mate.nix` on rog + thinkcentre** | `home-linux/shared-modules.nix:24` → `home-linux/mate.nix` | User wants MATE ONLY on rog/thinkcentre — this is correct! No change needed. |

---

## Affected Areas

| File | Why affected |
|------|-------------|
| `modules/base/profiles/base.nix` | Contains the MATE package list (lines 10-19), `materia-theme` (104), `gnome-themes-extra` (105), `adwaita-icon-theme` (107). All of these are suite-specific. Must be split into a shared base and a per-suite list. |
| `modules/base/packages.nix` | Wires the profile pkgs into `environment.systemPackages`. Need to be able to compose shared + host-chosen suite. |
| `modules/profiles/base.nix` | The "transversal" base — must continue to work for ALL hosts, but no longer drag in MATE/GNOME suite packages. |
| `modules/profiles/desktop.nix` | Currently a one-size-fits-all import. Needs to become suite-agnostic (fonts, i18n, kmscon are shared; xserver/mate-specific stuff is not). |
| `modules/profiles/server.nix` | Imports `xrdp.nix` (which sets `services.xserver.desktopManager.mate.enable = true`). This is a MATE-specific choice. thinkcentre and rog both want MATE, so server.nix is fine, but the `mate` opt-in needs to be explicit per host. |
| `modules/features/services/xrdp.nix` | Hardcoded MATE session via `mate-session-manager` and `services.xserver.desktopManager.mate.enable` (line 127). Acceptable because rog/thinkcentre both use MATE — but the module should be renamed or wrapped in a MATE-conditional flag. |
| `modules/hardware/keyring.nix` | Installs `gnome-keyring` + `services.gnome.gnome-keyring.enable`. Required on every host for Remmina/libsecret. Decision needed: keep "keyring helper" name and treat gnome-keyring as a generic dependency, or rename to clarify it's not a "GNOME suite" package. |
| `modules/base/dconf.nix` | Sets `org/mate/marco/compositing-manager` lock for ALL hosts. Must be made MATE-only. |
| `home-linux/mate.nix` | Full MATE dconf + autostart. Already correctly scoped to rog/thinkcentre via `shared-modules.nix`. No change. |
| `home-linux/mate-rog-autostart.nix` | Rog-specific MATE autostart. No change. |
| `home-linux/rofi.nix:112` | Hardcoded `terminal = "mate-terminal"`. Must change to host-aware terminal or remove. (Decision needed — but t14 doesn't use rofi.) |
| `home-linux/shared-modules.nix` | Canonical HM list for ALL Linux hosts. The `./mate.nix` line (24) means EVERY Linux HM gets MATE dconf. **Currently t14 avoids this by using its own curated list in `hosts/t14/home/omarchy.nix`** — but if any new Linux host forgets to curate, it'll get MATE. The split must be hardened so the canonical list is safe. |
| `hosts/rog/default.nix` | Must declare "I am a MATE host" (e.g. via a new `my.desktop.suite = "mate";` option). |
| `hosts/thinkcentre/default.nix` | Same as rog. |
| `hosts/t14/default.nix` | Must declare "I am a GNOME host" (via `my.desktop.suite = "gnome";`) and stop inheriting MATE packages. |
| `hosts/t14/home/omarchy.nix` | May need to be updated if GNOME suite requires HM-side config (e.g. `org/gnome/desktop/*` dconf, or `xdg.portal.config.gnome` for Nautilus). The current "excludes mate/rofi/theme/chrome-apps" comment is still accurate. |
| `overlays/linux.nix` | `libmateweather` overlay is dead weight on t14. Decision: move the patch to a MATE-host-only overlay, or keep it as a small compile cost (1 patch, 1 package). |
| `pkgs/nixos-scripts/default.nix` | `export-mate-config` script is MATE-specific. Should be moved into the MATE suite package set, not the universal `nixos-scripts`. |
| `lib/mkHost.nix` | Builder for nixos hosts. No change needed, but documentation should mention the new `my.desktop.suite` option. |

---

## Approaches

### Approach A: Split `modules/base/profiles/base.nix` into `shared` + per-suite profiles

**Description**: Keep `modules/base/profiles/base.nix` as the
host-agnostic shared profile (CLI utilities, networking, common
desktop helpers). Create two new profiles:
- `modules/base/profiles/mate.nix` — MATE package list + materia-theme
- `modules/base/profiles/gnome.nix` — GNOME suite packages + adwaita-icon-theme

`modules/base/packages.nix` would read a new
`my.desktop.suite = "mate" | "gnome" | null;` option (defined in
`modules/profiles/base.nix` via `options`) and conditionally append
the matching profile's pkgs to `environment.systemPackages`.

Each host declares its suite:
```nix
# hosts/rog/default.nix
my.desktop.suite = "mate";

# hosts/thinkcentre/default.nix
my.desktop.suite = "mate";

# hosts/t14/default.nix
my.desktop.suite = "gnome";
```

`modules/base/dconf.nix` would similarly gate the
`org/mate/marco/compositing-manager` lock on `my.desktop.suite == "mate"`.

`modules/hardware/keyring.nix` stays cross-host (gnome-keyring is a
daemon, not a DE). Rename doc comments to clarify.

- Pros: Clean split. Single source of truth per suite. Adding a new host
  is one line of config. Matches the existing `my.*` pattern (used by
  `my.shutdownDebug.enable` on rog).
- Cons: Touches many files (~12). Requires adding a new option. The
  `my.desktop.suite` option has to be defined in a place that imports
  before `modules/base/packages.nix` and `modules/base/dconf.nix`.
- Effort: **Medium** (~80-120 changed lines)

### Approach B: Per-host direct imports

**Description**: Drop the `my.desktop.suite` indirection. Each host
imports `modules/profiles/mate.nix` (new) or `modules/profiles/gnome.nix`
(new) directly in its `default.nix`. Split `modules/profiles/base.nix`
into shared and per-suite, and let each host import what it needs.

- Pros: No new option to define. Explicit per-host. Easy to read.
- Cons: Repeats the "I want suite X" declaration across hosts. If a
  profile name is misspelled, no error. Doesn't scale to a third suite.
- Effort: **Low-Medium** (~60-90 changed lines)

### Approach C: Host-conditional packages via `lib.mkIf` in `modules/base/packages.nix`

**Description**: Read `config.networking.hostName` inside
`modules/base/packages.nix` and `lib.mkIf` the per-suite lists. No
new profile files. No new option.

- Pros: Smallest diff. No new files. Easy to grep.
- Cons: Hidden coupling. Hostname string-matching is fragile. A new
  host (mact2, a future laptop) silently gets no suite. Doesn't compose
  with the "single source of truth" pattern the repo is moving toward.
- Effort: **Low** (~30-50 changed lines)

### Comparison

| Approach | Files touched | New options | New files | Scalability | Clarity | Effort |
|----------|---------------|-------------|-----------|-------------|---------|--------|
| A (my.desktop.suite) | ~12 | 1 | 2 (mate+gnome profiles) | High (one line per new host) | High | Medium |
| B (per-host imports) | ~10 | 0 | 2 (mate+gnome profiles) | Medium | High | Low-Medium |
| C (hostname mkIf) | 1-2 | 0 | 0 | Low | Low | Low |

---

## Recommendation

**Approach A** — `my.desktop.suite` option, with a shared
`modules/base/profiles/base.nix` + two new suite profiles
(`mate.nix` + `gnome.nix`).

**Reasoning**:
1. Matches the existing `my.*` pattern already in the repo
   (`my.shutdownDebug.enable` on rog, `boot-settings` option).
2. One-line-per-host opt-in keeps every host config self-documenting.
3. The split between "shared base pkgs" and "suite pkgs" is a clean
   architectural boundary that survives future DE changes (e.g. adding
   KDE).
4. The user asked for "no overlap" — a single source of truth per
   suite makes that testable (`nix flake check --no-build` + grep).

**Open questions to resolve in the proposal phase** (cannot be answered
from code alone — need user input):

1. **What is the "GNOME suite" on t14?** Today t14 runs Hyprland via
   omarchy-nix. The user's message says "t14: GNOME suite ONLY" but
   the actual state is omarchy/Hyprland. Two readings:
   (a) Replace omarchy with a full GNOME DE (gdm + gnome-shell +
   gnome-control-center + Nautilus + GNOME Terminal + …)
   (b) Keep omarchy but install GNOME apps + `gnome-shell` libraries
   so libadwaita (Nautilus) works correctly
   This materially changes the scope.
2. **Is `gnome-keyring` still acceptable on rog/thinkcentre?** It is
   technically a GNOME package, but the user needs Remmina/libsecret
   everywhere. Recommend: keep it but rename file/comment to clarify
   it is a keyring daemon, not a suite package.
3. **`mate-terminal` in rofi.nix**: should the terminal in rofi be
   re-pointed (e.g. to `ghostty`) or kept as a MATE-suite assumption
   (since rofi is only used on MATE hosts)?
4. **`adbwaita-icon-theme`**: used by rog/thinkcentre (theme.nix) AND
   by t14 (for Nautilus dark mode). Is it suite-specific or shared?
5. **`gnome-themes-extra`**: needed by t14 for Nautilus/libadwaita, but
   not strictly used by rog/thinkcentre (they use materia). Move to
   GNOME suite profile.
6. **`libmateweather` overlay**: small dead weight on t14. Move the
   patch into a MATE-host-only overlay, or keep it as a cross-host
   compile cost.

---

## Risks

- **Hidden consumers of MATE packages**: `materia-theme` is consumed
  by `home-linux/theme.nix` (only on rog/thinkcentre). If a new shared
  module adds a MATE theme dependency, the split breaks silently. Mitigate
  with a doc comment on the MATE profile.
- **libsecret/Remmina dependency on gnome-keyring**: any host that
  imports `home-linux/remote-desktop.nix` (all 3 today) needs keyring.
  If the user considers `gnome-keyring` a "GNOME suite" package, the
  the remote-desktop import on rog/thinkcentre becomes a contradiction.
  Mitigate by clarifying the daemon/suite distinction.
- **T14 currently uses omarchy-nix, which is Hyprland-based.** If the
  intended state is a full GNOME DE, this is a multi-day migration, not
  a config split. The proposal phase must confirm the scope.
- **`hosts/t14/home/omarchy.nix` may need GNOME HM dconf** if the
  GNOME suite is intended. Today it only sets `gtk.colorScheme` and
  `gtk4.extraConfig["gtk-interface-color-scheme"]`. If the user wants
  full GNOME desktop, t14 needs to be migrated off omarchy-nix, which
  is a much larger change.
- **The `my.*` option namespace is already used** (`my.shutdownDebug`).
  Adding `my.desktop.suite` is consistent but should be declared in a
  single `modules/base/options.nix` (or equivalent) so it can be
  `lib.mkDefault null`.
- **400-line budget risk**: Approach A is ~80-120 changed lines. Within
  the SDD single-PR budget. Approach C is even smaller. None require
  chained PRs.

---

## Ready for Proposal

**Yes**, with a strong recommendation that the proposal phase
**clarify the open question #1** (full GNOME DE migration vs.
GNOME-apps-alongside-omarchy) before committing to tasks.

The proposal should:
1. State whether t14 will gain a full GNOME DE or stay on omarchy/Hyprland.
2. Define `my.desktop.suite = "mate" | "gnome";` (or null for non-desktop hosts).
3. Create `modules/base/profiles/mate.nix` and `modules/base/profiles/gnome.nix`.
4. Refactor `modules/base/profiles/base.nix` to drop suite-specific packages.
5. Refactor `modules/base/packages.nix` to compose shared + suite pkgs.
6. Gate `modules/base/dconf.nix` MATE lock on `my.desktop.suite == "mate"`.
7. Move `gnome-themes-extra` from base profile to GNOME profile (after
   confirming `materia-theme` doesn't depend on it).
8. Update rofi.nix terminal reference (decision needed).
9. Update each host's `default.nix` to declare its suite.
10. Update `home-linux/shared-modules.nix` doc comment to clarify that
    `./mate.nix` is intentionally included for MATE hosts only (or
    remove it and let MATE hosts import it directly).
11. Verify with `nix flake check --no-build` and `format-nix`.

**Suggested execution mode**: single PR (≤400 lines, all related, easy
to review as one unit). Delivery strategy: `single-pr` (default).

---

## Omarchy GNOME Investigation

This subsection is a focused deep-dive into the `omarchy-nix` flake
input to answer the parent's open question #1 ("what is the GNOME
suite on t14?"). Full details live in
[`exploration-omarchy-gnome.md`](./exploration-omarchy-gnome.md); this
is the executive summary.

### Flake input

- **Repo**: `github:glats/omarchy-nix` (a fork of
  `mrosseel/omarchy-nix`, which is itself a NixOS port of
  `basecamp/omarchy` — DHH's Arch Linux flavor).
- **Pinned revision**: `d6f01639b552b9f0ad29946bf2b2401a81ce1842` (in
  `flake.lock`).
- **Source on disk**: `/nix/store/vngsq6mhh0v1vx7hwcnl070rllfpw304-source/`
  (resolved via `nix eval --impure --expr '...inputs.omarchy-nix.outPath'`).
- **Manifesto**: "stay as close to Omarchy as possible" — a port, not a
  reimagining. Package list closely tracks upstream Arch.

### GNOME apps in omarchy-nix (the answer to "what GNOME apps does it include?")

From `modules/packages.nix` (148 lines) — the answer is **9 user-facing
GNOME packages**, all already installed on t14:

| Package | Purpose | Tier |
|---------|---------|------|
| `nautilus` | File manager (primary, `SUPER+SHIFT+F`) | Core |
| `gnome-calculator` | Calculator (`SUPER+R`, `XF86Calculator`) | Core |
| `evince` | PDF viewer | Core |
| `loupe` | Image viewer (modern GNOME, replaces `eog`) | Core |
| `sushi` | Nautilus spacebar previewer | Core |
| `ffmpegthumbnailer` | Video thumbnails in Nautilus | Core |
| `pavucontrol` | PipeWire/PulseAudio volume control | Core |
| `blueman` | Bluetooth manager (autostart hidden) | Core |
| `gnome-themes-extra` | Adwaita/Adwaita-dark theme (libadwaita) | Core |

Plus the daemon: `gnome-keyring` (`services.gnome.gnome-keyring.enable = true` in `modules/nixos/system.nix:208`).

### GNOME apps NOT in omarchy-nix (and NOT in upstream Arch)

`gnome-control-center`, `gnome-system-monitor`, `gnome-screenshot`,
`gnome-text-editor`, `gnome-console`, `gnome-calendar`, `gnome-clocks`,
`gnome-weather`, `gnome-maps`, `eog`, `gedit`, `gnome-terminal`. These
are either intentionally replaced (e.g. `gnome-screenshot` → `satty`,
`gnome-terminal` → ghostty/alacritty/kitty) or simply not part of the
opinionated Omarchy set.

### The one notable omarchy-nix omission

**`gnome-disk-utility`**. Upstream Arch Omarchy includes it
(`install/omarchy-base.packages` line 51), but omarchy-nix dropped it
without comment. This is the most natural Tier 1 GNOME app to add to
t14.

### Recommended t14 GNOME suite (option b)

Tier 1 (matches upstream Arch, omarchy-nix just dropped it):

- `gnome-disk-utility` — disk manager GUI (~30 MB)
- `gnome-system-monitor` — process/resource GUI (~10 MB)

Tier 2 (opt-in, only if the user wants a unified settings panel):

- `gnome-control-center` — large dependency tree (~30-50 packages);
  omarchy's way is TUI menus (`omarchy-menu`, `omarchy-toggle-*`,
  bluetui, impala, wiremix) — no GUI control center is omarchy's
  design choice.

### Conflicts with existing omarchy-nix config

**NONE.** The recommended Tier 1 apps:
- Use the same `gnome-themes-extra` (Adwaita) theme already installed
- Use the same `gnome-keyring` D-Bus service already running
- Don't claim `inode/directory` MIME (Nautilus still owns that)
- Don't conflict with any Hyprland binding or window rule in
  omarchy-nix defaults or `hosts/t14/home/hypr/bindings.nix`
- Do not need `gdm`, `gnome-shell`, or any GNOME session component

### Hyprland ecosystem alternatives to gnome-control-center

`grep "nwg-look|nwg-shell|hyprland-control"` against omarchy-nix
returns **zero hits**. The omarchy way is **TUI + omarchy menu**:
`omarchy-menu` (SUPER+ALT+SPACE), `omarchy-menu system` (SUPER+ESCAPE),
`omarchy-menu theme` (SUPER+SHIFT+CTRL+SPACE), `omarchy-launch-bluetooth`
(bluetui TUI), `omarchy-launch-wifi` (impala TUI),
`omarchy-launch-audio` (wiremix TUI). No GUI settings panel.

### Resolves parent's open question #1

The "GNOME suite on t14" is **a curated set of GNOME apps on top of
Hyprland**, not a full GNOME DE. omarchy-nix ships 9 GNOME packages;
t14 should add 2 more (`gnome-disk-utility` + `gnome-system-monitor`)
to match upstream Arch Omarchy. The parent's `my.desktop.suite =
"gnome"` option (Approach A) can be set on t14 and refer to a new
`modules/base/profiles/gnome.nix` containing exactly these 2 packages
plus a comment explaining the omarchy-nix baseline already covers
Nautilus, Calculator, Evince, Loupe, etc.
