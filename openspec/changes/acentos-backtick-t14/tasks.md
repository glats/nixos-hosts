# Tasks: Restore fcitx5 IME and fix compose:caps on t14

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~110 (Repo 1: ~100 new, Repo 2: ~10 modified) |
| 400-line budget risk | Low |
| Chained PRs recommended | Yes (cross-repo dependency, not size) |
| Suggested split | PR 1 (omarchy-nix main) → PR 2 (nixos-hosts main) |
| Delivery strategy | auto-chain |
| Chain strategy | stacked-to-main (each repo's PR merges to its own main) |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | omarchy-nix: fcitx5 module + option + standalone output | PR 1 (omarchy-nix → main) | Foundation — must merge first |
| 2 | nixos-hosts: lock bump + t14 enable + remove compose:caps | PR 2 (nixos-hosts → main) | Depends on PR 1; auto-fetches new omarchy-nix input |

## Phase 1: omarchy-nix upstream (Repo 1)

Foundation: add the reusable `omarchy.fcitx5` module. Must merge and push before Phase 2.

- [x] 1.1 Add `fcitx5` submodule option (`enable` bool, default false) in `/home/glats/repos/omarchy-nix/config.nix` after the `wayvnc` option (after line 509), per R9
- [x] 1.2 Create `/home/glats/repos/omarchy-nix/modules/home-manager/fcitx5.nix` — packages (`fcitx5 fcitx5-qt fcitx5-gtk fcitx5-configtool`), `home.sessionVariables` (`GTK_IM_MODULE`/`QT_IM_MODULE`/`XMODIFIERS`), `xdg.configFile."fcitx5/profile"` + `"fcitx5/config"`, `systemd.user.services.fcitx5` (`PartOf`+`After`+`WantedBy` `graphical-session.target`, `Restart = on-failure`); gate via `let cfg = config.omarchy.fcitx5; in { config = lib.mkIf cfg.enable { ... }; }` (wayvnc.nix pattern)
- [x] 1.3 Add `./fcitx5.nix` to `imports` in `/home/glats/repos/omarchy-nix/modules/home-manager/default.nix` directly after `./wayvnc.nix` (line 88)
- [x] 1.4 Add `homeManagerModules.fcitx5` standalone output in `/home/glats/repos/omarchy-nix/flake.nix` after the `btop` entry (~line 82): imports the new module + declares `options.omarchy = (import ./config.nix lib).omarchyOptions;` so `cfg.enable` resolves when used standalone (R10)
- [x] 1.5 Validate omarchy-nix: `nix flake check` (no-build) in the repo + `nix fmt` on the four changed files; verify `homeManagerModules.fcitx5` evaluates standalone

## Phase 2: nixos-hosts consumer (Repo 2)

Consume the upstream module on t14. Hard dependency on Phase 1 merge.

- [x] 2.1 Add `omarchy.fcitx5.enable = true;` to `/home/glats/.nixos/hosts/t14/home/omarchy.nix` after the `omarchy.rotate_on_start` block (line 121), with a comment explaining the omarchy-nix module supplies packages/env/config/autostart
- [x] 2.2 In `/home/glats/.nixos/hosts/t14/home/hypr/input.nix` line 11: change `kb_options = lib.mkForce "grp:alt_shift_toggle,compose:caps";` to `kb_options = lib.mkForce "grp:alt_shift_toggle";` (R5, S5)
- [x] 2.3 In `/home/glats/.nixos/hosts/t14/default.nix` line 178: change `options = "grp:alt_shift_toggle,compose:caps";` to `options = "grp:alt_shift_toggle";` (R6, S6)
- [x] 2.4 Bump `omarchy-nix` input in `/home/glats/.nixos/flake.lock` via `nix flake update omarchy-nix` so the new module resolves (R10)
- [x] 2.5 Validate nixos-hosts: `nix flake check --no-build` (covers all hosts — rog, thinkcentre, t14, mact2) + `nix fmt` on the three changed files (R8, S10)

## Phase 3: Build + Runtime Verification

- [ ] 3.1 `nixos-build dry` on t14 — full closure must build cleanly; ask before `switch` (per AGENTS.md)
- [ ] 3.2 Manual: dead keys (`` ` ``, `´`, `^`, `¨`) produce accented characters in ghostty + nautilus (S1, S5)
- [ ] 3.3 Manual: CAPS LOCK toggles caps (not Compose) after Hyprland + greeter restart (S5, S6)
- [ ] 3.4 Manual: `systemctl --user status fcitx5` shows `active (running)`; fcitx5 tray icon visible in waybar (S4, S12)
- [ ] 3.5 Manual: Alt+Shift toggles es/latam at XKB level; Ctrl+Space cycles es/latam/us in fcitx5 panel (S9, S2)
- [ ] 3.6 Manual: ReGreet greeter (logout flow) accepts es + latam input with no compose:caps (S6)
