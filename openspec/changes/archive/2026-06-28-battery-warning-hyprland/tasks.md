# Tasks: battery-warning-hyprland

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~7 (one attribute block, no removals) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | single direct commit to main |
| Delivery strategy | exception-ok (direct-commits-on-main) |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Enable UPower + thresholds on t14 | direct commit to main | <10 lines; rollback = `git revert` |

## Phase 1: Implementation

- [x] 1.1 Add `services.upower` block to `modules/hardware/amd-laptop.nix` with `enable = true`, `percentageLow = 15`, `percentageCritical = 8`, `percentageAction = 5`, `criticalPowerAction = "PowerOff"`. Keep block adjacent to the existing `services.fwupd.enable` / `services.power-profiles-daemon.enable` lines for grouping.

## Phase 2: Verification

- [x] 2.1 Run `nix flake check --no-build` from the repo root. Must exit 0. Catches invalid option paths, type errors, and unknown attrs in the new `services.upower` block.
- [x] 2.2 Run `format-nix` (full repo) to apply `nixfmt-rfc-style` to the modified file. Confirms formatting matches the rest of the repo before commit.

## Phase 3: Post-Apply Smoke Test (manual, on t14)

- [x] 3.1 After `nixos-build switch` on t14, run `systemctl --user status omarchy-battery-monitor.service` — must be `active (running)`.
- [x] 3.2 Run `upower -d | grep -E "percentage|state"` — must list the battery with `state: discharging` and the configured thresholds.
- [x] 3.3 Disconnect AC, wait for the 15 % threshold (or fake it by setting a higher `percentageLow` temporarily) — mako must show "Time to recharge!".
