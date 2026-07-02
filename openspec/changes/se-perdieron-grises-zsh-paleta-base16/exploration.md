# Exploration: se perdieron grises en zsh paleta — audit base16 pattern

## Codebase Map

### Color data flow

```
                        ┌─────────────────────────────────┐
                        │   shared/palette.nix            │  ← SINGLE SOURCE OF TRUTH (Linux + Darwin)
                        │   (slug = "glats", 16 colors)   │
                        └──────────────┬──────────────────┘
                                       │ import
              ┌────────────────────────┴────────────────────────┐
              │                                                  │
              ▼                                                  ▼
  ┌──────────────────────────┐                    ┌────────────────────────────┐
  │ home-linux/theme.nix     │                    │  omarchy-nix  (glats branch)│
  │  imports nix-colors HM   │                    │  custom-base16-schemes.nix │
  │  sets colorScheme =      │                    │  → colorScheme = glats     │
  │  import ../shared/...    │                    │  (IDENTICAL hex values)    │
  └──────────┬───────────────┘                    └────────────┬───────────────┘
             │                                                 │
   ┌─────────┴──────────┐   rog, thinkcentre         t14       │
   │                   │   (NixOS HM integration)              │
   ▼                   ▼                                       ▼
  home-linux/kitty.nix              ←── consumed by ──→   omarchy-nix btop/ghostty/
  home-linux/ghostty.nix              config.colorScheme     kitty/hyprland/etc.
  home-linux/rofi.nix                  .palette.baseXX       (uses the SAME hex)
  home-linux/mate.nix                                       (verified via /nix/store
  home-darwin/ghostty.nix                                     rendered themes)
  shared/tmux.nix
  shared/shell-aliases.nix
  home-linux/conky-rog.nix
  home-linux/conky-thinkcentre.nix
  modules/desktop/kmscon.nix
  (any *.nix that does colorScheme.palette.baseXX)
```

### Key files

| File | Role | Pattern |
|------|------|---------|
| `shared/palette.nix` | The glats palette definition (pure attrset) | `base00..base0F = "RRGGBB"` ✓ base16 |
| `home-linux/theme.nix` | Wires nix-colors HM module + sets `colorScheme` | `import ../shared/palette.nix` ✓ |
| `home-darwin/theme.nix` | Same, for darwin (palette only, no GTK) | `import ../shared/palette.nix` ✓ |
| `home-linux/shared-modules.nix` | Canonical HM module list (rog/tc) | includes `theme.nix` before btop ✓ |
| `home-darwin/shared-modules.nix` | Same, for darwin (mact2) | includes `theme.nix` before btop ✓ |
| `home-linux/{kitty,ghostty,rofi,mate,conky-*,tmux}.nix` | Consumers | `config.colorScheme.palette.baseXX` ✓ |
| `shared/tmux.nix` | tmux base16 status bar | `config.colorScheme.palette.baseXX` ✓ |
| `shared/shell-aliases.nix` | zsh ZSH_HIGHLIGHT_STYLES (17 styles) | `config.colorScheme.palette.baseXX` ✓ |
| `modules/desktop/kmscon.nix` | console palette | `import ../../shared/palette.nix` ✓ |
| `lib/colors.nix` | helpers: hexToRgb, doubleHex, byteDoubleHex | n/a |
| `flake.nix` line 17 | `nix-colors.url = "github:misterio77/nix-colors"` | n/a |
| `flake.lock` | nix-colors pinned to `b01f024090d2c4fc3152cd0cf12027a7b8453ba1` (2024-02-13) | n/a |

### t14 special path (omarchy-nix)

| File | Role |
|------|------|
| `flake.nix` line 213 | `inputs.omarchy-nix.nixosModules.default` for t14 |
| `flake.nix` line 257 | Standalone HM `omarchy.theme = "glats"` |
| `hosts/t14/default.nix` line 129 | NixOS-level `omarchy.theme = "glats"` |
| `hosts/t14/home/omarchy.nix` line 43 | Imports `omarchy-nix.homeManagerModules.default` |
| `hosts/t14/home/omarchy.nix` lines 22–25 | **Excludes** `home-linux/theme.nix` because omarchy owns the colorScheme |
| `omarchy-nix/modules/custom-base16-schemes.nix` | Defines `glats` entry — **byte-for-byte identical to `shared/palette.nix`** |
| `omarchy-nix/modules/home-manager/default.nix` line 229 | `colorScheme = selectedColorScheme` (selected = glats) |
| `omarchy-nix/modules/home-manager/btop.nix` | Uses `config.colorScheme.palette` (resolves to glats hex) |

## Applications consuming nix-colors with glats

For **EACH** application, I verified:
- File path
- How it consumes colors
- Whether it uses base16 (base00–base0F)
- Anomalies

### Terminals (kitty, ghostty, alacritty)

| App | File | How | base16 pattern | Anomaly |
|-----|------|-----|---------------|---------|
| kitty | `home-linux/kitty.nix` (line 50–103) | Direct ref `config.colorScheme.palette.baseXX`; full 22-color ANSI mapping (0–21) | ✓ base00–base0F + extended base01/02/04/06 | None |
| ghostty | `home-linux/ghostty.nix` (line 22–69) | Direct ref; full 22-color palette + bg/fg/cursor/selection | ✓ | None |
| ghostty (macOS) | `home-darwin/ghostty.nix` (line 17–48) | Direct ref; same 22-color pattern | ✓ | None |
| alacritty | `home-linux/alacritty.nix` (10 lines) | **Does NOT set colors** — only `startup_mode` | n/a (omarchy-nix owns colors on t14) | None on Linux. On t14, omarchy's alacritty.nix uses `general.import = [~/.config/omarchy/current/theme/alacritty.toml]` (dynamic, no base16 vars) |
| alacritty (rendered) | `omarchy-nix/modules/home-manager/alacritty.nix` | Import theme file | n/a — static rendered config | None |

### Shell

| App | File | How | base16 pattern | Anomaly |
|-----|------|-----|---------------|---------|
| **zsh prompt** | `home-linux/shell.nix` line 32, `home-darwin/shell.nix` line 28 | `prezto.prompt.theme = "suse"` | ❌ **PROMPT THEME NOT BASE16** | **CRITICAL — see below** |
| zsh syntax highlighting | `shared/shell-aliases.nix` lines 89–105 | `ZSH_HIGHLIGHT_STYLES[x]="fg=#${palette.baseYY}"` — 17 styles | ✓ base03, base08, base0A, base0B, base0C, base0D, base0E, base09 | None |
| tmux status bar | `shared/tmux.nix` (15+ uses) | `set -g ... fg=#${palette.baseXX}` | ✓ base00, base01→base02, base02, base03, base04→base05, base05, base07, base0D | None |
| prezto zpreztorc | rendered `~/.zpreztorc` (HM) | n/a — sets theme name only | n/a | None |

### Launchers / GUI

| App | File | How | base16 pattern | Anomaly |
|-----|------|-----|---------------|---------|
| rofi | `home-linux/rofi.nix` line 4–17 | `@variable: #${palette.baseXX}` rasi template | ✓ base00, base02, base03, base05, base08, base0D | None |
| picom (compositor) | `home-linux/picom.nix` | No color refs | n/a | n/a |

### Desktop / GTK / MATE

| App | File | How | base16 pattern | Anomaly |
|-----|------|-----|---------------|---------|
| GTK theme + CSS | `home-linux/theme.nix` line 12–50 | Hardcoded "Materia-dark-compact" theme + GTK CSS uses `base02`/`base07` | ✓ base02, base07 | None |
| MATE dconf | `home-linux/mate.nix` (15+ uses, incl. `doubleHex baseXX`) | `dconf.settings` for caja, marco, panel, terminal | ✓ base00, base02, base03, base05, base07, base08, base09, base0A, base0B, base0C, base0D, base0E | None |
| MATE panel clock cities | `home-linux/mate.nix` line 152 | Hardcoded `latitude="-33.383331"` (Santiago) | n/a | None |

### Wayland (t14 only)

| App | File | How | base16 pattern | Anomaly |
|-----|------|-----|---------------|---------|
| Hyprland borders | omarchy-nix `hyprland/looknfeel.nix` | `hexToRgba config.colorScheme.palette.baseXX` | ✓ base00, base01, base0D | None |
| Hyprlock | `hosts/t14/home/hypr/hyprlock.nix` | References theme variables from `~/.config/omarchy/current/theme/hyprlock.conf` | n/a (indirection) | None — glats theme file exists |
| waybar | omarchy-nix `waybar.nix` | Reads theme CSS | n/a (rendered) | None |
| walker | omarchy-nix `walker.nix` | `colors = config.colorScheme.palette` | ✓ | None |
| ghostty (t14) | omarchy-nix `ghostty.nix` (uses theme import) | Theme-driven | n/a (rendered) | Rendered = `~/.config/omarchy/themes/glats/ghostty.conf` — uses base16 colors ✓ |
| kitty (t14) | omarchy-nix `kitty.nix` (uses theme import) | Theme-driven | n/a (rendered) | Rendered = `~/.config/omarchy/themes/glats/kitty.conf` — uses base16 colors ✓ |
| alacritty (t14) | omarchy-nix `alacritty.nix` | Theme-driven | n/a (rendered) | None |
| mako | omarchy-nix `mako.nix` | Theme-driven | n/a (rendered) | None |
| swayosd | omarchy-nix `swayosd.nix` | Theme-driven | n/a (rendered) | None |
| btop | omarchy-nix `btop.nix` | `home.file."~/.config/btop/themes/${themeName}.theme"` uses `palette.baseXX` | ✓ | **ANOMALY — see below** |
| zellij | omarchy-nix `zellij.nix` | Theme-driven | n/a (rendered) | None |
| hyprland-preview | omarchy-nix `hyprland-preview-share-picker.nix` | n/a | n/a | None |

### btop dual-writer anomaly (t14)

Two files exist for the btop glats theme, with **DIFFERENT** color content:

| Path | Source | `graph_text` | `proc_misc` | `mem_box` | `cpu_box` |
|------|--------|--------------|-------------|-----------|-----------|
| `~/.config/btop/themes/glats.theme` (DEAD-CODE since `90b4a60` refactor) | was `home-linux/btop-theme.nix` (deleted) | `#a0a0a0` (base04) | `#a0a0a0` (base04) | `#ff8800` (base09) | `#23fd00` (base0B) |
| `~/.config/omarchy/themes/glats/btop.theme` (rendered by omarchy's theme-generator) | `omarchy-nix/modules/home-manager/btop.nix` | `#e0e0e0` (base05, NOT base04) | `#e0e0e0` (base05) | `#1a8fff` (base0D, NOT base09) | `#1a8fff` (base0D, NOT base0B) |

**`color_theme = "glats"` resolves to `~/.config/btop/themes/glats.theme`**, so btop uses the LOCAL semantic-rainbow mapping (correct base16). The omarchy file at `~/.config/omarchy/themes/glats/btop.theme` is **dead code from btop's perspective**, but it is rendered and exists on disk with WRONG base16 mapping. This is the dual-writer dead-code pattern that the previous SDD change `se-perdio-theme-glats-pallete-de-btop` identified.

### Verified rendered outputs (t14 omarchy glats theme)

From `/nix/store/*-hm_.configomarchythemesglats*` (built by omarchy-nix at lock rev `3c5888121d7fb8af77cdd4401efa0cc5f2f18d2d`):

- `ghostty.conf`: palette 0=000000 1=f2201f 2=23fd00 3=fffd00 4=1a8fff 5=fd28ff 6=14ffff 7=e0e0e0 8=767676 9=ff8800 10=23fd00 11=fffd00 12=1a8fff 13=fd28ff 14=14ffff 15=ffffff
- `kitty.conf`: color0-15 same mapping; color16=ff6600, color17=f2201f (only 17 colors; no 18–21)
- `walker.css`: bg=000000, fg=e0e0e0, text=e0e0e0, accent=1a8fff, selected-text=1a8fff, border=1a1a1a, base=000000
- `waybar.css`: fg=e0e0e0, bg=000000, warning=f2201f

These match `shared/palette.nix` exactly.

### Verified rendered output (rog local ghostty)

From `/nix/store/agwmdznvm36gmr2vp2gh50i3phfzmj2b-home-manager-files/.config/ghostty/themes/nix-colors` (current rog host):

```
palette = 0=#000000   palette = 8=#767676    palette = 16=#ff8800
palette = 1=#f2201f   palette = 9=#f2201f    palette = 17=#ff6600
palette = 2=#23fd00   palette = 10=#23fd00   palette = 18=#1a1a1a
palette = 3=#fffd00   palette = 11=#fffd00   palette = 19=#505050
palette = 4=#1a8fff   palette = 12=#1a8fff   palette = 20=#a0a0a0
palette = 5=#fd28ff   palette = 13=#fd28ff   palette = 21=#f0f0f0
palette = 6=#14ffff   palette = 14=#14ffff
palette = 7=#e0e0e0   palette = 15=#ffffff
```

All 22 colors present. The 16-color bright mapping (8–15) follows the base16-shell convention (8=base03, 9=base08, 10=base0B, 11=base0A, 12=base0D, 13=base0E, 14=base0C, 15=base07) — this is the community-standard mapping used by `base16-shell` (chriskempson, dotfiles). **The strict Chris Kempson spec uses 9=base09, 10=base01, 11=base02** but no widely-used base16 implementation follows that. Rog and t14 are consistent with each other and with the base16-shell convention.

## Glats theme analysis

### Where defined

**TWO sources, byte-for-byte identical:**

1. `shared/palette.nix` (16 colors + 5 legacy bright aliases, format matches nix-colors' `colorSchemes.<name>` shape exactly)
2. `omarchy-nix/modules/custom-base16-schemes.nix` (same 16 colors, used when `omarchy.theme = "glats"` on t14)

### Format

Both are pure nix attrsets in the nix-colors shape (no YAML):
```
{ slug = "glats"; name = "Glats"; author = "Custom";
  palette = { base00 = "..."; ... base0F = "..."; }; }
```

### Color values (canonical glats)

| base | hex | role | % |
|------|-----|------|---|
| base00 | `000000` | background | 0% |
| base01 | `1a1a1a` | lighter background | 10% |
| base02 | `505050` | selection background | 31% |
| base03 | `767676` | comments / dim | 46% (mid-grey) |
| base04 | `a0a0a0` | dark foreground | 63% (light grey) |
| base05 | `e0e0e0` | default foreground | 88% (very light) |
| base06 | `f0f0f0` | light foreground | 94% |
| base07 | `ffffff` | light background | 100% |
| base08 | `f2201f` | red | — |
| base09 | `ff8800` | orange | — |
| base0A | `fffd00` | yellow | — |
| base0B | `23fd00` | green | — |
| base0C | `14ffff` | cyan | — |
| base0D | `1a8fff` | blue | — |
| base0E | `fd28ff` | magenta | — |
| base0F | `ff6600` | deprecated | — |

**All 16 base16 colors are present, including the greys (base03, base04, base05, base06).**

Legacy aliases (in `shared/palette.nix` only, used by `modules/desktop/kmscon.nix`):
- `brightGreen`, `brightYellow`, `brightBlue`, `brightMagenta`, `brightCyan`

## Anomalies & Issues Found

### 1. **CRITICAL: ZSH prompt is `suse` (built-in, no colors, NOT base16)**

`home-linux/shell.nix` line 32: `prompt.theme = "suse";`
`home-darwin/shell.nix` line 28: `prompt.theme = "suse";`

**`suse` is a BUILT-IN zsh prompt** (not a prezto prompt). Source from `/nix/store/*zsh-5.9.1/share/zsh/5.9.1/functions/prompt_suse_setup`:

```zsh
prompt_suse_setup () {
  PS1="%n@%m:%~/ > "
  PS2="> "
  prompt_opts=( cr percent )
}
```

**No color codes, no base16 integration.** The SuSE 5.2 default prompt is `user@host:path > ` with no ANSI sequences. This is the **most likely root cause of "se perdieron grises en zsh paleta"** — the user is seeing the colorless SuSE prompt, which has zero greys because it has zero colors.

This affects rog, thinkcentre, t14, AND mact2 (all hosts use `suse`).

To fix:
- Switch `prompt.theme` to a prezto prompt that uses base16 (e.g., create a custom prompt that consumes `config.colorScheme.palette`), OR
- Override the suse prompt's PS1 with `initContent` to inject base16 colors, OR
- Switch to starship / powerlevel10k (already disabled on t14: `programs.starship.enable = lib.mkForce false;`)

### 2. **btop dual-writer dead code (t14)**

`~/.config/omarchy/themes/glats/btop.theme` is rendered by omarchy-nix's `theme-generator.nix` with **wrong base16 mapping**:
- `graph_text = #e0e0e0` (should be `base04` = `#a0a0a0`)
- `proc_misc = #e0e0e0` (should be `base04` = `#a0a0a0`)
- `mem_box/cpu_box/net_box/proc_box = #1a8fff` (should be `base09/base0B/base0E/base0C`)

This is **dead code from btop's perspective** (`color_theme = "glats"` reads from `~/.config/btop/themes/glats.theme`, not from `~/.config/omarchy/themes/`). It exists on disk but is never loaded by btop. The user's btop theme is actually fine because the `lib.mkForce "glats"` in `home-linux/btop-settings.nix` (deleted) was migrated to `inputs.omarchy-nix.homeManagerModules.btop` (via commit `90b4a60`).

This was already identified by the previous SDD change `se-perdio-theme-glats-pallete-de-btop` and **resolved by deleting the local btop files** (now omarchy-nix's btop module is the single source of truth, which produces the correct `~/.config/btop/themes/glats.theme`).

### 3. **Bright color mapping (8-15) follows base16-shell convention, not strict chris-kempson**

This is **NOT a bug** but a deliberate design choice. Both `home-linux/ghostty.nix` (line 48–55), `home-linux/kitty.nix` (line 87–94), `home-darwin/ghostty.nix` (line 28–35), and the rendered omarchy-nix glats ghostty theme all use:

```
8=base03, 9=base08, 10=base0B, 11=base0A, 12=base0D, 13=base0E, 14=base0C, 15=base07
```

The chris-kempson strict spec would be:
```
8=base03, 9=base09, 10=base01, 11=base02, 12=base0D, 13=base0E, 14=base0C, 15=base07
```

The community-standard `base16-shell` (the most widely-used implementation) uses the same mapping as our config. The current mapping is consistent with the actual real-world base16 ecosystem.

### 4. **`shared/palette.nix` not directly used on t14**

`hosts/t14/home/omarchy.nix` lines 22–25 explicitly excludes `home-linux/theme.nix`:

> home-linux/theme.nix (it configures GTK/Qt/dconf and `colorScheme = shared/palette.nix`; the former is owned by omarchy and the latter is now driven by `omarchy.theme = "glats"` too).

So on t14, `config.colorScheme` is set by `omarchy-nix/modules/home-manager/default.nix` line 229 (`colorScheme = selectedColorScheme;`) which uses `customSchemes.glats` from `omarchy-nix/modules/custom-base16-schemes.nix`. The two palette sources are byte-identical (verified against the rendered theme files in `/nix/store/`), so colors match across hosts. This is by design, not a bug.

### 5. **`suse` prompt invalid in current prezto (false alarm)**

The current installed prezto version is `zsh-prezto-0-unstable-2025-07-30`. It has these prompts: `agnoster, cloud, damoekri, giddie, kylewest, minimal, nicoulaj, paradox, peepcode, powerlevel10k, powerline, pure, skwp, smiley, sorin, steeef`. **No `suse` in prezto.**

This is NOT a problem because the user's `suse` is resolved by zsh's built-in `promptinit` (which loads `/nix/store/*zsh-5.9.1/share/zsh/5.9.1/functions/prompt_suse_setup`), not by prezto. So `promptinit` finds the suse prompt via `$fpath` and the SuSE 5.2 colorless prompt is what the user sees. **This confirms Anomaly #1: the user's zsh prompt has no colors because suse is colorless.**

### 6. **No application is missing from the audit**

Every application that I could find uses `config.colorScheme.palette.baseXX` correctly. No hardcoded color hex values outside the palette definition. The only `hardcoded` colors are:
- "Materia-dark-compact" GTK theme name (line 14 of `home-linux/theme.nix`) — this is a GTK theme name, not a color
- "Papirus-Dark" icon theme name (line 16) — same
- "CaskaydiaCove Nerd Font" font name (multiple) — not a color
- `latitude="-33.383331"` (MATE clock, Santiago) — not a color
- "Source Sans Pro" / "sans" / "monospace" font names — not colors
- `bg=default` in tmux status bar — semantic default, not a hex

## Recent relevant changes

`git log --oneline -20 -- shared/ home-linux/theme.nix home-linux/ghostty.nix home-linux/kitty.nix shared/shell-aliases.nix shared/tmux.nix`:

```
061f32b refactor(flameshot): use activation script instead of xdg.configFile
90b4a60 refactor(btop): delegate theme+config to omarchy-nix          ← relevant (deleted btop files)
7982318 working                                                     ← relevant (created shared/shell-aliases.nix with ZSH_HIGHLIGHT_STYLES)
73c4fb5 fix(tmux): unify config across all hosts with vim-tmux-navigator
f5792df fix(theme): align all rog/thinkcentre/darwin apps with canonical base16
1ce9d81 chore: bump omarchy-nix + disable rotate_on_start on t14
6031acf refactor: modular profiles, zero conditions, clean suite split
476862c work
b103c55 flake: bump omarchy-nix (fix standalone HM osConfig crash)
bf6d92e chore(flake): bump omarchy-nix for screenshot runtime deps
07dfa8d work                                                       ← relevant (palette change to monotonic greys)
f1714b1 fix(kitty): restore omarchy-theme-set runtime recoloring on t14
d8f207f feat: gate omarchy-provided packages per suite
1fc3d4c fix(kitty): restore enable + font.name with lib.mkDefault
1c66351 refactor(kitty): consolidate config with lib.mkForce
0ec1c13 fix(ghostty): force exact rog config on all hosts
397bbd1 fix(theme): unify btop + ghostty across rog/thinkcentre/t14
fdbd592 fix(theme): align terminal ANSI mapping with base16 standard
```

The 4 most color-relevant recent commits:

1. **`07dfa8d` (2026-06-17) "work"** — Changed `shared/palette.nix` to add a "Monotonic gray gradient" with the new greys (`base03=767676`, `base04=a0a0a0`, `base05=e0e0e0`, `base06=f0f0f0`). Updated MATE palette (line 252) and home-darwin/home-linux shell.nix to add ZSH_HIGHLIGHT_STYLES. This is the most likely cause of the user's complaint — the palette was rebalanced to monotonic, and the previous "warmer" greys were replaced. If the user remembers the old palette, the new monotonic one will look "less colorful" and may feel like greys are "lost".

2. **`7982318` (2026-06-23) "working"** — Created `shared/shell-aliases.nix` (108 lines) with the full ZSH_HIGHLIGHT_STYLES block. Removed the styles from `home-linux/shell.nix` and `home-darwin/shell.nix`. **This is a pure refactor** — the styles moved from per-platform shell.nix to a shared file. They should still be active.

3. **`90b4a60` (2026-06-27) "refactor(btop): delegate theme+config to omarchy-nix"** — Deleted 4 btop files (~394 lines). btop is now owned by `inputs.omarchy-nix.homeManagerModules.btop`. This means the local semantic-rainbow btop theme is no longer maintained by nixos-hosts; omarchy-nix's `btop.nix` writes `~/.config/btop/themes/glats.theme` directly from the (identical) glats palette. The dual-writer dead code at `~/.config/omarchy/themes/glats/btop.theme` is the only remaining artifact.

4. **`fdbd592` (2026-04 approx) "fix(theme): align terminal ANSI mapping with base16 standard"** — Standardized the 16-color and extended 22-color ANSI mapping across ghostty, kitty, and alacritty to follow base16-shell convention.

## Most likely root causes of "se perdieron grises en zsh paleta"

Ranked by likelihood:

1. **PRIMARY: zsh prompt is `suse` (colorless).** The SuSE 5.2 prompt has no ANSI codes. The user is seeing `user@host:path > ` with no colors. Switching to any other prompt (or overriding PS1 to inject base16 colors) will restore the visual "palette" the user expects.

2. **SECONDARY: palette rebalance in commit `07dfa8d` made greys monotonic.** The old palette had warmer/softer greys (e.g., `base03=8a8a8a` was a more visible "warm" grey; `base05=dddddd` was slightly less bright). The new palette is a strict luminance ramp (`000000` → `1a1a1a` → `505050` → `767676` → `a0a0a0` → `e0e0e0` → `f0f0f0` → `ffffff`). Users perceiving the new greys as "lost" may actually be seeing the strict luminance separation and finding it visually flat. This is a **perception issue**, not a missing color.

3. **TERTIARY (already addressed): btop theme dual-writer** — fixed by `90b4a60`. The user's btop should now be correct after a `nixos-rebuild switch` on each host.

## Ready for Proposal

Yes. Recommendation: the change should focus on the **zsh prompt** (#1 above). Specifically:
- Replace `prompt.theme = "suse"` with a base16-aware prompt, OR
- Add an `initContent` override that injects base16 colors into PS1 (preserves the suse aesthetic), OR
- Use prezto's `prompt` pmodule to define a custom prompt that consumes `config.colorScheme.palette`.

The other two anomalies (palette rebalance, btop dead code) are either by design or already addressed. No need to touch the application consumers — they all use the base16 pattern correctly.
