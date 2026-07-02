# Design: fix-screensaver-idle-lock

## Technical Approach

Four surgical edits across two repos. Fix the caffeine toggle to also flip the `screensaver-off` flag (matching what `omarchy-launch-screensaver` already checks at line 19). Fix the multi-monitor focus race with per-iteration sleep + error check + trailing `wait`. Remove the now-redundant `ExecStopPost` workaround from t14 local config. Bump the flake input to deploy.

## Architecture Decisions

### Decision: Where to put the screensaver kill on toggle-off

**Choice**: Add `pkill -f org.omarchy.screensaver` to `omarchy-toggle-idle` stop branch, then remove `ExecStopPost` from t14.
**Alternatives considered**: Keep `ExecStopPost` as safety net; rely on hyprlock at 200s to kill screensaver.
**Rationale**: Without either mechanism, a screensaver already running when the user presses `Super+Ctrl+I` would persist until hyprlock fires at 200s. Moving the kill into the toggle script itself is more explicit, self-documenting, and works for all omarchy-nix users — not just t14.

### Decision: Flag creation pattern

**Choice**: Use `mkdir -p` + `touch` (mirroring `omarchy-toggle` helper at line 13-14).
**Alternatives considered**: Bare `touch` (fails if dir missing).
**Rationale**: `~/.local/state/omarchy/toggles/` exists on this system but only contains `hypr/`. The `screensaver-off` flag has never been created by `omarchy-toggle-idle` before. `mkdir -p` is idempotent and matches the existing `omarchy-toggle` pattern exactly.

### Decision: Sleep duration for focus settle

**Choice**: `sleep 0.3` (300ms per monitor).
**Alternatives considered**: 200ms (exploration estimate), 500ms (conservative).
**Rationale**: 300ms is enough for Hyprland to process `focusmonitor` and apply window rules before the next `dispatch exec`. With 4 monitors: ~1.2s total latency. Acceptable because the screensaver fires at 150s idle — user is already away.

## Data Flow

```
Super+Ctrl+I
    │
    ▼
omarchy-toggle-idle
    │
    ├─[stop]──► systemctl --user stop hypridle
    │           touch ~/.local/state/omarchy/toggles/screensaver-off  ← NEW
    │           pkill -f org.omarchy.screensaver                      ← NEW
    │           notify-send "Stop locking..."
    │
    └─[start]──► systemctl --user start hypridle
                 rm -f ~/.local/state/omarchy/toggles/screensaver-off ← NEW
                 notify-send "Now locking..."
    │
    └─► pkill -RTMIN+9 waybar  (refresh indicator)

hypridle timer (150s idle)
    │
    ▼
omarchy-launch-screensaver
    │
    ├─ check screensaver-off flag (line 19) → exit if set
    ├─ for each monitor:
    │     focusmonitor "$m"  →  check rc  →  skip if failed   ← CHANGED
    │     sleep 0.3                                            ← NEW
    │     dispatch exec -- terminal ...
    │     wait                                                 ← NEW
    └─ focusmonitor $focused  (restore original)
```

## File Changes

| File | Repo | Action | Description |
|------|------|--------|-------------|
| `bin/omarchy-toggle-idle` | omarchy-nix | Modify | Add flag flip + screensaver kill on stop; flag removal on start |
| `bin/omarchy-launch-screensaver` | omarchy-nix | Modify | Add focusmonitor error check, sleep 0.3, wait |
| `hosts/t14/home/omarchy.nix` | nixos-hosts | Modify | Remove `ExecStopPost` override (lines 156-159) |
| `flake.lock` | nixos-hosts | Auto | Updated by `nix flake update --input omarchy-nix` |

## Exact Line-Level Changes

### Fix 1: `bin/omarchy-toggle-idle` (omarchy-nix)

**Before** (lines 5-11):
```bash
if systemctl --user is-active hypridle >/dev/null 2>&1; then
  systemctl --user stop hypridle
  notify-send -u low "󱫖    Stop locking computer when idle"
else
  systemctl --user start hypridle
  notify-send -u low "󱫖    Now locking computer when idle"
fi
```

**After**:
```bash
if systemctl --user is-active hypridle >/dev/null 2>&1; then
  systemctl --user stop hypridle
  mkdir -p ~/.local/state/omarchy/toggles
  touch ~/.local/state/omarchy/toggles/screensaver-off
  pkill -f org.omarchy.screensaver 2>/dev/null || true
  notify-send -u low "󱫖    Stop locking computer when idle"
else
  systemctl --user start hypridle
  rm -f ~/.local/state/omarchy/toggles/screensaver-off
  notify-send -u low "󱫖    Now locking computer when idle"
fi
```

Lines added: 4 (mkdir+touch+pkill on stop branch, rm on start branch).

### Fix 2: `bin/omarchy-launch-screensaver` (omarchy-nix)

**Before** (lines 29-31):
```bash
for m in $(hyprctl monitors -j | jq -r '.[] | .name'); do
  hyprctl dispatch focusmonitor $m

  case $terminal in
```

**After**:
```bash
for m in $(hyprctl monitors -j | jq -r '.[] | .name'); do
  if ! hyprctl dispatch focusmonitor "$m" >/dev/null 2>&1; then
    notify-send -u low "⚠  Could not focus $m — skipping"
    continue
  fi
  sleep 0.3

  case $terminal in
```

**Before** (line 57-59):
```bash
done

hyprctl dispatch focusmonitor $focused
```

**After**:
```bash
done
wait

hyprctl dispatch focusmonitor $focused
```

Lines added: 6 (error check + sleep in loop, wait after loop). Also quotes `$m` → `"$m"` in focusmonitor call.

### Fix 3: `hosts/t14/home/omarchy.nix` (nixos-hosts)

**Remove** lines 156-159:
```nix
  # Kill screensaver when hypridle stops (e.g., via Ctrl+Super+I toggle).
  # Without this, the screensaver keeps running even after idle is disabled.
  systemd.user.services.hypridle.Service.ExecStopPost =
    lib.mkForce "${pkgs.pkgsBuildBuild.bash}/bin/bash -c 'pkill -f omarchy-screensaver 2>/dev/null || true'";
```

This block (comment + 3 code lines) is deleted entirely. The kill is now handled by `omarchy-toggle-idle` upstream.

### Fix 4: `flake.lock` (nixos-hosts)

After upstream commits land in `omarchy-nix`:
```bash
cd ~/repos/omarchy-nix && git push origin main
cd ~/.nixos && nix flake lock --update-input omarchy-nix
```

This updates `flake.lock` to point at the new commit SHA. No manual edit to `flake.nix` — the URL `github:glats/omarchy-nix/main` already tracks `main`.

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Manual | `Super+Ctrl+I` stops hypridle + creates flag + kills screensaver | Press shortcut, verify `ls ~/.local/state/omarchy/toggles/screensaver-off`, verify no screensaver after 150s |
| Manual | Toggle back removes flag + restarts hypridle | Press shortcut again, verify flag gone, verify `systemctl --user is-active hypridle` |
| Manual | Screensaver on all 4 monitors after 150s idle | Wait for timeout, verify ghostty fullscreen on eDP-1 + 3 externals |
| Validation | `nix flake check --no-build` passes | Run after flake lock update |

## Migration / Rollout

No migration required. The changes are:
1. Two upstream commits to `omarchy-nix` (push to main)
2. `nix flake lock --update-input omarchy-nix` in nixos-hosts
3. Remove `ExecStopPost` block in `hosts/t14/home/omarchy.nix`
4. `nixos-rebuild switch` on t14

Rollback: `git revert` the two upstream commits + revert flake lock + restore `ExecStopPost`.

## Open Questions

None.
