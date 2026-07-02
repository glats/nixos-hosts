# Design: Fix T14 Black Screen After Lid-Open + Undock

## Technical Approach

Make the daemon the **single runtime authority** for all monitor positioning by branching on a 2D state matrix: **lid state (open/closed) × external presence (connected/none)**. Strip bindls to `settings.conf`-only writes. Change the static `if ENABLE_LAPTOP` block's eDP-1 position from `4920x420` to `0x0` as a safe boot-undocked default. Switch daemon from polling to socat-based event listening, adding lid switch events alongside hotplug events. Remove `hyprctl reload` from `apply()`.

## Architecture Decisions

| # | Decision | Choice | Alternative | Rationale |
|---|----------|--------|-------------|-----------|
| D1 | Event mechanism | socat on socket2 (events: `monitoradded/removed/v2`, `switchon/off`) | Keep 2s polling | Event-driven: responsive (no 2s lag), efficient, reacts to lid events instantly |
| D2 | External detection | `hyprctl monitors -j \| jq '[.[] \| select(.name != "eDP-1")] \| length'` | Check specific descriptors | Boolean check is simpler; any external → docked layout. Disconnected descriptors are no-ops in `move_to_y420` |
| D3 | Static eDP-1 position | `preferred, 0x0, 1` | `preferred, auto, 1` | Explicit `0x0` is deterministic and matches `move_to_alone()`. `auto` may place eDP-1 unpredictably when externals also present at boot |
| D4 | `hyprctl reload` | Remove entirely from `apply()` | Keep conditionally | `keyword` applies immediately; reload re-parses config and re-asserts stale static positions, causing flicker |
| D5 | Bindl scope | `settings.conf` write only | Keep full positioning in bindls | Eliminates race between bindl and daemon. Daemon has full 2D context; bindl can't check external presence reliably |
| D6 | Docs update | Update `docs/t14-monitor-layout.md` | Leave as-is | Doc currently says "enabled at 4920x420" — must reflect new 2D behavior and `move_to_alone` |

## Data Flow

```
Lid close/open ──┬──→ bindl: write settings.conf only (immediate)
                 └──→ Hyprland socket2: switchon/switchoff event
                                    │
Dock/undock ──────→ socket2: monitoradded/removed ──→ socat pipe ──→ apply()
                                                           │
                                              ┌────────────┴────────────┐
                                              │  2D Branch:             │
                                              │  lid × externals        │
                                              ├─────────────────────────┤
                                              │  closed + any → y0      │
                                              │  open + externals → y420│
                                              │  open + none → alone    │
                                              └─────────────────────────┘
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `hosts/t14/home/scripts/monitor-lid-validator.sh` | Modify | Add `has_externals()`, `move_to_alone()`, 2D branch in `apply()`, socat event loop with lid events, remove `hyprctl reload` |
| `hosts/t14/home/hypr/monitors.nix` | Modify | Strip bindls to settings.conf-only; change `if ENABLE_LAPTOP` eDP-1 from `4920x420` to `0x0` |
| `docs/t14-monitor-layout.md` | Modify | Update eDP-1 behavior table to reflect 2D branch and `move_to_alone` |

## Key Algorithms

### `apply()` — 2D Branch

```
LID_STATE ← read /proc/acpi/button/lid/LID*/state (default: "open")
if LID_STATE == "closed":
    persist(0)    # $ENABLE_LAPTOP = (empty)
    move_to_y0()  # eDP-1 disable, externals at y=0
else:  # open
    persist(1)    # $ENABLE_LAPTOP = 1
    if has_externals():
        move_to_y420()   # eDP-1 at 4920x420, externals at y=420
    else:
        move_to_alone()  # eDP-1 at 0x0
# NO hyprctl reload
```

### `has_externals()`

```bash
has_externals() {
  local count
  count=$(hyprctl monitors -j 2>/dev/null | jq '[.[] | select(.name != "eDP-1")] | length')
  [ "${count:-0}" -gt 0 ]
}
```

Returns 0 (true) if any monitor besides eDP-1 is connected. `jq` 1.8.1 is available system-wide.

### `move_to_alone()`

```bash
move_to_alone() {
  hyprctl keyword monitor "eDP-1,preferred,0x0,1"
}
```

Single command — only eDP-1 needs repositioning. No externals to position.

### Daemon Event Loop (socat-based, replaces polling)

```bash
SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
# Wait for socket to appear (Hyprland may still be starting)
while [ ! -S "$SOCKET" ]; do sleep 1; done

socat -U - "$SOCKET" | stdbuf tr '\0' '\n' | \
  grep --line-buffered -E '^(monitoradded|monitorremoved|monitoraddedv2|monitorremovedv2|switchon|switchoff)>>' | \
  while IFS= read -r _event; do
    sleep 0.5
    apply
  done
```

- `switchon>>Lid Switch` = lid closed; `switchoff>>Lid Switch` = lid open
- `--line-buffered` prevents grep from buffering (critical for real-time pipe)
- `sleep 0.5` debounces rapid hotplug bursts (same as current)
- Pipeline exit (socket disappears on Hyprland restart) → daemon exits → systemd `Restart=on-failure` restarts

### New Bindls (settings.conf only)

```nix
# Lid close — persist only. Daemon handles monitor positioning via socat.
bindl = , switch:on:.*[Ll]id.*, exec, printf '$ENABLE_LAPTOP =\n' > $HOME/.config/hypr/settings.conf
# Lid open — persist only. Daemon handles monitor positioning via socat.
bindl = , switch:off:.*[Ll]id.*, exec, printf '$ENABLE_LAPTOP = 1\n' > $HOME/.config/hypr/settings.conf
```

### Static Block Change (`if ENABLE_LAPTOP`)

```nix
# Before:
monitor = eDP-1, preferred, 4920x420, 1
# After:
monitor = eDP-1, preferred, 0x0, 1
```

Externals in the same block keep `y=420` positions unchanged (dead-zone fix preserved).

## Error Handling

| Failure | Behavior | Mitigation |
|---------|----------|------------|
| Daemon not running | Static config + bindls only. Boot-undocked: safe (eDP-1 at 0x0). Boot-docked: wrong layout until daemon starts | systemd `Restart=on-failure`, `RestartSec=5` |
| `hyprctl keyword` fails | Non-fatal (no `set -e`). Independent commands — partial apply possible. Next event retries full `apply()` | socat events trigger retry; daemon restart on persistent failure |
| socat pipe breaks | Daemon exits → systemd restarts | `Restart=on-failure` handles reconnection to new socket |
| `jq` not in PATH | `has_externals()` returns false → `move_to_alone()` fallback | `jq` 1.8.1 confirmed in `/run/current-system/sw/bin` |

## Testing Strategy

| Layer | What | Approach |
|-------|------|----------|
| Build | Nix flake check | `nix flake check --no-build` — verifies derivation builds |
| Manual | 9 scenarios from spec | Physical lid/dock testing on t14 |
| Regression | Dead-zone fix preserved | Verify y=420 when docked with lid open |

## Migration / Rollout

No migration required. Single `nixos-build switch` applies both file changes atomically. Daemon restarts automatically via systemd. `docs/t14-monitor-layout.md` updated to reflect new 2D behavior.

## Open Questions

None.
