# Exploration: kitty padding/margin

> Change: `kitty-quedo-con-un-padding-o-marhin-que-no-me-gusta`
> Type: investigation (no implementation)
> Project: nixos-hosts (cwd: /home/glats/.nixos)

## Current State

`kitty` is configured in **one single source of truth** (`home-linux/kitty.nix`, 130 lines), used by all three Linux hosts. No host-specific overrides of kitty exist anywhere in the repo. macOS (`mact2`) gets kitty via Homebrew (`darwin/homebrew.nix` line 58) with no Nix-level config — kitty.conf on mact2 is whatever Homebrew's cask ships by default.

### Where kitty is configured

| File | Role | Status |
|---|---|---|
| `home-linux/kitty.nix` | **Single source of truth** for Linux kitty config. Imported by all 3 Linux hosts. | Active |
| `home-linux/shared-modules.nix:29` | Lists `./kitty.nix` in the canonical shared HM module list (used by rog, thinkcentre). | Active |
| `hosts/t14/home/default.nix:19` | Re-imports `../../../home-linux/kitty.nix` for t14 (t14 uses a curated import list, not `shared-modules.nix`). | Active |
| `hosts/t14/home/omarchy.nix:115` | `omarchy.fonts.kitty = lib.mkForce "CaskaydiaCove Nerd Font"` — overrides the font supplied to omarchy's kitty module. | Active |
| `darwin/homebrew.nix:58` | macOS gets kitty as a Homebrew cask. No Nix-level config. | Active |
| `home-linux/neovim.nix:30,44` | `backend = "kitty"` for neovim's clipboard/image protocol — unrelated to window config. | Active |
| `/tmp/opencode/omarchy-nix/modules/home-manager/kitty.nix` | omarchy-nix's own kitty module (imported on t14 via `inputs.omarchy-nix.homeManagerModules.default`). Sets `window_padding_width = 10`, `background_opacity = "0.95"`, keybinds, and `include = ~/.config/omarchy/current/theme/kitty.conf` (the theme-include trick that enables `omarchy-theme-set` runtime recoloring). | Upstream (read-only context) |

### Host coverage

| Host | Has kitty? | Configured via | Padding source |
|---|---|---|---|
| `rog` (NixOS, MATE/XRDP) | Yes | `home-linux/kitty.nix` (via `shared-modules.nix`) | nixos-hosts only |
| `thinkcentre` (NixOS, headless) | Yes | `home-linux/kitty.nix` (via `shared-modules.nix`) | nixos-hosts only |
| `t14` (NixOS, Hyprland/Omarchy) | Yes | `home-linux/kitty.nix` + `omarchy-nix/modules/home-manager/kitty.nix` (attrset-merged via `lib.mkDefault` on `settings` since commit `f1714b1`) | Both — nixos-hosts wins at equal priority via later-import (line 14–20 comment in `kitty.nix` documents the merge rules) |
| `mact2` (macOS) | Yes (Homebrew cask) | None (Nix) | Out of scope — default Homebrew kitty.conf |

### The one padding setting that exists

`home-linux/kitty.nix:64` (inside `programs.kitty.settings = lib.mkDefault { ... }`):

```nix
window_padding_width = 10;
```

This is the **only** padding/margin/border/decoration key set anywhere in nixos-hosts. Kitty default is `0`. 10 cells of internal padding means ~10 character-widths of dead space between the terminal text and the window border on all four sides.

The same value is re-declared by `omarchy-nix` at `modules/home-manager/kitty.nix:24` (also `mkDefault` 10). On t14, both `mkDefault` values are equal (10) so attrset merge succeeds without conflict — the value lands as 10.

### What is **not** set (would affect perceived padding if added)

Grep over the entire repo (`*.nix`) for `window_padding|hide_window|placement_strategy|window_border|window_margin` returns only the two matches in `home-linux/kitty.nix:14` (comment) and `:64` (the value above). Specifically:

- `window_margin_width` — **not set** (kitty default 0 = no margin between kitty window and screen edge)
- `window_border` / `window_border_width` — **not set** (kitty default = no OS border drawn)
- `placement_strategy` — **not set** (kitty default = center)
- `hide_window_decorations` — **not set** (kitty default = false → OS title bar is visible)
- `window_padding_width` is the **only** spacing-related setting anywhere in the repo

### Other related settings (for context, not the cause)

- `programs.kitty.font.size = lib.mkForce 11;` (`kitty.nix:110`) — overrides omarchy's `mkDefault 12`. Smaller font = each cell is smaller, but padding is in cells, so 10 cells of padding is the same physical size regardless of font. However, the **proportion** of padding-to-content is larger at font 11 than at font 12.
- `background_opacity = lib.mkForce "0.9";` (`kitty.nix:55`) — overrides omarchy's `mkDefault "0.95"`. Inline `mkForce` is required because both modules set the same key at `mkDefault` priority (line 53–54 comment).
- `xdg.dataFile."applications/kitty.desktop"` with `Exec=...kitty --start-as maximized %U` (`kitty.nix:118–129`) — the .desktop launcher forces maximized windows. **This does not add padding**, but a maximized window makes the 10-cell internal padding more visually obvious (no surrounding screen real estate to "hide" the padding against).
- `keybindings.kitty_mod+f10 = "toggle_maximized";` (`kitty.nix:114`) — toggles maximize via the keyboard.

### Hyprland tiling gaps on t14 (orthogonal to kitty's own padding)

`hosts/t14/home/hypr/looknfeel.nix:29–32`:

```nix
general = {
  gaps_in = lib.mkForce 0;
  gaps_out = lib.mkForce 2.5;
};
```

These are **Hyprland window-tiling gaps**, not kitty's internal padding. They affect the space between adjacent tiled windows (`gaps_in`) and between a window and the screen edge (`gaps_out`). For a **floating** kitty window (which it is by default on Hyprland unless windowrulev2 forces tiling), the `gaps_out` value adds a small visible margin between the kitty window border and the screen edge. This is separate from `window_padding_width` (inside kitty) and `window_margin_width` (between kitty window and screen).

Note: `omarchy-launch-screensaver` in omarchy-nix (`bin/omarchy-launch-screensaver:50`) explicitly uses `--override window_padding_width=0` to launch kitty with zero internal padding for the screensaver — confirming that upstream omarchy considers `window_padding_width = 10` the user-visible default for ordinary use.

## Problem Areas

The user's complaint is about **unwanted padding or margin in kitty**. Based on the grep above, the candidates are:

1. **`window_padding_width = 10` (10 cells of internal padding)** — the primary suspect. This is set in both `home-linux/kitty.nix:64` and `omarchy-nix/modules/home-manager/kitty.nix:24`, and is the only padding/margin key in the entire repo. It produces 10 character-widths of dead space around the terminal text on all four sides. Kitty's default is 0. 10 is generous by community convention (most configs use 0–4).

2. **`hide_window_decorations` not set (default false)** — the OS title bar at the top of the kitty window adds visible height that some users perceive as extra space. Not padding, but related visually. Default is OS-dependent: on Wayland under Hyprland (t14) the title bar is minimal; on MATE (rog, thinkcentre) it includes min/max/close buttons + title text.

3. **Hyprland `gaps_out = 2.5` on t14** (`hosts/t14/home/hypr/looknfeel.nix:31`) — adds a small margin between the kitty window and the screen edge. This affects **all** floating windows on t14, not just kitty. Independent of kitty's own config.

4. **`window_margin_width` (kitty) is not set** — default 0, so there is no kitty-level external margin. **Not a contributor.**

5. **Font size 11** — makes the 10-cell padding proportionally larger relative to text. Not a cause on its own but amplifies perception of (1).

6. **OMarchy theme `include` line** — `~/.config/omarchy/current/theme/kitty.conf` is `include`d via kitty's `include` directive. The generated file (per `omarchy-nix/modules/home-manager/theme-generator.nix:127–159`) only sets colors, tab/window border colors, and selection colors. **It does not set padding or margin.** Not a contributor.

## Affected Areas

- `home-linux/kitty.nix:64` — the single line that produces the 10-cell internal padding. Changing it (e.g. to 0, 2, 4) directly changes the perceived padding.
- `home-linux/kitty.nix:110` — `font.size = lib.mkForce 11` — secondary effect on padding proportion.
- `home-linux/kitty.nix:122` — `Exec=...kitty --start-as maximized %U` — secondary effect (maximized windows show padding more prominently).
- `hosts/t14/home/omarchy.nix:115` — `omarchy.fonts.kitty` — unrelated to padding but kept in scope for context.
- `/tmp/opencode/omarchy-nix/modules/home-manager/kitty.nix:24` — same `window_padding_width = 10` value in upstream omarchy. Would need to be changed in lockstep on t14 if the nixos-hosts value is reduced AND the merge priority is changed (currently they match at 10, so no conflict). **If the user wants the change to apply on t14, omarchy-nix also needs to be reduced** — otherwise on t14 both modules declare different values at equal priority and merge will fail.
- `/tmp/opencode/omarchy-nix/bin/omarchy-launch-screensaver:50` — already hardcodes `--override window_padding_width=0` for the screensaver. This is independent of the main kitty config; no change needed here.

## Approaches

### Option A — Change only the nixos-hosts value (rog, thinkcentre only)

Reduce `window_padding_width = 10` to e.g. `0`, `2`, or `4` in `home-linux/kitty.nix:64`.

- **Pros:** One-line change, immediate effect on rog + thinkcentre.
- **Cons:** Does not affect t14 (t14 also reads `window_padding_width` from omarchy-nix's `mkDefault` 10, which at equal priority would now conflict with the new nixos-hosts value 0/2/4 and fail evaluation).
- **Mitigation:** Use `lib.mkForce` to force the new value on t14 too, OR reduce omarchy-nix's value in lockstep (requires PR to omarchy-nix).
- **Effort:** Low (one line) — but requires deciding what to do about t14.

### Option B — Change both nixos-hosts and omarchy-nix in lockstep

Reduce `window_padding_width` in `home-linux/kitty.nix:64` AND open a PR / push to `github.com/glats/omarchy-nix` to reduce the same value in `omarchy-nix/modules/home-manager/kitty.nix:24`. User owns omarchy-nix (per `AGENTS.md` row 73) and can push directly.

- **Pros:** All 3 Linux hosts get the same padding. t14's attrset merge stays clean (matching values at matching priorities).
- **Cons:** Two-repo change. omarchy-nix PR review (or direct push) takes a flake bump on t14 to take effect.
- **Effort:** Medium (one nixos-hosts commit + one omarchy-nix commit + one flake bump on t14).

### Option C — Keep `window_padding_width = 10` and use `hide_window_decorations = true` instead

User's complaint is about visible space; eliminating the OS title bar (which takes ~24px at the top) might satisfy them without changing the internal padding.

- **Pros:** Preserves the "10 cells of breathing room" choice (which has been the explicit user preference for at least 3 commits: `1c66351`, `1fc3d4c`, `f1714b1`). One-line addition.
- **Cons:** Does not actually address the internal padding if that's what the user dislikes. Title bar removal affects only the top edge. May look worse on rog/thinkcentre (MATE) where the WM doesn't apply its own decorations.
- **Effort:** Low.

### Option D — Make it host-conditional

Different padding per host. E.g. t14: 0, rog: 10, thinkcentre: 4.

- **Pros:** Honors per-host preferences.
- **Cons:** Splits the "single source of truth" architecture that was just refactored (commits `1c66351` + `1fc3d4c`). The current `lib.mkDefault` strategy specifically exists so that all three hosts get the same value with no per-host branching.
- **Effort:** Medium-High (regression risk on the merge architecture).

## Recommendation

**Option A with a small twist**: change `window_padding_width = 10` to `0` in `home-linux/kitty.nix:64`, and pair it with `lib.mkForce` so the new value wins over omarchy-nix's `mkDefault 10` on t14. This gives all 3 Linux hosts zero internal padding (kitty's true default) with a single file change.

Rationale:
- 10 cells of internal padding is a strong, opinionated choice. Most "minimal" kitty configs ship at 0. The user has reported it as unwanted, so restoring the kitty default is the least-surprising fix.
- `lib.mkForce` is already the established pattern in this file (used for `background_opacity` and `font.size` to override omarchy-nix's `mkDefault`). Same pattern, same file, no new architecture.
- No need to touch omarchy-nix or open a separate PR.
- If the user prefers 2 or 4 instead of 0, the same change works — just substitute the value.

Alternative: present the user with the menu (0 / 2 / 4 / keep 10 but use `hide_window_decorations`) before applying. The user might also have meant the Hyprland `gaps_out = 2.5` on t14 (which is a separate, unrelated setting).

## Risks

- **Loss of `omarchy-theme-set` runtime recoloring** — unlikely; the `include = ~/.config/omarchy/current/theme/kitty.conf` directive is in omarchy-nix's `mkDefault` block, and the merge architecture (commit `f1714b1`) was designed so that `include` survives attrset union. `mkForce` on a single key (`window_padding_width`) does not drop the rest of the settings attrset, so `include` is unaffected.
- **Visual mismatch with omarchy defaults** — t14 will have 0 padding while omarchy's screenshots and theme previews show 10. This is intentional and user-driven, but other users of omarchy-nix (if any) will not see this change. Acceptable since the user owns omarchy-nix and can choose to upstream the change (Option B) later.
- **rog/thinkcentre regression** — if the user actually likes the 10-cell padding on rog/thinkcentre and only dislikes it on t14, the global change in Option A would regress those hosts. Mitigation: ask the user to confirm before applying, or use Option D.
- **Compiled kitty.conf verification** — without running `nix flake check` or `home-manager build`, the actual generated `~/.config/kitty/kitty.conf` cannot be inspected. The merge arithmetic in this report is derived from reading the source files (`home-linux/kitty.nix` and `omarchy-nix/modules/home-manager/kitty.nix`) and the home-manager kitty module source on GitHub; it is correct per the Nix module system semantics but should be sanity-checked by building.

## Options Available (home-manager kitty module)

From `nix-community/home-manager/modules/programs/kitty.nix` (master):

| Option | Type | Used by nixos-hosts? | Used by omarchy-nix? |
|---|---|---|---|
| `programs.kitty.enable` | bool | Yes (`mkDefault true`) | Yes (`mkDefault true`) |
| `programs.kitty.package` | package | No (default) | No |
| `programs.kitty.darwinLaunchOptions` | listOf str | No | No |
| `programs.kitty.settings` | attrsOf (str/bool/int/float) | Yes | Yes |
| `programs.kitty.themeFile` | nullOr str | No | No |
| `programs.kitty.autoThemeFiles` | submodule | No | No |
| `programs.kitty.font` | nullOr fontType | Yes (name+size) | Yes (name+size) |
| `programs.kitty.actionAliases` | attrsOf str | No | No |
| `programs.kitty.keybindings` | attrsOf str | Yes (`kitty_mod+f10`) | Yes (`ctrl+insert`/`shift+insert`) |
| `programs.kitty.mouseBindings` | attrsOf str | No | No |
| `programs.kitty.environment` | attrsOf str | No | No |
| `programs.kitty.shellIntegration.{mode,enableBash/Fish/ZshIntegration}` | various | No | No |
| `programs.kitty.enableGitIntegration` | bool | No | No |
| `programs.kitty.extraConfig` | lines | No | No |
| `programs.kitty.quickAccessTerminalConfig` | attrsOf ... | No | No |
| `programs.kitty.diffConfig.{settings,keybindings,extraConfig}` | various | No | No |

**Key insight:** `programs.kitty.settings` is typed `attrsOf (str|bool|int|float)` and is rendered verbatim via `toKeyValue` into `key value` lines in `~/.config/kitty/kitty.conf`. The home-manager module does **not** validate that keys are real kitty.conf directives — anything you put there is passed through. This means `window_padding_width`, `window_margin_width`, `placement_strategy`, `hide_window_decorations`, `window_border`, `tab_bar_edge`, etc. are all supported simply by adding them to `settings` — no schema migration or HM version bump required.

Convenience attrs that are **not** exposed as first-class HM options but are pass-through supported: everything documented in <https://sw.kovidgoyal.net/kitty/conf.html> goes into `settings`. Specific keys relevant to this change:

- `window_padding_width` (cells, default 0) — already in use
- `window_margin_width` (pixels, default 0) — not set anywhere
- `window_margin_height` (pixels, default 0) — not set anywhere
- `window_border_width` (pixels, default 0) — not set anywhere
- `hide_window_decorations` (bool, default false) — not set anywhere
- `placement_strategy` (center/top-left/... default center) — not set anywhere
- `remember_window_size` (bool, default true) — not set anywhere
- `initial_window_width`/`initial_window_height` (cells) — not set anywhere
- `tab_bar_edge` (top/bottom/hidden, default bottom) — not set anywhere
- `enabled_layouts` (str list) — not set anywhere

## Relevant Commits

Recent commits touching kitty config (most recent first):

| Commit | Date | Description |
|---|---|---|
| `f1714b1` | 2026-06-28 | `fix(kitty): restore omarchy-theme-set runtime recoloring on t14` — switched `lib.mkForce` → `lib.mkDefault` on `programs.kitty.settings`; inline `mkForce "0.9"` on `background_opacity`. This is the current architecture. |
| `1fc3d4c` | 2026-06-28 | `fix(kitty): restore enable + font.name with lib.mkDefault for rog/thinkcentre` — added `lib.mkDefault true` on `enable` and `lib.mkDefault "CaskaydiaCove Nerd Font"` on `font.name` so rog/thinkcentre get kitty enabled without omarchy-nix. |
| `1c66351` | 2026-06-28 | `refactor(kitty): consolidate config with lib.mkForce, wire omarchy.fonts.kitty` — the consolidation refactor. Re-declared `window_padding_width=10`, `repaint_delay=10`, `input_delay=3`, `sync_to_monitor="yes"` as `mkDefault` so they match omarchy-nix's values and merge cleanly. |
| `26084e8` | 2026-06-28 | `feat(t14): set GUI font overrides to sans` — added the `omarchy.fonts.kitty = "CaskaydiaCove Nerd Font"` block. |
| `a0b6e0b` | (earlier) | `refactor(t14): drop duplicate kitty override file` — eliminated a previous t14-specific kitty override file; everything now lives in `home-linux/kitty.nix`. |
| `61837fe` | 2026-05 (approx) | `feat(t14): port missing personal configs — ghostty, kitty, starship, wiremix, remmina` — initial kitty import for t14. |
| `fdbd592` | (earlier) | `fix(theme): align terminal ANSI mapping with base16 standard` — color-only change. |
| `ddcf061` | (earlier) | `work` — predates the 3-commit refactor series; not analyzed in detail. |

**Pattern:** The kitty config has been through 3 stabilization commits in the past 48 hours (Jun 28). The `window_padding_width = 10` value has been consistent across all of them — the user's complaint is about a value that has been deliberately preserved through the refactor, not a recent regression.

## Quick verification commands (do not run yet)

```bash
# Inspect the compiled kitty.conf on any Linux host
ssh rog.local cat ~/.config/kitty/kitty.conf
ssh t14.local cat ~/.config/kitty/kitty.conf

# Dry-run the build to inspect the merged attrset
nix eval .#homeConfigurations.rog.config.xdg.configFile."kitty/kitty.conf".text --raw
nix eval .#homeConfigurations.t14.config.xdg.configFile."kitty/kitty.conf".text --raw
```

## Ready for Proposal

**Yes.** The investigation is complete. The root cause is `window_padding_width = 10` at `home-linux/kitty.nix:64` (with the upstream omarchy-nix mirror at `omarchy-nix/modules/home-manager/kitty.nix:24`). The fix is a one-line value change with optional `lib.mkForce` to handle the t14 merge.

The orchestrator should present the user with a menu of values (0 / 2 / 4 / keep 10) before drafting a proposal, since the value choice is a personal preference that only the user can make.
