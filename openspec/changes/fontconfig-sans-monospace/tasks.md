# Tasks: Fontconfig Sans/Monospace + Omarchy-Nix Per-Component Font Override

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~40-60 (omarchy-nix ~35-55 / 7 files; nixos-hosts 1 URL bump) |
| 400-line budget risk | Low |
| Chained PRs recommended | Yes (cross-repo) |
| Suggested split | PR 1 (omarchy-nix) → PR 2 (nixos-hosts flake bump) |
| Delivery strategy | ask-on-risk (preflight: single commit or small series) |
| Chain strategy | stacked-to-main |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | omarchy-nix: schema + 5 module wirings | PR 1 | 6 commits. Kitty/mako/walker/rofi options defined but not wired — forward-compatible. |
| 2 | nixos-hosts: bump `omarchy-nix` input | PR 2 | Depends on PR 1 merge. One URL line. |

## Phase 1: omarchy-nix — Schema (PR 1, commit 1)

- [ ] 1.1 Edit `config.nix`: add `fonts = { ... }` attrset in `omarchyOptions` with 9 `lib.types.str` options (waybar, swayosd, mako, walker, rofi, hyprlock, alacritty, ghostty, kitty). GUI defaults = `"sans-serif"`; TUI/terminal defaults = `"monospace"`. Each has a `description`.

## Phase 2: omarchy-nix — Wire Fonts (PR 1, commits 2-6)

- [ ] 2.1 Edit `config/waybar/style.css`: remove `font-family: 'JetBrainsMono Nerd Font';` and `font-size: 12px;` from `*` block; add `@import "./font.css";` at top.
- [ ] 2.2 Edit `modules/home-manager/waybar.nix`: add `xdg.configFile."waybar/font.css".text = ''* { font-family: ${cfg.fonts.waybar}; font-size: 12px; }'';`.
- [ ] 2.3 Edit `modules/home-manager/swayosd.nix`: replace hardcoded `'JetBrainsMono Nerd Font'` with `${cfg.fonts.swayosd}`.
- [ ] 2.4 Edit `modules/home-manager/alacritty.nix`: replace all 3 `"JetBrainsMono Nerd Font"` (normal/bold/italic `family`) with `cfg.fonts.alacritty`.
- [ ] 2.5 Edit `modules/home-manager/ghostty.nix`: replace `font-family = "JetBrainsMono Nerd Font"` with `font-family = cfg.fonts.ghostty`.
- [ ] 2.6 Edit `modules/home-manager/hyprlock.nix`: replace both `"CaskaydiaMono Nerd Font"` occurrences with `cfg.fonts.hyprlock`.

## Phase 3: nixos-hosts — Integration (PR 2, commit 7)

- [ ] 3.1 Edit `flake.nix`: update `omarchy-nix.url` to the PR 1 merge commit SHA. Run `nix flake lock --update-input omarchy-nix` to refresh `flake.lock`.

## Acceptance Criteria

- [ ] AC1 `nix flake check --no-build` passes on omarchy-nix after Phase 2.
- [ ] AC2 `nix flake check --no-build` passes on nixos-hosts after Phase 3.
- [ ] AC3 `format-nix` reports no changes on both repos.
- [ ] AC4 Generated `~/.config/waybar/style.css` (post-rebuild) contains `@import "./font.css";` and no `'JetBrainsMono Nerd Font'` literal.
- [ ] AC5 Generated `~/.config/waybar/font.css` contains `font-family: sans-serif;` by default.
- [ ] AC6 Setting `omarchy.fonts.waybar = "Source Sans 3"` in a consumer changes generated waybar font.css to that family.
- [ ] AC7 `fc-match monospace` on t14 still resolves to JetBrainsMono or CaskaydiaCove Nerd Font.
- [ ] AC8 `modules/desktop/fonts.nix` unchanged (system fontconfig policy not modified).
- [ ] AC9 No browser-targeted `<test name="application">` rules in fontconfig localConf.

## Out of Scope (deferred)

- `home-linux/alacritty.nix` explicit `font.normal.family` (spec mentioned; dropped — verify no override gap before adding).
- `omarchy.fonts.kitty` wiring into `kitty.nix` (option defined; nixos-hosts `home-linux/kitty.nix` already sets its own font).
- Active wiring of `mako`/`walker`/`rofi` (options defined for forward-compat; mako/walker use static CSS, rofi not in omarchy-nix).
