## Exploration: omarchy-arch-to-nixos-drift

### Current State
Omarchy is a Hyprland-based desktop environment originally configured on Arch Linux. The user's old Arch install is mounted at an external drive path, containing full dotfiles. The user created omarchy-nix (github.com/glats/omarchy-nix) to replicate this in NixOS, now integrated into their main flake at github.com/glats/nixos-hosts.

The nixos-hosts repo uses omarchy-nix as a flake input (NixOS module + HM module) for the t14 ThinkPad host. Integration is heavy with local overrides: waybar config is fully overridden, many shared home-linux modules (neovim, btop, git, ssh, tmux) mkForce omarchy-nix defaults, starship is disabled, fontconfig disabled, and hypridle timings are customized.

### Affected Areas
- `/run/media/glats/4f7d05e8-.../@home/glats/.config/omarchy/themes/glats/backgrounds/` — 14 unique wallpapers not in omarchy-nix
- `/run/media/glats/4f7d05e8-.../@home/glats/.config/omarchy/hooks/` — 5 hook samples not managed in NixOS
- `/run/media/glats/4f7d05e8-.../@home/glats/.config/waybar/config.jsonc` — waybar config with modules missing from NixOS (weather, kb-layout)
- `/run/media/glats/4f7d05e8-.../@home/glats/.config/hypr/` — hypr config sources with user customizations
- `/run/media/glats/4f7d05e8-.../@home/glats/.config/fcitx5/` — fcitx5 input method config not in omarchy-nix
- `/run/media/glats/4f7d05e8-.../@home/glats/.config/swayosd/config.toml` — swayosd config not in omarchy-nix
- `/run/media/glats/4f7d05e8-.../@home/glats/.config/starship.toml` — starship config (disabled in NixOS by design)
- Upstream `omarchy-nix/` repo — target for PRs to add missing modules/themes/configs
- `/home/glats/.nixos/hosts/t14/home/default.nix` — waybar config override missing weather module from Arch
- `/home/glats/.nixos/hosts/t14/home/hypr/` — t14 hypr config fragments to reconcile with Arch originals

### Key Findings: Arch vs NixOS Drift

| Priority | Category | Arch (external drive) | omarchy-nix upstream | NixOS (t14 host) |
|----------|----------|----------------------|---------------------|-------------------|
| **HIGH** | Wallpapers | 15 backgrounds in glats theme | 1 (0-black.png) | Same as upstream |
| **MED** | Waybar weather | `custom/weather` module present | Missing | Missing |
| **MED** | Waybar kb-layout | `custom/kb-layout` module present | Missing | Replaced with iwd-wifi |
| **MED** | Omarchy hooks | 5 sample hooks (font-set, post-update, battery-low, theme-set, weather) | Not managed | Not managed |
| **MED** | Fcitx5 input method | Full config with keyboard-us profile | No module | No module |
| **MED** | Helper scripts | window-switcher, monitor-hotplug, kb-layout, kb-toggle | Same scripts in bin/ | Same scripts via t14/home/ |
| **LOW** | Ghostty config | background-opacity=0.9, async-backend=epoll | Generated from theme | Override via home-linux/ghostty.nix + t14 ghostty.nix |
| **LOW** | SwayOSD config | config.toml (show_percentage, max_volume) | Has swayosd module for style.css | Same as upstream |
| **LOW-MED** | Hyprlock config | Explicit background/input-field/auth config | Generated from theme | Override via t14 hypr/hyprlock.nix |
| **LOW** | Hypridle config | 150/152s timers | 150/151s timers | 150/200s (overridden for screensaver visibility) |
| **LOW** | Starship | Custom starship.toml | starship module exists | Disabled (uses prezto) |
| **MED** | App configs not ported | chromium/, Code/, discord/, obsidian/, etc. | Not managed | Most apps installed as packages |
| **LOW** | GTK configs | gtk-3.0/settings.ini with dark-theme=0 | Managed via HM GTK module | Same as upstream |
| **LOW** | omarchy.ttf font | Present at ~/.config/omarchy.ttf | Present in config/omarchy.ttf | Deployed via HM |

### Detailed Findings

#### 1. Wallpapers (HIGH — 14 files)
The Arch glats theme at `/run/media/glats/.../.config/omarchy/themes/glats/backgrounds/` contains 15 images:
- `1-oled-black.jpg`, `carbon_black.jpg`, `Bpsmen.jpg`, `KhnKOgr.jpg`, `wallhaven-*.jpg/png` (10), `8nixmv7qg9g21.png`, `image.png`

The upstream omarchy-nix at `config/themes/glats/backgrounds/` contains only `0-black.png`. The remaining 14 files need to be committed to omarchy-nix or at minimum backed up.

#### 2. Waybar Config Drift (MEDIUM)
- **Arch** waybar has `custom/weather` (runs weather.sh, shows temp), `custom/kb-layout` (reads hyprctl layout state), `custom/expand-icon` format ``
- **Upstream omarchy-nix** waybar config has no `custom/weather`, uses `format: ""` for expand-icon
- **NixOS t14** waybar (fully overridden in `hosts/t14/home/default.nix`) adds `custom/iwd-wifi` for iwd WiFi status, has no `custom/weather`, expand-icon format ``
- `custom/update` format differs: Arch `""`, upstream `""`, t14 override `""` (empty)

#### 3. Hypr Config Drift (MEDIUM)
- **input.conf**: Arch has `kb_layout = es,latam` with `grp:alt_shift_toggle`, `repeat_rate = 40`, `touchpad natural_scroll = true`, `no_hardware_cursors = true`. NixOS t14 has its own input.nix with similar values — needs diff.
- **looknfeel.conf**: Arch uses `gaps_in = 0`, `gaps_out = 2.5`, `initial_workspace_tracking = false`. NixOS t14 has its own looknfeel.nix — needs diff.
- **monitor-hotplug-handler.sh**: Arch version runs socat listener for external monitor detection via hyprctl socket2, switches kb layout on dock/undock. NixOS t14 has same script path — needs content diff.
- **hypridle.conf**: Arch uses 150/152s (lock 2s after screensaver). NixOS t14 uses 150/200s (50s gap for screensaver visibility).

#### 4. Omarchy Hooks (MEDIUM)
Arch `~/.config/omarchy/hooks/` has 5 sample files:
- `font-set.sample` — triggered on font change
- `post-update.sample` — triggered after system update
- `battery-low.sample` — plays warning sound via mpv on low battery
- `theme-set.sample` — triggered on theme change
- `post-boot.d/weather.sample` — shows weather notification after boot

These are an Arch runtime feature (executed by omarchy's own tooling). In NixOS, omarchy commands are provided by `bin/` scripts. The hooks mechanism itself needs evaluation — it may not exist in the NixOS module at all.

#### 5. Helper Scripts (MEDIUM — needs content diff)
Both Arch and NixOS t14 have scripts for:
- `window-switcher.sh` — uses walker menu
- `monitor-hotplug-handler.sh` — socat-based display detection
- `kb-layout.sh` — shows current keyboard layout
- `kb-toggle.sh` — toggles between es/latam

#### 6. Fcitx5 Input Method (MEDIUM)
Arch has a full fcitx5 config: `profile` (keyboard-us), `conf/` directory. NixOS doesn't manage fcitx5 — omarchy-nix has no fcitx5 module. If the user uses it, it needs to be added.

#### 7. Application Configs Not Ported (MEDIUM)
Configs present on Arch drive but NOT managed in NixOS:
- `chromium/`, `google-chrome/` — browser profiles (usually cloud-synced)
- `Code/` — VS Code config (cloud-synced via Settings Sync)
- `discord/` — Discord config (auto-generated)
- `obsidian/` — Obsidian notes config
- `libreoffice/` — LibreOffice config
- `mpv/`, `obs-studio/` — media tools
- `qalculate/` — calculator config
- `remmina/` — remote desktop (managed via home-linux/remote-desktop.nix)
- `nvim/` — neovim config (managed via home-linux/neovim.nix)

Most of these are either cloud-synced or auto-generated. Only remmina is already managed.

### Approaches
1. **Full inventory + manual migrate** — Catalog every file on the external drive, compare with omarchy-nix, commit what's missing
   - Pros: Exhaustive, nothing missed
   - Cons: Very time-consuming, many app configs are ephemeral or cloud-synced
   - Effort: High

2. **Targeted drift extraction** — Focus on highest-value items: wallpapers, scripts, hypr config diffs, waybar config reconciliation, swayosd config, fcitx5 module
   - Pros: Delivers the most impact quickly, avoids busywork on ephemeral configs
   - Cons: Lower-priority items (app configs, branding) would remain on drive
   - Effort: Medium

3. **NixOS module parity** — File PRs against upstream omarchy-nix to add missing modules (fcitx5, hooks management) and missing assets (wallpapers, swayosd config)
   - Pros: Upstream-first approach, benefits all omarchy-nix users
   - Cons: Requires separate PR process, slower to converge
   - Effort: Medium

### Recommendation
**Approach 2 (Targeted drift extraction)** with a follow-up pass for approach 3. The highest-value work is: (a) copy 14 wallpapers to omarchy-nix, (b) diff and reconcile helper scripts, (c) reconcile waybar config with Arch original (add weather module), (d) diff hypr config fragments and fix any drift, (e) fcitx5 module for omarchy-nix. App configs (chromium, Code, discord, etc.) should be evaluated for NixOS management individually — most are already installed as packages and their configs are either auto-generated or cloud-synced.

### Risks
- Wallpapers may have unknown licensing — need to verify origin before committing to a public repo
- Arch configs may reference runtime state (e.g., Arch-specific paths) that don't apply in NixOS
- Waybar config contains Arch-specific items like `$OMARCHY_PATH` that need NixOS adaptation
- Some hooks reference `omarchy-cmd-present` and other Arch-specific commands — need NixOS equivalents
- Over-engineering risk: not everything from Arch needs to be NixOS-managed (e.g., some app configs)

### Ready for Proposal
Yes
