# Design: Waybar Workspace Switch Crash Fix

## Technical Approach

Two complementary fixes eliminate the waybar crash on workspace switches:
1. **ext/workspaces** replaces hyprland/workspaces — removes socket2 IPC crash surface entirely
2. **systemd Restart=always** — safety net for any remaining crash vectors

## Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| IPC module | ext/workspaces (ext-workspace-v1 Wayland protocol) | hyprland/workspaces uses socket2 IPC with blocking socket1 calls while holding mutexes — fundamentally crash-prone. ext/workspaces dispatches on compositor main thread, zero IPC. |
| Process manager | systemd user service (`Restart=always`) | uwsm-app runs as transient scope (`systemd-run --scope`, Restart=no). Proper service unit survives crashes. Same lifecycle via `WantedBy=graphical-session.target`. |
| Restart timing | 100ms RestartSec | systemd treats RestartSec=0 as "use default" (100ms). Explicit 100ms prevents thrashing without adding measurable delay. |
| Rate limiting | StartLimitBurst=20 / 5s | Default 5 restarts in 10s would kill waybar during rapid workspace cycling. Increased to 20 allows bursts without infinite-loop risk. |
| Config location | Shared omarchy-nix `config/waybar/config` | Single source of truth for all Hyprland hosts. ext-workspace-v1 requires Hyprland ≥ 0.52.1 — all omarchy hosts meet this. |

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `omarchy-nix/config/waybar/config` | Modify | hyprland/workspaces → ext/workspaces with `all-outputs:true`, `on-click:activate`, `format:"{icon}"`, `format-icons` for ws 1-20 |
| `omarchy-nix/modules/.../autostart.nix` | Modify | Line 14: `pkill -x waybar; uwsm-app -- waybar 2>>...` → `systemctl --user restart waybar \|\| systemctl --user start waybar` |
| `omarchy-nix/bin/omarchy-toggle-waybar` | Modify | Replace `pkill -f` + `uwsm-app` with `systemctl --user is-active/stop/start waybar` |
| `hosts/t14/home/default.nix` | Modify | Add `systemd.user.services.waybar` alongside existing `monitor-lid-validator` service |
| `flake.nix` | Modify | Remove `waybar-src` input (lines 113-117) — dead code from reverted overlay |
| `flake.lock` | Regenerate | Auto-updated by `nix flake update omarchy-nix` after omarchy-nix commits are pushed |

### NO-OP: omarchy-nix/bin/omarchy-hyprland-monitor-watch

Verified both pinned (`f6b5a93`) and origin/main HEAD — file only handles `monitorremoved`, **no `monitoradded>>` reload handler exists**. No change required. Previously reported as "Phase 2 never applied" — the pinned version was already clean.

## Design 1: Waybar Config (exact diff)

```diff
# omarchy-nix/config/waybar/config

--- a/config/waybar/config
+++ b/config/waybar/config
-  "modules-left": ["custom/omarchy", "hyprland/workspaces"],
+  "modules-left": ["custom/omarchy", "ext/workspaces"],

-  "hyprland/workspaces": {
-    "format": "{name}"
+  "ext/workspaces": {
+    "format": "{icon}",
+    "format-icons": {
+      "1": "1", "2": "2", "3": "3", "4": "4", "5": "5",
+      "6": "6", "7": "7", "8": "8", "9": "9", "10": "10",
+      "11": "11", "12": "12", "13": "13", "14": "14", "15": "15",
+      "16": "16", "17": "17", "18": "18", "19": "19", "20": "20"
+    },
+    "on-click": "activate",
+    "all-outputs": true
   },
```

Note: Hyprland workspace rules in `monitors.nix` already set `persistent:true` for ws ≤ 5 — `persistent-workspaces` config removed (not supported by ext/workspaces).

## Design 2: Autostart Systemd Migration (exact diff)

```diff
# omarchy-nix/modules/home-manager/hyprland/autostart.nix

-      "pkill -x waybar; uwsm-app -- waybar 2>>$HOME/.cache/waybar-stderr.log"
+      "systemctl --user restart waybar || systemctl --user start waybar"
+      # NOTE: systemd manages waybar lifecycle with Restart=always.
+      # Stderr captured via journald (StandardError=journal), view with:
+      #   journalctl --user -u waybar
```

## Design 3: Monitor Watch — NO-OP

Verified at pinned commit `f6b5a93` and origin/main HEAD — file only handles `monitorremoved`, **no `monitoradded>>` reload handler exists**. No change needed. Prior exploration claimed Phase 2 was unapplied; the pinned version was already clean.

## Design 4: Toggle Script (exact diff)

```diff
# omarchy-nix/bin/omarchy-toggle-waybar

 omarchy-toggle waybar-off

-# pgrep -x / pkill -x match comm, which on Nix is `.waybar-wrapped`. Use -f
-# so the running waybar is detected and killed correctly.
-if pgrep -f "(^|/)\.?waybar(-wrapped)?( |\$)" >/dev/null; then
-  pkill -f "(^|/)\.?waybar(-wrapped)?( |\$)"
+if systemctl --user is-active --quiet waybar; then
+  systemctl --user stop waybar
 else
-  uwsm-app -- waybar >/dev/null 2>&1 &
+  systemctl --user start waybar
 fi
+# NOTE: waybar is managed by systemd user service.
+# Stderr captured via journald (StandardError=journal).
```

## Design 5: Systemd Service (exact addition)

```nix
# hosts/t14/home/default.nix — inside the { config, lib, ... }: { ... } block,
# after the existing monitor-lid-validator systemd service (after line 67)

  systemd.user.services.waybar = {
    Unit = {
      Description = "Waybar status bar";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      ConditionEnvironment = [ "WAYLAND_DISPLAY" ];
    };
    Service = {
      ExecStart = "${pkgs.waybar}/bin/waybar";
      Restart = "always";
      RestartSec = "100ms";
      StartLimitBurst = 20;
      StartLimitIntervalSec = "5s";
      StandardOutput = "null";
      StandardError = "journal";
      SyslogIdentifier = "waybar";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
```

## Design 6: Flake Cleanup (exact diff)

```diff
# flake.nix

-    # waybar-src — master branch with Hyprland 0.55 workspace fixes (PR #5013)
-    waybar-src = {
-      url = "github:Alexays/Waybar";
-      flake = false;
-    };
```

`flake.lock` will be regenerated by `nix flake lock` after omarchy-nix commits are pushed — the `waybar-src` node and root reference auto-remove.

## Design 7: PRESERVE — Verified Unchanged Files

| File | Verification | Status |
|------|-------------|--------|
| `hosts/t14/home/hypr/monitors.nix:25` | `builtins.filter (w: w > 3) workspaces` — w>3 filter exists | ✅ Preserved |
| `hosts/t14/home/scripts/monitor-lid-validator.sh` | `apply()` ends after `case` block — no `hyprctl reload` | ✅ Preserved |
| `overlays/linux.nix` | No waybar-git or waybar-src references | ✅ Clean |
| `hosts/t14/default.nix` | No waybar process management code | ✅ Unchanged |

## Data Flow: Workspace Switch (Super+1)

```
User presses Super+1
  → Hyprland keyboard dispatch
  → Hyprland changes active workspace (internal state)
  → ext-workspace-v1: compositor notifies waybar via Wayland event
  → waybar receives event on GTK main thread (no IPC, no mutex, no socket)
  → waybar updates GTK widget in-place
  → Workspace indicator updates. PID unchanged. No crash.
```

## Testing Strategy

| Layer | What | How |
|-------|------|-----|
| Build | Nix eval succeeds | `nix flake check --no-build` |
| Format | All files consistent | `format-nix` |
| Manual T14 | PID stability | `pgrep waybar` before/after 30 workspace switches |
| Manual T14 | No crash entries | `journalctl --user -u waybar` |
| Cleanup | Dead code removed | `grep "waybar-src" flake.nix` → no match |
| Cleanup | No reload re-introduced | `grep "hyprctl reload" omarchy-nix/bin/omarchy-hyprland-monitor-watch` → no match |

## Rollback

1. Revert omarchy-nix commits → restore hyprland/workspaces + uwsm-app
2. Revert flake.nix → restore waybar-src input
3. `nix flake update omarchy-nix` → previous pin
4. `nixos-build` on t14

## Open Questions

None. All technical decisions resolved. Implementation ready for sdd-tasks.
