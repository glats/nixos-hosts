# Proposal: Reliable Idle Toggle for T14 Lock Screen

## Intent

`omarchy-toggle-idle` stops/starts hypridle via systemctl, but this couples idle + screensaver state (manages `screensaver-off` flag) and `ExecStartPre` clears it on restart. The Nix lock listener uses `loginctl lock-session` instead of `omarchy-system-lock`, missing 1password locking + keyboard reset. Replace process-based toggle with a flag-based disarm mechanism and fix regressions vs Arch Omarchy.

## Scope

### In Scope
- `omarchy-toggle-idle` rewrites to toggle `idle-off` flag file; remove screensaver flag + systemctl management
- Wrap hypridle listener `on-timeout` commands with `omarchy-toggle-enabled idle-off` check
- Fix lock listener: `loginctl lock-session` -> `omarchy-system-lock`; add `on-resume = omarchy-system-wake`
- Fix `before_sleep_cmd`: `loginctl lock-session` -> `OMARCHY_LOCK_ONLY=true omarchy-system-lock`
- New `bin/omarchy-system-wake` (port from Arch: restore display + keyboard brightness)
- Add `OMARCHY_LOCK_ONLY` support to `omarchy-system-lock`
- `ExecStartPre` keeps clearing `screensaver-off` but NOT new `idle-off`
- Remove t14's lock listener override (obsolete with flag-based disarm)

### Out of Scope
- `omarchy-toggle-screensaver`, `omarchy-config` TUI, config refresh/restore (Nix-managed)

## Capabilities

### New Capabilities
- `idle-toggle`: Flag-based idle disarm — toggle script writes/removes `idle-off` flag; listeners check it before firing. Replaces process kill/start.
- `system-lock-wake`: Unified lock/wake lifecycle — `omarchy-system-lock` gains `OMARCHY_LOCK_ONLY`; new `omarchy-system-wake` restores display/keyboard after unlock/sleep.

### Modified Capabilities
None.

## Approach

Flag-file mechanism replaces systemctl stop/start:
1. `omarchy-toggle-idle` creates/removes `~/.local/state/omarchy/toggles/idle-off` (using existing `omarchy-toggle` pattern). Keeps same notification text.
2. Listener commands wrap: `! omarchy-toggle-enabled idle-off && <cmd>`. Flag exists -> nothing fires (screensaver, lock, DPMS all silent — "caffeine" behavior).
3. Lock path unified: `omarchy-system-lock` for idle lock, sleep lock, and manual lock. `OMARCHY_LOCK_ONLY=true` skips DPMS/brightness off on sleep.
4. `omarchy-system-wake` restores state after unlock.
5. `ExecStartPre` clears `screensaver-off` only; `idle-off` persists across hypridle restarts.
6. T14 override simplified: no lock listener override needed.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `omarchy-nix/modules/home-manager/hypridle.nix` | Modified | Wrap listeners, fix regressions, ExecStartPre |
| `omarchy-nix/bin/omarchy-toggle-idle` | Rewritten | Flag toggle, remove systemctl + screensaver mgmt |
| `omarchy-nix/bin/omarchy-system-lock` | Modified | OMARCHY_LOCK_ONLY, background wake pattern |
| `omarchy-nix/bin/omarchy-system-wake` | New | Port from Arch |
| `nixos-hosts/hosts/t14/home/omarchy.nix` | Modified | Remove lock listener override |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Flag check latency on timeout | Low | Single `[[ -f ]]` — negligible |
| OMARCHY_LOCK_ONLY not recognized | Low | Default unset = unchanged behavior |
| Other hosts missing omarchy-system-wake | Low | Only lock on-resume uses it; harmless if absent |

## Rollback Plan

Revert omarchy-nix commits for hypridle.nix + scripts, delete omarchy-system-wake, restore t14 override, bump nixos-hosts flake.lock.

## Dependencies

- Write access to `github:glats/omarchy-nix`
- `omarchy-toggle-enabled` already exists in omarchy-nix bin/

## Success Criteria

- [ ] `omarchy-toggle-idle` toggles `idle-off` flag, not hypridle process
- [ ] Flag present: no listener fires (screensaver, lock, DPMS all silent)
- [ ] Lock uses `omarchy-system-lock` uniformly (idle, sleep, manual)
- [ ] `OMARCHY_LOCK_ONLY=true` locks without display state change
- [ ] `omarchy-system-wake` restores display + keyboard after unlock
- [ ] T14 config no longer needs lock listener override
- [ ] `nix flake check --no-build` passes
