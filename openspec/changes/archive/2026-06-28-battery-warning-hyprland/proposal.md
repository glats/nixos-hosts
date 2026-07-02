# Proposal: battery-warning-hyprland

## Intent

t14 (ThinkPad T14 AMD Gen 4, Omarchy/Hyprland) has no working low-battery protection. Three symptoms share one root cause — `services.upower.enable` is missing from the NixOS config:

1. The `omarchy-battery-monitor` user service (provided by `omarchy-nix`) is dead — it polls `upower -i` and needs the UPower D-Bus service.
2. The mako "Time to recharge!" notification never fires.
3. At 0 % the embedded controller cuts power abruptly → dirty shutdown, journald doesn't flush, btrfs corruption risk.

A single missing line (`services.upower.enable = true`) unlocks the existing upstream stack and adds a clean poweroff at a safe threshold.

## Scope

### In Scope
- Enable UPower D-Bus service on t14.
- Configure low / critical / action thresholds and the critical-power action.
- Verify the existing `omarchy-battery-monitor` user service starts and the mako notification fires.

### Out of Scope
- Hibernate / suspend-on-low-battery (requires swap + `boot.resumeDevice` + initrd hook — separate change).
- Changes to `modules/base/logind.nix` (`HandleLidSwitch=ignore` is intentional).
- Changes to `omarchy-nix` upstream (the battery-monitor script and mako daemon are provided there).
- Hosts other than t14 — `amd-laptop.nix` is only imported by `hosts/t14/default.nix`.

## Capabilities

### New Capabilities
- `battery-warning`: UPower-backed low-battery notification (mako) and clean poweroff before EC cutoff on t14.

### Modified Capabilities
None.

## Approach

Add a `services.upower` block to `modules/hardware/amd-laptop.nix`:

```nix
services.upower = {
  enable = true;
  percentageLow = 15;        # mako "Time to recharge!" via omarchy-battery-monitor
  percentageCritical = 8;    # second warning, urgent tone
  percentageAction = 5;      # UPower triggers criticalPowerAction
  criticalPowerAction = "PowerOff";
};
```

This is the minimal change that:
- Brings the dead `omarchy-battery-monitor` user service to life (UPower D-Bus now present).
- Lets UPower's own `PercentageAction` / `CriticalPowerAction` handle the 0 % cliff with a clean `poweroff`.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `modules/hardware/amd-laptop.nix` | Modified | Add `services.upower` block (~7 lines). |
| `hosts/t14/default.nix` | Unchanged (transitive) | Already imports `amd-laptop.nix` at line 43. |
| `omarchy-nix` (flake input) | Unchanged | Provides `omarchy-battery-monitor` + mako daemon; now actually runs. |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| UPower conflicts with `power-profiles-daemon` (both talk to power-profiles D-Bus) | Low | They are designed to coexist; UPower owns battery, ppd owns profiles. Verify `systemctl status power-profiles-daemon` after switch. |
| `percentageAction = 5` too aggressive vs. user workflow | Low | Tunable; thresholds chosen to give ~10 min warning at typical load before forced poweroff. |
| Clean poweroff at 5 % interrupts unsaved work | Low | Same tradeoff as the EC cutoff — data loss is worse. Mako notifications at 15 % and 8 % give the user multiple chances to plug in. |

## Rollback Plan

Remove the `services.upower` block from `modules/hardware/amd-laptop.nix` and rebuild. One file, one block — `git revert` of the single commit is the rollback.

## Dependencies

- `omarchy-nix` flake input (already present) — provides the battery-monitor script and mako notification daemon.
- No new flake inputs.

## Success Criteria

- [ ] `systemctl --user status omarchy-battery-monitor.service` is `active (running)` on t14.
- [ ] `upower -d` lists the battery device with correct percentage.
- [ ] `nix flake check --no-build` passes.
- [ ] `nixos-build` succeeds for t14.
- [ ] Discharging from 20 % → 15 % triggers the mako "Time to recharge!" notification (manual test).

## Spec Scenarios (preview for sdd-spec)

1. **Low-battery notification fires at 15 %** — Given t14 is on battery at 16 %, When discharge reaches 15 %, Then mako shows "Time to recharge!" and the flag file `/run/user/$UID/omarchy_battery_notified` is created.
2. **Critical warning at 8 %** — Given the low-battery notification already fired, When discharge reaches 8 %, Then a second, urgent mako notification is shown.
3. **Clean poweroff at 5 %** — Given t14 is on battery and no AC is connected, When discharge reaches 5 %, Then UPower triggers `PowerOff` and the system shuts down cleanly before the EC cutoff at 0 %.

## Delta Estimate

- Files changed: 1 (`modules/hardware/amd-laptop.nix`)
- Lines added: ~7 (one attribute block + comment)
- Lines removed: 0
- Total diff: < 10 lines — well under the 400-line review budget. Single direct commit to `main`, no chained PRs.
