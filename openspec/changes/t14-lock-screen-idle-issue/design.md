# Design: Reliable Idle Toggle for T14 Lock Screen

## Technical Approach

Replace process-based idle disarm (systemctl stop/start hypridle) with flag-file mechanism using existing `omarchy-toggle-enabled` pattern. When `idle-off` flag exists, hypridle listeners skip all timeout actions (screensaver, lock, DPMS) producing "caffeine" behavior without stopping the daemon. Unify lock path across idle/sleep/manual triggers via `omarchy-system-lock`, adding `OMARCHY_LOCK_ONLY` env guard for sleep scenarios and new `omarchy-system-wake` for lock on-resume restore.

## Architecture Decisions

| Decision | Option | Tradeoff | Choice |
|----------|--------|----------|--------|
| Disarm mechanism | Flag file vs. systemctl stop | Flag: daemon stays alive, survives rebuilds. Stop: simpler but breaks `ExecStartPre` semantics | Flag file |
| Guard pattern | `! omarchy-toggle-enabled idle-off && cmd` vs. wrapper script | Inline: minimal overhead, no extra process. Wrapper: cleaner but one more fork per timeout | Inline guard |
| Lock command for before_sleep | `OMARCHY_LOCK_ONLY=true omarchy-system-lock` vs. `loginctl lock-session` | omarchy: 1password lock + keyboard reset. loginctl: only session lock | omarchy unified path |
| Screensaver visibility | Flag disarm vs. lock timeout tuning | Flag: natural behavior at 151s. Timeout: requires per-host overrides | Flag disarm (removes t14 override) |
| Wake-on-resume | `omarchy-system-wake` vs. inline commands | Dedicated script: reusable, matches Arch pattern. Inline: one-liner but duplicated | Dedicated script |

## Data Flow

```
omarchy-toggle-idle ──→ writes/removes ~/.local/state/omarchy/toggles/idle-off
                                │
                                ▼
hypridle listener (every 150/151/330s) ──→ ! omarchy-toggle-enabled idle-off && <cmd>
                                │
                    ┌───────────┼───────────┐
                    ▼           ▼           ▼
            screensaver    lock (151s)    dpms off (330s)
            (150s)              │
                    ┌───────────┤
                    ▼           ▼
          omarchy-system-lock   on-resume: omarchy-system-wake
                    │           │
          OMARCHY_LOCK_ONLY?    hyprctl dispatch dpms on
          ├─ true: hyprlock,    brightnessctl -r
          │   keyboard, 1pass
          └─ unset: same + any
              future side effects

before_sleep_cmd ──→ OMARCHY_LOCK_ONLY=true omarchy-system-lock
after_sleep_cmd  ──→ hyprctl dispatch dpms on (unchanged)
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `omarchy-nix:modules/home-manager/hypridle.nix` | Modify | Wrap 3 listener on-timeout commands with `! omarchy-toggle-enabled idle-off &&` guard. Lock on-timeout → `omarchy-system-lock`, add `on-resume = "omarchy-system-wake"`. `before_sleep_cmd` → `OMARCHY_LOCK_ONLY=true omarchy-system-lock`. `ExecStartPre` clears `screensaver-off` only. Remove `Restart` override — daemon never gets manually stopped. |
| `omarchy-nix:bin/omarchy-toggle-idle` | Modify | Rewrite: check `idle-off` flag existence instead of `systemctl is-active`. Create flag on first toggle (stop locking), remove on second (resume locking). No systemctl calls. No `screensaver-off` management. Keep notification text, screensaver kill, waybar refresh. |
| `omarchy-nix:bin/omarchy-system-lock` | Modify | Add early-exit guard: when `$OMARCHY_LOCK_ONLY` is set, run `hyprlock` directly and exit. Unset path preserves full current behavior (hyprlock, keyboard reset, 1password lock, screensaver kill). |
| `omarchy-nix:bin/omarchy-system-wake` | Create | New script: `brightnessctl -r` + `hyprctl dispatch dpms on`. Called by lock listener `on-resume`. |
| `nixos-hosts:hosts/t14/home/omarchy.nix` | Modify | Remove `services.hypridle.settings = lib.mkForce { ... }` block. Flag-based disarm makes the 200s lock timeout override obsolete. |

## Interfaces / Contracts

**Flag file contract**: `~/.local/state/omarchy/toggles/idle-off` — plain file (no content). Presence = idle listeners suppressed. Checked via `omarchy-toggle-enabled idle-off` (exit 0 = flag exists).

**Environment variable**: `OMARCHY_LOCK_ONLY` — when set to any non-empty value, `omarchy-system-lock` locks session without display/keyboard side effects. Used only by `before_sleep_cmd`.

**New script**: `omarchy-system-wake` — idempotent (safe to call repeatedly). No args, no env vars.

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Build | Nix eval across hosts | `nix flake check --no-build` on nixos-hosts |
| Build | omarchy-nix eval | `nix flake check` on omarchy-nix repo |
| Unit | Flag toggle behavior | Manual: run `omarchy-toggle-idle` twice, verify flag created/removed, notifications fire |
| Integration | Listener suppression | Manual: create `idle-off` flag, verify `omarchy-toggle-enabled idle-off` returns 0 |
| Integration | OMARCHY_LOCK_ONLY | Manual: `OMARCHY_LOCK_ONLY=true omarchy-system-lock`, verify hyprlock launches without side effects |
| E2E | Full idle cycle on t14 | Manual: deploy to t14, trigger idle timeout, verify lock + wake + DPMS cycle |

## Migration / Rollout

No data migration required. The `idle-off` flag file does not exist before this change, so initial state is "idle armed" (normal behavior). Flags and scripts are already in `PATH` via omarchy-nix module.

Rollback: revert omarchy-nix commits, bump nixos-hosts flake.lock, rebuild. No state cleanup needed (stale `idle-off` flag is harmless — future builds without the guard simply ignore it).

## Open Questions

- [ ] Should `after_sleep_cmd` also call `omarchy-system-wake` instead of `hyprctl dispatch dpms on`? Currently kept separate — wake is for lock resume, after_sleep is for sleep resume. Could unify but low priority.
- [ ] Does `OMARCHY_LOCK_ONLY` guard need to also skip keyboard reset? Current design skips it for sleep path — keyboard state is preserved by kernel on suspend. Verify no edge case.
