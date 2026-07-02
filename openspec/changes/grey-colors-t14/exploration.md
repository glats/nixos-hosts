# Exploration: grey-colors-t14

> **Change**: `grey-colors-t14`
> **Repo**: `/home/glats/.nixos`
> **Date**: 2026-06-28
> **Project**: nixos-hosts

## Problem Statement

OpenCode TUI renders greys correctly on host `rog` (MATE/X11/NVIDIA) but on
host `t14` (Omarchy/Hyprland/AMD) some greys are too dark / not visible against
the background. User provided two screenshots showing the contrast. The issue
appeared right after the migration to Omarchy (which forced the migration from
MATE to Hyprland and adopted ghostty as the default terminal).

## Root Cause (Corrected — v2)

Both hosts use **ghostty** with identical config (`theme = "nix-colors"`,
`background-opacity = 0.8`). Ghostty answers OSC 11 with bg=`#000000` on both
hosts. OpenCode's `system` theme enters `generateGrayScale`'s `luminance < 10`
branch and produces #08–#66 greys against #000000 **identically on both hosts**.

The difference is the **display pipeline AFTER OpenCode renders**:

| Host | Pipeline | Grey visibility |
|------|----------|-----------------|
| rog  | ghostty → OpenCode → X11 → **XRDP compression** → client display | ✅ XRDP's color re-encoding stretches dark greys, making them visible |
| t14  | ghostty → OpenCode → **Wayland native** → laptop panel | ❌ Native pipeline delivers exact colors; #333333 is invisible on the T14 panel |

**XRDP accidentally "fixes" the contrast** by re-encoding the image for network
transport — lossy compression slightly shifts dark tones upward. The native
Wayland pipeline on t14 delivers pixel-exact colors, revealing the real problem:
OpenCode's `system` theme generates greys that are objectively too dark for a
`#000000` background on a typical laptop panel.

The fix is the same regardless: bypass the `system` theme's dynamic greys and
use explicit glats palette values that have adequate luminance.

The user also reported in the same session: "funciono pero se cambia solo… como
que no persiste. que nos podria faltar?" — meaning an earlier attempt at a fix
worked at first but then reverted. This rules out a simple one-line `.opencode`
config edit and points to a config-generation / activation issue.

## Current State (verified by reading the workspace)

### 1. OpenCode TUI theme: `system` on both hosts

`shared/opencode.nix:115-122` (in `mkRuntimeConfig`):

```nix
".config/${runtimeCfg.dir}/tui.json" = {
  force = true;
  text = builtins.toJSON {
    "$schema" = "https://opencode.ai/tui.json";
    theme = "system";
    plugin = lib.attrNames tuiPluginsToInstall;
  };
};
```

Both hosts therefore write the same `tui.json` with `"theme":"system"`.
Confirmed locally: `/home/glats/.config/opencode/tui.json` =
`{"$schema":"https://opencode.ai/tui.json","plugin":["opencode-subagent-statusline"],"theme":"system"}`.

OpenCode `theme = "system"` means "adapt to the terminal's actual color
scheme" — it does NOT use any of the built-in named themes (opencode, tokyo,
catppuccin, etc.). The TUI:

1. Queries the terminal via OSC 11 (background) and OSC 10 (foreground).
2. Queries OSC 4 (palette colors 0-15).
3. Falls back to the built-in `opencode` theme if `palette[0]` is empty
   (e.g. running inside tmux — see comment in
   `packages/opencode/src/cli/cmd/tui/util/terminal.ts`).

When the palette query succeeds, the system theme is generated dynamically by
`generateSystem(colors, mode)` in
`packages/opencode/src/cli/cmd/tui/context/theme.tsx` (verified from upstream
source):

- `bg` = `defaultBackground` (OSC 11) ?? `palette[0]` (ANSI 0)
- `fg` = `defaultForeground` (OSC 10) ?? `palette[7]` (ANSI 7)
- `grays[i]` (for i = 1..12) = `generateGrayScale(bg, isDark)`
- `textMuted` = `generateMutedTextColor(bg, isDark)`
- All non-grey UI tokens (borders, panels, diff contexts, markdown rules,
  syntax comment) come from either `grays[i]`, `bg`, `fg`, or one of the
  10 ANSI slots (`col(0..10)`).

### 2. `generateGrayScale` for true-black backgrounds

The relevant branch in `generateGrayScale` for the dark case (verified):

```ts
if (isDark) {
  if (luminance < 10) {
    grayValue = Math.floor(factor * 0.4 * 255)  // factor = i/12
    newR = newG = newB = grayValue
  } else {
    // ratio-based scaling toward 255
  }
}
```

`luminance = 0.299*r + 0.587*g + 0.114*b` over 0-255 RGB.

For the glats palette `base00 = 000000`, luminance = 0, falls into the
`luminance < 10` branch. The grays used in the UI:

| i  | factor | grayValue | hex (approx) | Used for                          |
|----|--------|-----------|--------------|-----------------------------------|
| 1  | 0.083  | 8         | `#080808`    | (rarely used)                     |
| 2  | 0.167  | 17        | `#111111`    | `backgroundPanel`                 |
| 3  | 0.250  | 25        | `#191919`    | `backgroundElement`, `backgroundMenu` |
| 6  | 0.500  | 51        | `#333333`    | `borderSubtle`, `diffLineNumber`  |
| 7  | 0.583  | 59        | `#3b3b3b`    | `border`, `diffContext`, `diffHunkHeader`, `markdownHorizontalRule` |
| 8  | 0.667  | 68        | `#444444`    | `borderActive`                    |
| 12 | 1.000  | 102       | `#666666`    | (rarely used)                     |

The brightest generated grey used in the actual UI is `grays[8] = #444444`,
and the most common border (`grays[7] = #3b3b3b`) sits only ~59/255 = 23%
above the `#000000` background. On a high-DPI laptop screen with Hyprland's
color management pipeline and `background-opacity = 0.8` blending against the
glats wallpaper (`config/themes/glats/backgrounds/0-black.png` — true black),
these dark greys are visually indistinct from the background. They are NOT
invisible on rog because:

- MATE on X11 doesn't do Wayland-style color management.
- The wallpaper / background on rog under MATE is likely a slightly lighter
  fill, so `#3b3b3b` shows as a noticeable "darker than wall but still
  visible" tint.
- mate-terminal and most X11 terminals render the OSC 11 background exactly
  as configured, whereas ghostty on Hyprland composites with the Wayland
  wallpaper through `background-opacity = 0.8` (only 20% of the configured
  `#000000` is alpha-blended with whatever Hyprland paints behind it).

### 3. The glats palette has *visible* greys that the system theme ignores

`shared/palette.nix` and the omarchy-nix mirror
`modules/custom-base16-schemes.nix:224-246` define both:

```nix
base00 = "000000"  # Default Background       ← 0% luminance
base01 = "1a1a1a"  # Lighter Background       ← 10%
base02 = "505050"  # Selection Background     ← 31%
base03 = "767676"  # Comments, Invisibles     ← 46%
base04 = "a0a0a0"  # Dark Foreground          ← 63%
base05 = "e0e0e0"  # Default Foreground       ← 88%
base06 = "f0f0f0"  # Light Foreground         ← 94%
base07 = "ffffff"  # Light Background         ← 100%
```

These greys (base03, base04, base05) are explicitly what the base16 standard
uses for comments / dark-fg / default-fg. The OpenCode `system` theme
algorithm **discards them** when bg is `#000000` and synthesises much darker
greys via the `luminance < 10` branch.

Ghostty's own palette (exposed via OSC 4) contains the correct base16 greys:

- `col(7)` (white) = `#e0e0e0` ← used as `text`, `fg`
- `col(8)` (bright black) = `#767676` ← not used in `system` theme
- `col(20)` (extended) = `#a0a0a0` ← not used in `system` theme
- `col(21)` (extended) = `#f0f0f0` ← not used in `system` theme

So ghostty has the right greys in its palette, but OpenCode's `system` theme
generator doesn't read base03/base04/base05/base06 as semantic roles — it only
reads palette[0]..palette[15] (the standard 16 ANSI slots) and the bg/fg.

### 4. Ghostty config is the same on both hosts

- rog: gets `home-linux/ghostty.nix` via `home-linux/shared-modules.nix` →
  `linuxHomeModules` → `home-manager.users.glats.imports`
  (`modules/base/home-manager.nix`).
- t14: gets `home-linux/ghostty.nix` directly via
  `hosts/t14/home/default.nix:18` and omarchy-nix's
  `modules/home-manager/ghostty.nix` is also imported but its `settings` and
  `themes` attrsets are overridden by `lib.mkForce` in
  `home-linux/ghostty.nix:22, 35`.

Result: both hosts use `theme = "nix-colors"` (defined in
`home-linux/ghostty.nix:30`) and the same 16-color palette (the glats palette
from `shared/palette.nix`, embedded into the `themes.nix-colors` block at
`home-linux/ghostty.nix:36-69`).

`background-opacity = 0.8` (line 23) is set on both.

### 5. t14-specific Ghostty / omarchy overrides that change behavior

`hosts/t14/home/default.nix:13-22`:

```nix
imports = [
  ./hypr/monitors.nix
  ./hypr/input.nix
  ./hypr/looknfeel.nix
  ./hypr/hyprlock.nix
  ./hypr/hyprsunset.nix
  ../../../home-linux/ghostty.nix
  ../../../home-linux/kitty.nix
  ./mouse-wiggle.nix
  ../../../home-linux/webcam-rog.nix
];
```

The problem statement referenced `hosts/t14/home/ghostty.nix`, but that file
**does not exist** in the repo (verified with `ls -la` and `read` attempts).
The actual t14-specific ghostty overlays are *omitted* — the only t14 overlay
on top of the shared ghostty config is omarchy-nix's, which `lib.mkForce`
suppresses for the settings and themes attrsets.

This means:

- `window-theme = "ghostty"` from omarchy-nix is dropped on t14 — but this
  only affects the titlebar appearance, not terminal colors.
- `config-file = "?~/.config/omarchy/current/theme/ghostty.conf"` from
  omarchy-nix is dropped on t14 — meaning `omarchy-theme-set` does NOT
  dynamically re-skin ghostty on t14. This is unrelated to the grey issue
  but is a side effect worth noting.
- The `mouse-scroll-multiplier` and other omarchy ghostty keys are dropped
  on t14 — also unrelated.

### 6. ColorScheme / nix-colors wiring

| Host  | `colorScheme` source                                               | `themes.nix-colors` defines                          |
|-------|---------------------------------------------------------------------|-----------------------------------------------------|
| rog   | `home-linux/theme.nix:10` → `import ../shared/palette.nix`          | `base00..base0F` = glats values                     |
| t14   | omarchy-nix `modules/home-manager/default.nix:229` → `selectedColorScheme` = `customSchemes.glats` (from `modules/custom-base16-schemes.nix:224-246`) | same glats values |

`shared/palette.nix` and the omarchy-nix `customSchemes.glats` define
**byte-identical** `base00..base0F` strings. So `config.colorScheme.palette`
is the same on both hosts.

### 7. opencode.json config (also identical)

Both hosts use `shared/opencode.nix` (via shared-modules) and
`shared/opencode-profile.nix`. The active provider on t14 is overridden to
`opencode-go` via `({ home.opencode.activeProviderName = "opencode-go"; })` in
`hosts/t14/home/omarchy.nix:86`, but this is unrelated to the rendering issue.

### 8. OpenCode version

`pkgs/opencode/default.nix:18`: `version = "1.17.11"`. Same on both hosts.

## Investigation Summary — Where the Greys Come From

| Source of grey                | Value on `#000000` bg | Used by                                            |
|-------------------------------|------------------------|----------------------------------------------------|
| OpenCode `system` `grays[i]`  | #080808 – #666666      | borders, diff context, panel bg, etc.              |
| OpenCode `textMuted`          | `#b4b4b4`              | `syntaxComment`, hidden text, etc.                 |
| OpenCode `bg`                 | `#000000`              | selection background tint                          |
| OpenCode `fg` (palette[7])    | `#e0e0e0`              | `text`, `markdownText`, `markdownHeading`, `markdownStrong`, `variable`, `punctuation` |
| OpenCode palette ANSI 8 (bblack) | not used             | —                                                  |

The issue is concentrated in `grays[6]`, `grays[7]`, `grays[8]` — the border
colors. These are by design too dark to be visible against a true-black
background. The `textMuted = #b4b4b4` and `fg = #e0e0e0` are fine.

## Affected Areas

- `home-linux/ghostty.nix` — defines `themes.nix-colors` (the palette that
  gets queried by OpenCode via OSC 4). Changing it changes the 16-color
  palette exposed to OpenCode and to anything else that consumes base16.
- `shared/palette.nix` — single source of truth for the glats palette
  (rog + macOS + t14 via omarchy-nix custom-scheme).
- `shared/opencode.nix:115-122` — the `tui.json` generation. Setting
  `theme` here to anything other than `"system"` is the cleanest single-point
  override.
- `home-linux/theme.nix` — sets GTK colors + `dconf.settings` + dconf, plus
  the local `colorScheme` (used only on rog/thinkcentre). Tied to the glats
  palette via `../shared/palette.nix`. Not on the critical path for the
  OpenCode issue, but changing `base00` here requires also updating
  `shared/palette.nix` (the canonical source) and the omarchy-nix mirror.
- `repos/omarchy-nix/modules/custom-base16-schemes.nix:224-246` — the
  omarchy-nix mirror of the glats palette. Must be kept byte-identical to
  `shared/palette.nix` for t14 to see the same colors.
- `hosts/t14/home/omarchy.nix` — t14 HM entry. Imports omarchy-nix HM module
  + selective shared modules. The `lib.mkForce false` on
  `programs.zsh.zplug` and `programs.starship` and `fonts.fontconfig` are
  unrelated.
- `hosts/t14/home/default.nix` — t14 HM overlays (imports `home-linux/ghostty.nix`).
  Problem statement referenced a `hosts/t14/home/ghostty.nix` that does not
  exist; the actual t14 ghostty overrides are deferred to omarchy-nix but
  then suppressed by `lib.mkForce` in the shared file.

## Approaches

### Approach A — Change OpenCode theme to a built-in named theme

Edit `shared/opencode.nix:119` from `theme = "system"` to one of the
built-in themes (e.g. `"catppuccin"`, `"github"`, `"tokyonight"`, etc.) that
has pre-defined greys with adequate contrast.

- Pros: One-line change, deterministic, independent of host/terminal.
- Cons: Decouples OpenCode from the glats palette — the opencode TUI no
  longer matches the rest of the system theme. Loses the "respect terminal
  defaults" behavior the user explicitly chose.
- Effort: Low (one line + flake build + switch).

### Approach B — Define a custom OpenCode theme JSON in `~/.config/opencode/themes/glats.json`

OpenCode supports a custom-theme lookup order
(`~/.config/opencode/themes/*.json` → `./.opencode/themes/*.json`). Create a
`glats.json` that uses the full base16 palette explicitly for borders, panels,
diff contexts, and text. Deploy it via Home Manager
`xdg.configFile."opencode/themes/glats.json".text = ...` so it's reproducible.

- Pros: Preserves the glats aesthetic, full control over the greys (use
  `base04 = #a0a0a0` for `border`, `base03 = #767676` for `borderSubtle`,
  `base05 = #e0e0e0` for `text` etc.), no more `luminance < 10` dark-grey
  branch.
- Cons: ~40-60 line JSON file, must match the OpenCode ThemeJson schema,
  needs to be regenerated when adding new theme tokens (the theme schema
  drifts across opencode versions).
- Effort: Medium (write the JSON, deploy via HM, verify it loads).

### Approach C — Bump glats `base00` from `#000000` to a slightly lighter black (e.g. `#0d0d0d` or `#121212`)

This is the "fix it for everything at once" approach — every app that reads
the base16 palette (ghostty, btop, walker, mako, tmux status, shell aliases,
kitty, alacritty, fzf, etc.) gets slightly more contrast.

- Pros: One-value change in `shared/palette.nix` + the omarchy-nix mirror
  fixes the rendering everywhere, not just opencode. The
  `generateGrayScale` `luminance < 10` branch is bypassed (luminance becomes
  ~12-15), grays become `factor * 0.4 * 255` based on the ratio
  `newLum/luminance`, producing #20-#70 greys that are visible.
- Cons: Slightly changes the look of the entire system (waybar, mako, btop,
  tmux). The "true black" aesthetic is lost. Hyprland wallpaper is still
  `0-black.png` (true black), so there will be a small but visible mismatch
  between the ghostty/btop/etc. background (`#0d0d0d`) and the wallpaper
  (`#000000`).
- Effort: Low (2-3 line edit), but a broader visual change to verify.

### Approach D — Set `background-opacity = 1.0` in ghostty on t14

`home-linux/ghostty.nix:23` sets `background-opacity = 0.8` for both hosts.
Setting it to `1.0` on t14 would eliminate the alpha-blending and make the
rendered background exactly `#000000`. But the OpenCode `system` theme
already uses `#000000` as the reference, so this doesn't help — it would
only make the issue slightly worse (no wallpaperseep at all).

- Pros: One-line change.
- Cons: Doesn't fix the issue; arguably makes it worse.
- Effort: Low, but the wrong direction.

### Approach E — Hybrid: Approach B (custom theme) + Approach C (slight base00 lift)

Use both: lift `base00` to `#0d0d0d` AND define a custom OpenCode theme that
uses the full base16 palette. Belt and suspenders.

- Pros: Maximum fix coverage. The custom theme doesn't depend on the
  background luminance at all, so even if the base00 lifts fails on a
  particular opencode version, the custom theme is the safety net.
- Cons: Two changes, broader review surface.
- Effort: Medium-high.

## Recommendation

**Approach B** — define a custom `glats.json` OpenCode theme that uses the
full base16 palette explicitly.

Reasoning:

1. The OpenCode `system` theme algorithm has a known limitation for
   true-black backgrounds (`luminance < 10` branch produces #08..#66 greys).
   The proper fix is to use a theme that has its greys defined as
   hex values, not computed.
2. The glats palette already has the right greys — they just need to be
   *applied* to the right OpenCode theme tokens. This is a configuration
   problem, not a palette problem.
3. Approach C (lifting base00) has side effects on every other app
   (waybar, btop, mako, shell, tmux) and changes the look of the system,
   which is a larger discussion than the user is asking about.
4. Approach A (built-in theme) decouples opencode from the glats aesthetic.
5. Approach D is in the wrong direction.

The custom theme should map the OpenCode ThemeJson tokens like:

- `text` → `base05` (#e0e0e0)
- `textMuted` → `base04` (#a0a0a0)
- `background` → `base00` (#000000)
- `backgroundPanel` → `base01` (#1a1a1a)
- `backgroundElement` → `base02` (#505050)  ← visible selection
- `borderSubtle` → `base02` (#505050)
- `border` → `base03` (#767676)            ← visible normal border
- `borderActive` → `base04` (#a0a0a0)     ← visible active border
- `diffContext` → `base03` (#767676)
- `diffLineNumber` → `base04` (#a0a0a0)
- `markdownHorizontalRule` → `base04` (#a0a0a0)
- `syntaxComment` → `base03` (#767676)
- ANSI slots → the existing base08..base0F (already correct)

The `theme` field in tui.json stays `"system"` for the "uses terminal
defaults" semantic, but with the custom theme registered, the user can
select `glats` via the `/theme` command in TUI. Or, more simply, set
`theme = "glats"` in tui.json to make it the default.

This deployment is a single `xdg.configFile` in `home-linux/opencode-theme.nix`
(or inline in `shared/opencode.nix`) and a one-line `tui.json` change.

## Risks

- **OpenCode ThemeJson schema drift**: the theme schema is internal to
  opencode and not formally published. If opencode 1.18+ renames or removes
  any token used in our custom theme, the file will silently fall back to
  defaults. Mitigation: pin the opencode version, document the
  schema-dependence in a comment, and add a `nix flake check` smoke test
  that grep's the json for the expected keys.
- **Theme file vs `tui.json` ordering**: opencode reads `tui.json` *and*
  the `themes/` directory. If `theme = "system"` stays in `tui.json`, the
  custom theme is available but not selected. If the change is `theme =
  "glats"`, opencode loads `glats.json`. We should make this a deliberate
  single decision, not a leftover from previous attempts (the user noted
  "se cambia solo… no persiste" — so a previous fix may have been written
  to `~/.config/opencode/tui.json` directly and then overwritten by
  activation).
- **Shared `home-linux/ghostty.nix` is shared with rog/thinkcentre**:
  any change here affects all three hosts. Approach B keeps ghostty config
  untouched and only touches `shared/opencode.nix`, so the risk is
  contained to opencode TUI rendering.
- **The previous attempt didn't persist**: the user said "funciono pero se
  cambia solo… no persiste". This strongly suggests the previous fix was
  applied to the user-level config dir, not to the Nix-managed config.
  We need to confirm our HM-managed approach actually wins on the next
  rebuild (look for `force = true` on the `tui.json` deployment — it's
  already set in `shared/opencode.nix:81` and `:115`, good).
- **Shared opencode.nix changes affect rog + t14 + thinkcentre**:
  the custom theme would also be loaded on rog/thinkcentre. This is
  intentional and desirable (the glats aesthetic), but worth flagging
  in the proposal for sign-off.

## Ready for Proposal

**Yes.** The root cause is identified (OpenCode `system` theme's
`generateGrayScale` `luminance < 10` branch produces dark greys that are
invisible against `#000000`). The fix is a well-contained
OpenCode-theme addition via Home Manager. The orchestrator can move to
`sdd-propose` to draft a proposal + spec.
