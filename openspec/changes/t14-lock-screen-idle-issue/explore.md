## Exploration: t14-lock-screen-idle-issue (Merged — includes Arch vs Nix comparative analysis)

### Current State (Recap from Initial Exploration)

The t14 host runs Hyprland via omarchy-nix. The idle/lock/screensaver pipeline:

1. **hypridle** (Home Manager systemd user service) auto-starts on login via `WantedBy = graphical-session.target`
2. After 150s idle: `omarchy-launch-screensaver` launches TTE-based screensaver (unless `screensaver-off` flag exists)
3. After 200s idle: `loginctl lock-session` triggers lock via PAM / hyprlock
4. After 330s idle: DPMS display off (`hyprctl dispatch dpms off`)
5. `omarchy-system-lock` is the `lock_cmd` for `inhibit_sleep` / general lock

User's t14 override (lines 175-198 of `hosts/t14/home/omarchy.nix`):
- Does NOT set `services.hypridle.enable = false`
- Only adjusts timeouts: lock delayed from 151s to 200s (gives 50s screensaver visibility)
- Lock listener at 200s still fires `loginctl lock-session`

Runtime toggles exist but are SESSION-LOCAL only.

### Part 1: Arch Omarchy (basecamp/omarchy) — How It Works

#### 1.1. hypridle config (`config/hypr/hypridle.conf`)

Arch uses a flat INI-style config file, NOT Nix settings:

```ini
general {
    lock_cmd = omarchy-system-lock
    before_sleep_cmd = OMARCHY_LOCK_ONLY=true omarchy-system-lock
    after_sleep_cmd = sleep 1 && omarchy-system-wake
    inhibit_sleep = 3
}

# Screensaver: 150s (2.5 minutes)
listener {
    timeout = 150
    on-timeout = pidof hyprlock || omarchy-launch-screensaver
}

# Lock: 152s (2s after screensaver starts — screensaver resets idle timer)
listener {
    timeout = 152
    on-timeout = omarchy-system-lock
    on-resume = omarchy-system-wake
}
```

**Key observations**:
- **No DPMS timeout listener** — Arch does NOT have a 330s DPMS listener. Screen-off is handled by the lock script (3s after lock, `omarchy-brightness-display off` via `omarchy-system-lock` when `OMARCHY_LOCK_ONLY != true`)
- **`on-resume` present** — lock listener has `on-resume = omarchy-system-wake` to restore display + keyboard brightness
- **`before_sleep_cmd` uses `OMARCHY_LOCK_ONLY=true`** — locks before suspend but avoids DPMS scheduling on sleep (preserves display state)
- **Lock listener calls `omarchy-system-lock` directly** — consistent with `lock_cmd`, not `loginctl lock-session`

#### 1.2. `omarchy-toggle-idle` (Arch)

```bash
if pgrep -x hypridle >/dev/null; then
  pkill -x hypridle
  notify-send "Stop locking computer when idle"
else
  uwsm-app -- hypridle >/dev/null 2>&1 &
  notify-send "Now locking computer when idle"
fi
pkill -RTMIN+9 waybar
```

**Behavior**: Kills/launches hypridle process directly (not systemd). Does NOT manage screensaver-off flag. All-or-nothing: disabling idle kills hypridle, which eliminates screensaver + lock + any hypridle behavior. Re-enabling re-launches via uwsm.

#### 1.3. `omarchy-toggle-screensaver` (Arch)

```bash
omarchy-toggle \
  --enabled-notification "Screensaver disabled" \
  --disabled-notification "Screensaver enabled" \
  screensaver-off
```

Only toggles the `screensaver-off` flag file. Does NOT stop hypridle. Does NOT prevent locking.

#### 1.4. `omarchy-system-lock` (Arch)

```bash
if ! pidof hyprlock >/dev/null; then
  ( hyprlock; omarchy-system-wake ) &
fi
hyprctl switchxkblayout all 0 > /dev/null 2>&1
if pgrep -x "1password" >/dev/null; then
  1password --lock &
fi
pkill -f org.omarchy.screensaver

if [[ ${OMARCHY_LOCK_ONLY:-false} != "true" ]]; then
  ( sleep 3; pidof hyprlock >/dev/null || exit 0;
    omarchy-brightness-keyboard off; omarchy-brightness-display off ) &
fi
```

**Features**: Backgrounded `hyprlock` with `omarchy-system-wake` on exit. `OMARCHY_LOCK_ONLY` flag skips DPMS off + keyboard brightness off. Keyboard reset + 1password lock + screensaver kill.

#### 1.5. `omarchy-restart-hypridle` (Arch)

```bash
omarchy-restart-app hypridle
# Which does: pkill -x hypridle && setsid uwsm-app -- hypridle
```

Restarts by killing process and re-launching via uwsm. Not a systemd operation.

#### 1.6. `omarchy-system-wake` (Arch)

```bash
omarchy-brightness-display on
omarchy-brightness-keyboard restore
```

#### 1.7. `omarchy-refresh-config` + `omarchy-refresh-hypridle` (Arch)

Arch provides `omarchy refresh config hypr/hypridle.conf` to restore factory defaults from `~/.local/share/omarchy/config/` and restart hypridle. This is a safety net if the user messes up their config.

#### 1.8. `omarchy-config screensaver` (Arch, PR #6086)

Interactive TUI for configuring screensaver options. Not present in omarchy-nix.

---

### Part 2: omarchy-nix (glats/omarchy-nix) — How It Works

#### 2.1. hypridle module (`modules/home-manager/hypridle.nix`)

```nix
services.hypridle = {
  enable = true;
  settings = {
    general = {
      lock_cmd = "omarchy-system-lock";
      before_sleep_cmd = "loginctl lock-session";        # <-- DIFFERS from Arch
      after_sleep_cmd = "hyprctl dispatch dpms on";
      ignore_dbus_inhibit = false;
      inhibit_sleep = 3;
    };
    listener = [
      { timeout = 150; on-timeout = "pidof hyprlock || omarchy-launch-screensaver"; }
      { timeout = 151; on-timeout = "loginctl lock-session"; }         # <-- DIFFERS from Arch
      { timeout = 330; on-timeout = "hyprctl dispatch dpms off";       # <-- ADDED (not in Arch)
        on-resume = "hyprctl dispatch dpms on && brightnessctl -r"; }
    ];
  };
};
# ExecStartPre clears screensaver-off flag on hypridle start
systemd.user.services.hypridle.Service.ExecStartPre = [
  "${pkgs.coreutils}/bin/rm -f %h/.local/state/omarchy/toggles/screensaver-off"
];
systemd.user.services.hypridle.Service.Restart = lib.mkForce "on-failure";
```

#### 2.2. `omarchy-toggle-idle` (Nix)

```bash
if systemctl --user is-active hypridle >/dev/null 2>&1; then
  systemctl --user stop hypridle
  # Also disable the screensaver                      # <-- ARCH DOES NOT DO THIS
  mkdir -p ~/.local/state/omarchy/toggles
  touch ~/.local/state/omarchy/toggles/screensaver-off
  # Kill any running screensaver
  pkill -f org.omarchy.screensaver 2>/dev/null || true
else
  systemctl --user start hypridle
  rm -f ~/.local/state/omarchy/toggles/screensaver-off  # <-- ARCH DOES NOT DO THIS
fi
```

**Nix-specific side effects**: Toggles BOTH hypridle AND screensaver-off flag. In Arch, toggling idle only controls hypridle process.

#### 2.3. `omarchy-toggle-screensaver` (Nix)

```bash
omarchy-toggle \
  --enabled-notification "Screensaver disabled" \
  --disabled-notification "Screensaver enabled" \
  screensaver-off
```

Identical to Arch. Does NOT stop hypridle. Does NOT prevent locking.

#### 2.4. `omarchy-system-lock` (Nix)

```bash
pidof hyprlock || hyprlock &
hyprctl switchxkblayout all 0 > /dev/null 2>&1
if pgrep -x "1password" >/dev/null; then
  1password --lock &
fi
pkill -f org.omarchy.screensaver
```

**Missing vs Arch**: No `OMARCHY_LOCK_ONLY` support. No `omarchy-system-wake` on unlock. No backgrounded `(hyprlock; omarchy-system-wake)` pattern. No DPMS/keyboard brightness off after lock.

#### 2.5. `omarchy-restart-hypridle` (Nix)

```bash
systemctl --user restart hypridle
```

#### 2.6. Missing from omarchy-nix

| Feature | Arch | omarchy-nix |
|---------|------|-------------|
| `omarchy-system-wake` | Yes | NO |
| `omarchy-refresh-config` | Yes | NO (Nix-managed config) |
| `omarchy-refresh-hypridle` | Yes | NO |
| `omarchy-config screensaver` (TUI) | Yes (PR #6086) | NO |
| `OMARCHY_LOCK_ONLY` env var support | Yes | NO |

---

### Part 3: Comparative Analysis — Key Differences

#### 3.1. Lock Mechanism Divergence

| Aspect | Arch Omarchy | omarchy-nix |
|--------|-------------|-------------|
| `lock_cmd` | `omarchy-system-lock` | `omarchy-system-lock` |
| Lock listener on-timeout | `omarchy-system-lock` | `loginctl lock-session` |
| `before_sleep_cmd` | `OMARCHY_LOCK_ONLY=true omarchy-system-lock` | `loginctl lock-session` |
| Lock listener on-resume | `omarchy-system-wake` | NONE (user removed) |

**Impact**: Arch uses a SINGLE consistent lock path (`omarchy-system-lock` everywhere). omarchy-nix uses TWO different lock paths (`omarchy-system-lock` for `lock_cmd` / inhibit_sleep, `loginctl lock-session` for idle lock and before_sleep). These two paths produce different user-visible behavior:
- `omarchy-system-lock`: launches hyprlock, resets keyboard, locks 1password, kills screensaver
- `loginctl lock-session`: tells logind to lock the session, which activates whatever PAM lock is configured (hyprlock in this case), WITHOUT the keyboard reset, 1password lock, or screensaver kill

**This is a functional regression**: When the lock listener fires after idle timeout, the Nix version does NOT lock 1password or reset the keyboard layout, but the Arch version does.

#### 3.2. `before_sleep_cmd` Behavior

| Aspect | Arch | omarchy-nix |
|--------|------|-------------|
| Command | `OMARCHY_LOCK_ONLY=true omarchy-system-lock` | `loginctl lock-session` |
| Display state on suspend lock | Preserved (LOCK_ONLY skips DPMS off) | Depends on logind PAM behavior |
| Keyboard brightness | Preserved | Unknown |
| 1password lock | Yes | No (loginctl doesn't invoke it) |
| Keyboard reset | Yes | No |

#### 3.3. Idle Toggle Side Effects

| Aspect | Arch `omarchy-toggle-idle` | Nix `omarchy-toggle-idle` |
|--------|---------------------------|---------------------------|
| Detect hypridle state | `pgrep -x hypridle` | `systemctl --user is-active hypridle` |
| Stop hypridle | `pkill -x hypridle` (SIGTERM) | `systemctl --user stop hypridle` |
| Start hypridle | `uwsm-app -- hypridle &` (uwsm) | `systemctl --user start hypridle` |
| Manages screensaver-off flag | NO | YES |
| Kills running screensaver | NO | YES |
| Persistence | Process-level (survives crashes via restart-app) | systemd-level (on-failure restart only) |

**Key risk**: The Nix toggle managing the screensaver-off flag is REDUNDANT because `ExecStartPre` clears it on hypridle start. This creates a confusing state: `omarchy-toggle-idle` sets the flag, but as soon as hypridle restarts (next login, rebuild, manual restart), the flag is cleared.

#### 3.4. DPMS Handling

| Aspect | Arch | omarchy-nix |
|--------|------|-------------|
| hypridle DPMS listener | NONE | 330s, `hyprctl dispatch dpms off` |
| Screen off on lock | Yes (3s after lock via `omarchy-system-lock`) | No (Nix lock script doesn't do this) |
| Screen on after sleep | `omarchy-system-wake` | `hyprctl dispatch dpms on` (in after_sleep_cmd) |

omarchy-nix ADDED a DPMS timeout listener that Arch does not have. This is not necessarily a problem — it's an enhancement for power saving when idle AND unlocked.

#### 3.5. Config Restoration

Arch can reset hypridle config to defaults: `omarchy refresh config hypr/hypridle.conf`. omarchy-nix cannot — config is Nix-generated and must be rebuilt. This is not a bug, just a design difference of Nix vs imperative config.

---

### Part 4: Root Cause Analysis (Updated with Comparative Findings)

#### Primary Root Cause: No persistent disable option

There is no Nix-level option to permanently disable idle locking. The user must either:
- Run `omarchy-toggle-idle` every session (runtime-only, lost on logout/rebuild)
- Manually add `services.hypridle.enable = lib.mkForce false` to their Nix config
- The Arch version has the SAME limitation: `omarchy-toggle-idle` kills hypridle, but nothing persists it

#### Secondary Cause: `omarchy-toggle-screensaver` UX trap

In BOTH Arch and Nix, `omarchy-toggle-screensaver` only blocks the screensaver (flag file check at 150s) but does NOT prevent the lock at 152s/200s. Users who run "toggle screensaver" thinking it prevents locking will be surprised when the lock still fires. This is an upstream Arch design issue, inherited by the Nix port.

#### Tertiary Cause: Nix toggle-idle manages screensaver flag unnecessarily

The Nix `omarchy-toggle-idle` also manages the `screensaver-off` flag. This is:
1. Redundant (hypridle's ExecStartPre clears it)
2. Misleading (suggests screensaver and idle are coupled when they're independent)
3. Different from Arch behavior (where toggling idle only affects hypridle process)

#### Quaternary Cause: Nix lock listener uses `loginctl`, not `omarchy-system-lock`

When the Nix lock listener fires after idle timeout (200s in t14 config), it calls `loginctl lock-session` which:
- Activates PAM lock → hyprlock appears
- Does NOT lock 1password
- Does NOT reset keyboard layout to default
- Does NOT kill the screensaver

In Arch, the lock listener calls `omarchy-system-lock` which does ALL of the above. This is a functional regression that may cause unexpected behavior.

#### Additional Finding: `before_sleep_cmd` regression

Arch uses `OMARCHY_LOCK_ONLY=true omarchy-system-lock` which locks without killing display state. Nix uses `loginctl lock-session` which goes through logind. On system sleep, the Nix user gets a different lock experience than Arch users.

---

### Part 5: Affected Areas (Updated)

#### In nixos-hosts (t14 config)
- `hosts/t14/home/omarchy.nix` (lines 171-198) — hypridle settings override
- `hosts/t14/home/hypr/hyprlock.nix` — hyprlock config
- `hosts/t14/home/default.nix` — imports hyprlock.nix
- `modules/base/logind.nix` — sets `IdleAction = "ignore"` (NOT imported in t14, but default is also "ignore")

#### In omarchy-nix repo
- `modules/home-manager/hypridle.nix` — upstream hypridle config (differs from Arch in 3 ways)
- `modules/home-manager/hyprlock.nix` — upstream hyprlock config
- `bin/omarchy-toggle-idle` — manages both hypridle AND screensaver flag (Arch divergence)
- `bin/omarchy-toggle-screensaver` — flag file toggle only (identical to Arch)
- `bin/omarchy-system-lock` — simplified lock script (missing OMARCHY_LOCK_ONLY, wake, DPMS off)
- `bin/omarchy-restart-hypridle` — systemd restart (vs Arch's process restart)
- `bin/omarchy-toggle` — generic flag toggle (identical to Arch)
- `bin/omarchy-launch-screensaver` — screensaver launcher
- `modules/nixos/system.nix` (line 84) — `security.pam.services.hyprlock = {}`

#### Missing from omarchy-nix
- `bin/omarchy-system-wake` — does NOT exist (used by Arch for on-resume and after lock)
- `bin/omarchy-refresh-config` — does NOT exist (Nix manages config declaratively)
- `bin/omarchy-refresh-hypridle` — does NOT exist
- `bin/omarchy-config` (screensaver TUI) — does NOT exist

---

### Part 6: Approaches (Updated)

#### 1. Disable hypridle entirely (Nix-level, persistent)
`services.hypridle.enable = lib.mkForce false;` in t14 config.
- **Pros**: Complete disable. One line. Persistent across rebuilds/logins.
- **Cons**: Loses ALL idle features: screensaver, DPMS off for power saving.
- **Effort**: Low

#### 2. Remove lock listener only, keep screensaver + DPMS (Nix-level, persistent)
Override `services.hypridle.settings.listener` to exclude the lock entry. Also change `before_sleep_cmd`.
- **Pros**: Keeps DPMS off for power saving. Keeps screensaver. Only removes lock behavior.
- **Cons**: Requires configuring multiple sub-fields. Need to decide what `before_sleep_cmd` should be.
- **Effort**: Low

#### 3. Fix `omarchy-toggle-idle` alignment with Arch (upstream fix)
Remove the screensaver-off flag management from the Nix toggle-idle script. Let `omarchy-toggle-idle` only control hypridle (matching Arch behavior).
- **Pros**: Restores Arch behavioral parity. Cleans up confusing dual-management.
- **Cons**: Requires PR to omarchy-nix repo. Doesn't directly fix the user's issue.
- **Effort**: Low (code change is small), Medium (PR + review cycle)

#### 4. Add OMARCHY_LOCK_ONLY support to omarchy-nix lock script (upstream fix)
Port the `OMARCHY_LOCK_ONLY` env var pattern from Arch, restoring smarter before_sleep behavior.
- **Pros**: Restores Arch feature parity. Better user experience on system sleep.
- **Cons**: Requires PR to omarchy-nix repo. Not directly related to the idle lock issue.
- **Effort**: Medium

#### 5. Add persistent toggle state via Nix option (upstream + downstream)
Create an `omarchy.disableIdleLock` option. When true, wraps `services.hypridle.enable = false`. When false, uses default. User can toggle via rebuild.
- **Pros**: Persistent, intentional, controllable via Nix.
- **Cons**: Requires module changes in omarchy-nix. User must rebuild to change.
- **Effort**: Medium

#### 6. Make the runtime toggle persist across sessions (upstream fix)
Modify `omarchy-toggle-idle` to save state to disk and restore on login. This is the closest to "Arch behavior plus persistence."
- **Pros**: User keeps familiar toggle workflow. No Nix rebuild needed for state change.
- **Cons**: Requires upstream changes. Complex: state file, login hook, conflict with ExecStartPre.
- **Effort**: High

---

### Part 7: Recommendation (Updated)

**Immediate fix (user's t14 config)**: Approach 2 — remove the lock listener but keep screensaver and DPMS.

This is the best balance:
- Permanently prevents unwanted idle locking (the user's stated need)
- Preserves power-saving DPMS auto-off at 330s (important for a laptop)
- Preserves screensaver at 150s
- No upstream changes needed (change is fully local to t14)
- Also fix `before_sleep_cmd` to avoid lock on sleep if user wants zero-lock

Recommended configuration:

```nix
services.hypridle.settings = lib.mkForce {
  general = {
    lock_cmd = "omarchy-system-lock";
    before_sleep_cmd = "hyprctl dispatch dpms off";  # Only DPMS off on sleep, no lock
    after_sleep_cmd = "hyprctl dispatch dpms on";
    ignore_dbus_inhibit = false;
    inhibit_sleep = 3;
  };
  listener = [
    {
      timeout = 150;
      on-timeout = "pidof hyprlock || omarchy-launch-screensaver";
    }
    # Lock listener REMOVED
    {
      timeout = 330;
      on-timeout = "hyprctl dispatch dpms off";
      on-resume = "hyprctl dispatch dpms on && brightnessctl -r";
    }
  ];
};
```

**Upstream fix (omarchy-nix repo)**: Approach 3 — align `omarchy-toggle-idle` with Arch behavior by removing screensaver-off flag management. This is a quality-of-life improvement that prevents user confusion but is not critical to the user's immediate problem.

**Lower-priority upstream fix**: Approach 4 — port OMARCHY_LOCK_ONLY and omarchy-system-wake from Arch. This restores feature parity but is independent of the lock-disable issue.

---

### Part 8: Risks (Updated)

1. **DPMS off lost with Approach 1**: On a laptop, losing DPMS auto-off means screen stays on indefinitely, wasting battery. Prefer Approach 2.

2. **`before_sleep_cmd` with `loginctl lock-session`**: Even with lock listener removed, the current `before_sleep_cmd` still locks on system sleep. Must be changed if user wants zero-lock behavior.

3. **Nix lock listener uses `loginctl`, not `omarchy-system-lock`**: This is a functional regression vs Arch that affects 1password locking, keyboard reset, and screensaver kill on idle lock. Not directly related to the disable-lock ask, but worth noting.

4. **Hypridle restart from omarchy-nix overriding**: Currently safe (`Restart = "on-failure"`), but if omarchy-nix upgrades to `Restart = "always"`, manual systemctl stop would be defeated.

5. **`omarchy-system-lock` still available**: Even with hypridle lock listener removed, the lock script is still on PATH and could be invoked by keybinds or other mechanisms.

6. **`ExecStartPre` clearing screensaver-off**: If the user manages to start hypridle while `omarchy-toggle-idle` set the screensaver-off flag, ExecStartPre clears it. This makes the flag effectively session-local, which is good (no stale state) but means the toggle-idle's flag management is wasted work.

---

### Ready for Proposal

Yes — the root cause is clear, the Arch-vs-Nix comparison reveals specific divergences, and multiple fix approaches are available at different effort levels and scopes (t14-local vs omarchy-nix upstream).
