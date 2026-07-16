# Tasks: regreeter-keyboard-layout

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~85 (omarchy-nix: ~80, nixos-hosts: ~5) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR per repo (2 PRs total) |
| Delivery strategy | ask-on-risk |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

## Phase 1: omarchy-nix — Submodule Definition

- [x] 1.1 **omarchy-nix:config.nix** — Add `layoutIndicator` submodule to `greeter` block after `wayvnc`. Options: `enable` (bool, default false), `style` (lines, default ""). Follow existing `wayvnc` submodule pattern.
- [x] 1.2 **Verify** — `nix flake check --no-build` for any host using omarchy-nix. Submodule defaults to disabled, no breakage. (Verified via `nix flake check` on t14)

## Phase 2: omarchy-nix — Config Generation

- [x] 2.1 **omarchy-nix:modules/nixos/system.nix** — Add `greetd-kb-layout` polling script (`writeShellScriptBin`). Parses `hyprctl devices -j | jq .active_keymap`, maps via `case`: "ES", "LATAM", "?". Uses full store paths.
- [x] 2.2 **omarchy-nix:modules/nixos/system.nix** — Add waybar config derivation (`pkgs.writeText`, `builtins.toJSON`): `layer: bottom`, `height: 24`, `custom/kb-layout` module, `interval: 1`.
- [x] 2.3 **omarchy-nix:modules/nixos/system.nix** — Add waybar stylesheet derivation (`pkgs.writeText`): sans-serif 14px, translucent dark background, appended `cfg.greeter.layoutIndicator.style`.
- [x] 2.4 **omarchy-nix:modules/nixos/system.nix** — Add Hyprland template fragments: `gtkPortalEnv` (`env = GTK_USE_PORTAL,0`) and `waybarExec` (`exec-once = waybar -c ...`), inserted before `monitorBlock`.
- [x] 2.5 **omarchy-nix:modules/nixos/system.nix** — Add `environment.etc."greetd/waybar-config"` and `"greetd/waybar-style.css"` entries, gated on `regreet && layoutIndicator.enable`.
- [x] 2.6 **omarchy-nix:modules/nixos/system.nix** — Insert `sleep 0.5` delay at Phase 0 of `greetd-regreet-start` script, gated on `layoutIndicator.enable`.
- [x] 2.7 **Verify** — `nix flake check --no-build` for t14 (omarchy-nix module eval). Config generation does not break existing hosts.

## Phase 3: nixos-hosts — Enable & Document

- [x] 3.1 **nixos-hosts:hosts/t14/default.nix** — Add `layoutIndicator.enable = true;` to `omarchy.greeter` block (after `wayvnc` block, around line 233).
- [x] 3.2 **nixos-hosts:hosts/t14/home/omarchy.nix** — Append to GREETER ARCHITECTURE comment block (line 43): mention waybar provides visual kb-layout feedback via `omarchy.greeter.layoutIndicator`.
- [x] 3.3 **Verify** — `nix flake check --no-build` for t14, rog, thinkcentre, mact2. All pass (verified with local path override for omarchy-nix flake input).

## Summary

| Phase | Tasks | Focus |
|-------|-------|-------|
| Phase 1 | 2 | omarchy-nix: submodule definition |
| Phase 2 | 6 | omarchy-nix: config generation (script, waybar config+style, Hyprland template, env entries, startup delay) |
| Phase 3 | 3 | nixos-hosts: enable on t14, update docs |
| **Total** | **11** | |
