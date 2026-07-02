# Tasks: fix-screensaver-idle-lock

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~14 net (omarchy-nix: +10 across 2 scripts; nixos-hosts: −4 in omarchy.nix + flake.lock auto) |
| 400-line budget risk | Low |
| Chained PRs recommended | No (user requested direct-to-main; under budget anyway) |
| Suggested split | 2 upstream commits → 1 nixos-hosts commit (drop ExecStopPost + flake bump) |
| Delivery strategy | direct-to-main |
| Chain strategy | size:exception (under 400-line review budget) |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Repo | Base | Notes |
|------|------|------|------|-------|
| 1 | Toggle flip + screensaver kill on stop/start | omarchy-nix | main | Self-contained; flag already read by `omarchy-launch-screensaver` line 19 |
| 2 | Per-iter focus rc-check + sleep + `wait` | omarchy-nix | main | Self-contained; independent of unit 1 |
| 3 | Drop ExecStopPost + bump omarchy-nix input | nixos-hosts | master | MUST land after units 1+2 are on omarchy-nix `main` |

## Phase 1: Upstream — Bug 1 (caffeine toggle flag flip)

- [x] 1.1 Edit `~/repos/omarchy-nix/bin/omarchy-toggle-idle`: in the `is-active` stop branch, add `mkdir -p ~/.local/state/omarchy/toggles`, `touch ~/.local/state/omarchy/toggles/screensaver-off`, and `pkill -f org.omarchy.screensaver 2>/dev/null || true`; in the `else` start branch, add `rm -f ~/.local/state/omarchy/toggles/screensaver-off`
- [x] 1.2 Verify: re-read file; confirm 4 lines added in the correct branches; run `bash -n ~/repos/omarchy-nix/bin/omarchy-toggle-idle`
- [x] 1.3 Commit on `omarchy-nix` `main` with message `fix(idle): flip screensaver-off flag and kill running screensaver on toggle` and push to `origin/main` (use `~/.git-credentials`)

## Phase 2: Upstream — Bug 2 (multi-monitor focus race)

- [x] 2.1 Edit `~/repos/omarchy-nix/bin/omarchy-launch-screensaver`: quote `$m` → `"$m"` in the `focusmonitor` call; wrap it in `if ! hyprctl dispatch focusmonitor "$m" >/dev/null 2>&1; then notify-send -u low "⚠  Could not focus $m — skipping"; continue; fi`; add `sleep 0.3` after the focus block; add `wait` after the `done` and before the original `focusmonitor $focused` restore
- [x] 2.2 Verify: re-read file; confirm 5 lines added + 1 line modified (quoting); run `bash -n ~/repos/omarchy-nix/bin/omarchy-launch-screensaver`
- [x] 2.3 Commit on `omarchy-nix` `main` with message `fix(screensaver): settle focus, skip unreachable monitors, wait on dispatch exec` and push to `origin/main`

## Phase 3: Local cleanup + flake bump (nixos-hosts)

- [x] 3.1 Edit `hosts/t14/home/omarchy.nix`: delete the `ExecStopPost` override block (the 2-line comment + 1-line `lib.mkForce` assignment currently at lines 156-159); the file should jump from the `];` closing the hypridle listeners list straight to the `gtk.iconTheme = {` block
- [x] 3.2 From `/home/glats/.nixos`, run `format-nix` (per AGENTS.md) so the deletion re-flows cleanly
- [x] 3.3 From `/home/glats/.nixos`, run `nix flake lock --update-input omarchy-nix` to refresh `flake.lock` against the new upstream SHAs (no edit to `flake.nix` — `url = "github:glats/omarchy-nix/main"` already tracks main)
- [x] 3.4 From `/home/glats/.nixos`, run `nix flake check --no-build` to validate the lock update (per AGENTS.md "before finishing" rule)
- [x] 3.5 Commit on `nixos-hosts` `master` with message `fix(t14): drop screensaver ExecStopPost now handled by omarchy-toggle-idle` (stages both `hosts/t14/home/omarchy.nix` and `flake.lock`) and push to `origin/master`

## Phase 4: User-side verification (manual, on t14)

- [ ] 4.1 User runs `nixos-rebuild switch` on t14 to activate the new module
- [ ] 4.2 User verifies Spec Scenario "Toggle off disables screensaver": press `Super+Ctrl+I`, confirm `~/.local/state/omarchy/toggles/screensaver-off` exists and no screensaver launches after 150s
- [ ] 4.3 User verifies "Toggle on restores screensaver and idle": press `Super+Ctrl+I` again, confirm flag removed and `systemctl --user is-active hypridle` returns active
- [ ] 4.4 User verifies "All monitors receive screensaver": wait 150s idle, confirm ghostty fullscreen on eDP-1 + 3 externals
- [ ] 4.5 User verifies "Unreachable monitor is skipped": hot-unplug a monitor during a screensaver launch, confirm low-priority notification and graceful skip
