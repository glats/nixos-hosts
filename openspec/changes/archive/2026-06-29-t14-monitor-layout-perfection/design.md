# Design: T14 Monitor Layout Perfection

## Technical Approach (Final)

Three-layer architecture for monitor layout management:

1. **Parse-time** — hyprlang conditionals read `$ENABLE_LAPTOP` from `settings.conf` and select correct externals position (y=420 vs y=0) at config load time
2. **Boot-time** — systemd daemon (`monitor-lid-validator.service`) runs after `graphical-session.target`, corrects any state mismatch, then polls for monitor changes
3. **Runtime** — lid-switch `bindl` fires on open/close, updates `settings.conf` + applies via `hyprctl keyword` for all 4 outputs

omarchy-nix provides two generic building blocks: `monitoradded` handler (triggers `hyprctl reload` on dock) and `lidSwitch.enable` option (allows opt-out of default lid bindl).

## Architecture Decisions (as evolved through iterations)

### Decision: Parse-time conditionals (not runtime-only)

**Choice**: Use `# hyprlang if ENABLE_LAPTOP` / `# hyprlang if !ENABLE_LAPTOP` blocks in `extraConfig` to position externals at parse time.

**Rationale**: The dead zone existed because externals were positioned at y=420 regardless of lid state at config load time. Parse-time conditionals eliminate the dead zone from the first frame — no runtime fixup needed.

### Decision: Empty value for $ENABLE_LAPTOP (not 0)

**Choice**: Disabled state uses `$ENABLE_LAPTOP =` (empty), enabled uses `$ENABLE_LAPTOP = 1`.

**Rationale**: Hyprlang preprocessor treats any non-empty value as truthy, including `0`. This was discovered as Bug 5 during implementation. The empty string is the only reliable "falsy" value in hyprlang.

### Decision: systemd service (not exec-once)

**Choice**: `monitor-lid-validator.service` with `Type=simple`, `After=graphical-session.target`.

**Evolution**: Started as `exec-once` inline bash. After 4 format variants (direct path, `$HOME`, literal path, full bash -c) all failed silently for some edge case, migrated to systemd oneshot service, then to daemon.

**Rationale**: systemd services have deterministic lifecycle management, environment control, and restart policies. `exec-once` in Hyprland is unreliable for complex commands.

### Decision: Polling loop (not socat event-driven)

**Choice**: 2s polling of `hyprctl monitors -j` in a `while true; sleep 2` loop.

**Evolution**: Initially attempted `socat UNIX-CONNECT:$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock` for event-driven monitoring. However, socat is not in `PATH` inside systemd user services (it's a NixOS system package, not in the user service's restricted PATH). Polling is simpler and avoids this PATH issue.

### Decision: Lid-state-only validator (not DRM + external detection)

**Choice**: Validator reads lid state from `/proc/acpi/button/lid/LID*/state`, applies layout based on lid open/closed.

**Evolution**: Original validator had 3 branches: (1) externals connected + lid closed → disable eDP-1, (2) no externals → enable eDP-1, (3) lid open with externals → keep eDP-1 + y=420. This required `omarchy-hw-external-monitors` which reads `/sys/class/drm` — racing with DRM probe.

**Rationale**: With `udevadm settle` ensuring DRM probe, and the lid switch being the only trigger for state changes, the validator only needs to know lid state. Two branches (open/closed) covers all cases. The `udevadm settle` is kept as belt-and-suspenders.

### Decision: Always apply (not state-check optimization)

**Choice**: The daemon always calls `apply()` on every loop iteration.

**Evolution**: Originally had a state-tracking optimization that skipped `apply()` if stored state matched current state. This was Bug 6 — after a first failed run, the validator would skip all subsequent runs.

**Rationale**: `hyprctl keyword` is idempotent. Always-applying costs ~50ms per 2s loop and eliminates an entire class of state-tracking bugs.

### Decision: Auto-detect HYPRLAND_INSTANCE_SIGNATURE

**Choice**: If `HYPRLAND_INSTANCE_SIGNATURE` is not set, auto-detect via `ls -t "$XDG_RUNTIME_DIR/hypr/" | head -1`.

**Rationale**: systemd user services do not inherit `HYPRLAND_INSTANCE_SIGNATURE` from the user session. Without it, `hyprctl` silently fails. Auto-detection handles both the systemd service context and interactive execution.

### Decision: `home.activation` for settings.conf (not home.file)

**Choice**: `home.activation.seedHyprSettings` writes settings.conf via shell `printf` at activation time.

**Evolution**: Started with `home.file.".../settings.conf".text = '$ENABLE_LAPTOP = 1\n'`. This creates a Nix store symlink that's read-only. The bindl's `printf ... > settings.conf` silently failed.

**Rationale**: The file must be writable at runtime. `home.activation` runs shell commands directly, creating a regular writable file. Conditionally creates if not exists (preserving state across HM activations).

### Decision: Duplicate externals in two conditional blocks

**Choice**: Two `# hyprlang if/endif` blocks for externals (6 monitor lines each, ~12 extra lines total).

**Rationale**: Hyprlang preprocessor has no `else`/`else if` — must duplicate with negated condition. Parse-time correctness eliminates the dead zone without any runtime fixup.

### Decision: omarchy `lidSwitch.enable` as submodule

**Choice**: `omarchy.hyprland.lidSwitch.enable` nested in a new `hyprland` submodule.

**Rationale**: Follows the established submodule pattern (`greeter`, `seamless_boot`, `nvidia`). Clean namespace for future Hyprland-specific options.

### Decision: `lib.optionals` wrapping for switchBindings

**Choice**: `switchBindings = lib.optionals cfg.hyprland.lidSwitch.enable [...]`.

**Rationale**: `mkBindl []` produces `""` (verified), so an empty list is harmless. No change needed at the template rendering site.

## Data Flow (Final)

```
BOOT SEQUENCE:
┌─────────────────────────────────────────────────────────────────────────┐
│ 1. Kernel loads DRM modules → udev queues device events                │
│ 2. systemd starts wayland-wm@hyprland.desktop.service                  │
│    ├── ExecStartPre: udevadm settle --timeout=10  (wait for DRM probe)  │
│    └── ExecStart: uwsm aux exec → Hyprland                             │
│ 3. Hyprland parses hyprland.conf:                                      │
│    ├── source = settings.conf → reads $ENABLE_LAPTOP from last session │
│    ├── # hyprlang if ENABLE_LAPTOP  → eDP-1 enabled, externals y=420  │
│    ├── # hyprlang if !ENABLE_LAPTOP → eDP-1 disabled, externals y=0   │
│    └── workspace rules bind to present monitors                        │
│ 4. graphical-session.target reached                                   │
│ 5. monitor-lid-validator.service starts:                               │
│    ├── apply(): reads lid state, applies correct layout                 │
│    ├── persist(): writes to settings.conf                              │
│    ├── hyprctl reload: re-applies config with corrected state          │
│    └── Enter 2s polling loop                                           │
│ 6. omarchy-hyprland-monitor-watch starts (exec-once from omarchy):     │
│    └── Listens for monitoradded/removed → hyprctl reload               │
└─────────────────────────────────────────────────────────────────────────┘

LID CLOSE:
┌─────────────────────────────────────────────────────────────────────────┐
│ 1. Hyprland fires switch:on:Lid Switch event                           │
│ 2. T14 bindl matches (regex .*[Ll]id.*):                               │
│    ├── printf '$ENABLE_LAPTOP =\n' > settings.conf (empty = disabled)  │
│    ├── hyprctl keyword monitor "eDP-1,disable"                         │
│    ├── hyprctl keyword monitor "AOC 24P1W1...,0x0,1,transform,1"      │
│    ├── hyprctl keyword monitor "Lenovo...,1080x0,1"                     │
│    └── hyprctl keyword monitor "AOC 2470W...,3000x0,1"                 │
│ 3. (omarchy bindl does NOT fire — lidSwitch.enable = false)            │
│ 4. No race, no flicker                                                 │
└─────────────────────────────────────────────────────────────────────────┘

LID OPEN:
┌─────────────────────────────────────────────────────────────────────────┐
│ 1. Hyprland fires switch:off:Lid Switch event                          │
│ 2. T14 bindl matches:                                                   │
│    ├── printf '$ENABLE_LAPTOP = 1\n' > settings.conf                   │
│    ├── hyprctl keyword monitor "eDP-1,preferred,4920x420,1"            │
│    ├── hyprctl keyword monitor "AOC 24P1W1...,0x420,1,transform,1"     │
│    ├── hyprctl keyword monitor "Lenovo...,1080x420,1"                   │
│    └── hyprctl keyword monitor "AOC 2470W...,3000x420,1"               │
└─────────────────────────────────────────────────────────────────────────┘

DOCK/UNDOCK (mid-session):
┌─────────────────────────────────────────────────────────────────────────┐
│ 1. omarchy-hyprland-monitor-watch detects monitoradded/removed         │
│    └── hyprctl reload (generic, from omarchy-nix)                      │
│ 2. monitor-lid-validator.sh daemon detects monitor change via polling   │
│    └── apply(): re-applies layout based on current lid state           │
│ 3. Both layers fire — idempotent, no conflict                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## File Changes (Final — As Delivered)

### omarchy-nix (3 files)

| File | Lines | Change |
|------|-------|--------|
| `bin/omarchy-hyprland-monitor-watch` | +3 | Added `monitoradded>>|monitoraddedv2>>) hyprctl reload;;` case |
| `config.nix` | +21 | Added `hyprland` submodule with `lidSwitch.enable` option |
| `modules/home-manager/hyprland/bindings.nix` | +1/-1 | Wrapped `switchBindings` in `lib.optionals` |

### nixos-hosts (5 files, 16+ commits)

| File | Lines | Change |
|------|-------|--------|
| `hosts/t14/home/hypr/monitors.nix` | +40/-10 | Removed `lib.mkForce`, added conditionals, workspace rules, bindl with regex+all-4-outputs |
| `hosts/t14/home/scripts/monitor-lid-validator.sh` | +71 | New file: standalone daemon script with --daemon/--apply-once modes |
| `hosts/t14/home/default.nix` | +50/-10 | systemd service, udev-settle drop-in, activation script, validator deployment |
| `hosts/t14/default.nix` | +1 | `omarchy.hyprland.lidSwitch.enable = false` |
| `flake.lock` | auto | Multiple omarchy-nix bumps |

## Script Architecture: `monitor-lid-validator.sh`

```
#!/usr/bin/env bash
SETTINGS="$HOME/.config/hypr/settings.conf"
HIS_DIR="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE"

# Auto-detect HYPRLAND_INSTANCE_SIGNATURE if not set
if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  export HYPRLAND_INSTANCE_SIGNATURE=$(ls -t "$XDG_RUNTIME_DIR/hypr/" | head -1)
fi

# move_to_y420()  — hyprctl keyword for all 4 outputs at y=420
# move_to_y0()    — hyprctl keyword for all 4 outputs at y=0
# persist(1|0)    — write $ENABLE_LAPTOP = 1|<empty> to settings.conf

apply() {
  read lid_state from /proc/acpi/button/lid/LID*/state
  if closed → persist 0 + move_to_y0
  if open  → persist 1 + move_to_y420
  hyprctl reload
}

monitor_snapshot() { hyprctl monitors -j | grep '"name"' | sort; }

case $1 in
  --daemon)    apply; loop: sleep 2; if snapshot changed → apply ;;
  --apply-once) apply ;;
  *)           apply ;;
esac
```

## Testing Strategy (as actually performed)

| Layer | Test | Result |
|-------|------|--------|
| Build (omarchy-nix) | `nix flake check --no-build` | Passed |
| Build (nixos-hosts) | `nix flake check --no-build` | Passed |
| Format | `format-nix` | Passed |
| Config grep | Conditionals present in generated config | Confirmed |
| Config grep | No omarchy bindl when lidSwitch.enable = false | Confirmed |
| Settings writable | settings.conf not Nix store symlink | Confirmed (home.activation) |
| hyprlang truthiness | `$ENABLE_LAPTOP =` empty correctly disabled eDP-1 | Confirmed (compare: `= 0` failed) |
| Regex | `.*[Ll]id.*` matches `Lid Switch` | Confirmed |
| ALL 4 outputs | bindl repositions all externals, not just eDP-1 | Confirmed |
| PATH validation | socat, udevadm paths | socat → polling loop; udevadm → absolute path |
| HYPRLAND_INSTANCE_SIGNATURE | Auto-detect works in systemd service | Confirmed |

## Migration / Rollout

**Order**: omarchy-nix PR first (adds option + handler), then nixos-hosts commits. Multiple flake bumps happened across the 16+ commits as omarchy-nix was iterated.

**Rollback**: Revert nixos-hosts commits in reverse chronological order, or reset to commit before `759a6ed`. omarchy-nix changes are backward-compatible by default.

## Open Questions (resolved during implementation)

- [x] Should settings.conf use `0` or empty for disabled? → Empty (hyprlang truthiness bug)
- [x] Should validator use exec-once or systemd service? → systemd service (exec-once unreliable)
- [x] Should daemon use socat or polling? → Polling (socat not in PATH)
- [x] Should validator check DRM/externals or lid only? → Lid only (simpler, more robust)
- [x] Should state-check optimization be kept? → Removed (caused no-op after first run)
