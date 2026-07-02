# Tasks: Omarchy Arch-to-NixOS Drift

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 80–120 (across two repos) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | 2 PRs (1 local, 1 upstream) |
| Delivery strategy | single-pr (default) |
| Chain strategy | N/A — not needed |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Fix Nautilus dark mode portal path | PR 1 (nixos-hosts, main) | `hosts/t14/default.nix` only |
| 2 | Upstream omarchy-nix improvements | PR 2 (omarchy-nix, main) | `bin/omarchy-hook`, `theme-switcher.nix`, new `omarchy-weather-status`, new systemd module |

## Phase 1: Fix Nautilus Dark Mode (Local Repo)

- [x] 1.1 In `hosts/t14/default.nix`, move the `runCommand "gtk-portal-hyprland"` block from `home-manager.users.glats.home.packages` to `xdg.portal.extraPortals`. Keep the `xdg.portal.config.hyprland` block below as-is.
- [x] 1.2 Remove or set to `[]` the `home-manager.users.glats.home.packages` assignment (line 155–165). The `runCommand` derivation should now be the sole element of `xdg.portal.extraPortals`.
- [x] 1.3 Update comments at lines 145–154 to reflect the new mechanism (`extraPortals` puts the portal file in `NIX_XDG_DESKTOP_PORTAL_DIR` where the user-profile lookup finds it).
- [x] 1.4 Run `nix fmt -- hosts/t14/default.nix` to validate formatting.
- [x] 1.5 Run `nix flake check --no-build` to validate the full flake.

## Phase 2: Upstream omarchy-nix — Hook & Theme-Set

- [x] 2.1 In `bin/omarchy-hook`, add support for `hooks/<name>.d/` directories: after running the single hook file, iterate `"$HOOK_DIR.d/"*.hook` and source each (skip files ending in `.sample`).
- [x] 2.2 In `bin/omarchy-hook`, replace `set -e` with per-command `||` error handlers (e.g., `"$cmd" "$@" || warn "Hook $cmd failed"`) for graceful error handling — hooks should not abort the session.
- [x] 2.3 In `modules/home-manager/theme-switcher.nix` (or the script it deploys), add `omarchy-hook theme-set "$THEME_NAME"` after the `nixos-rebuild switch` command succeeds.
- [x] 2.4 Run `nix fmt` on the modified files in omarchy-nix.

## Phase 3: Upstream omarchy-nix — Weather + Post-Boot Service

- [x] 3.1 Create `bin/omarchy-weather-status` in omarchy-nix: a shell script that runs `curl -s "wttr.in?format=%c+%t+%w"` and exits gracefully on curl failure.
- [x] 3.2 Create `modules/home-manager/omarchy-weather.nix` that deploys `bin/omarchy-weather-status` and defines a systemd user service `omarchy-post-boot.service` (Type=oneshot, WantedBy=graphical-session.target) running `omarchy-hook post-boot`.
- [x] 3.3 Ensure the new module is imported where needed (e.g., in the home-manager imports for the omarchy user).
- [x] 3.4 Run `nix fmt` on the new/modified files in omarchy-nix.

## Phase 4: Verification

- [ ] 4.1 **Nautilus**: After `nixos-rebuild switch`, open Nautilus — confirm dark mode renders correctly. Verify `ls /run/current-system/sw/share/xdg-desktop-portal/portals/` shows `gtk.portal`.
- [ ] 4.2 **Hook .d/ support**: Create `~/.config/omarchy/hooks/post-boot.d/00-test.hook` (simple `echo`), run `omarchy-hook post-boot` — confirm output. Create a `00-test.hook.sample` in the same dir — confirm it's skipped.
- [ ] 4.3 **Error handling**: Create a hook that exits 1, run `omarchy-hook <name>` — confirm the session doesn't abort and a warning is printed.
- [ ] 4.4 **Theme-set**: Change the theme via `omarchy-theme-set` — confirm `omarchy-hook theme-set <name>` is called after rebuild.
- [ ] 4.5 **Weather**: Run `omarchy-weather-status` — confirm it returns temp/wind data. Test with network down — confirm graceful failure (non-zero exit, no crash).
- [ ] 4.6 **Post-boot service**: Run `systemctl --user start omarchy-post-boot.service` — confirm it runs `omarchy-hook post-boot`. Check `systemctl --user status omarchy-post-boot.service`.
- [ ] 4.7 Run `nix flake check --no-build` on both repos to confirm no regressions.
