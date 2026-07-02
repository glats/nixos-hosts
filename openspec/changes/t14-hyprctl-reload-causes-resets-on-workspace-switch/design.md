# Design: t14-hyprctl-reload-causes-resets-on-workspace-switch

## Technical Approach

Eliminate all `hyprctl reload` calls from the T14 monitor layout path. The reload is the root cause of waybar crashes on workspace switch: it re-parses the full config, re-creates workspace rules, and triggers `destroyworkspace>>` events that crash waybar v0.15.0 (upstream #4361). Four surgical removals across two repos (nixos-hosts + omarchy-nix) plus workspace-rule isolation and stderr capture for diagnostics.

References: proposal (Approach 3+4), delta spec (REQ-DAEMON-6, REQ-HOTPLUG-1, REQ-HOTPLUG-4, REQ-COND-5, REQ-DIAG-1).

## Architecture Decisions

### Decision: Remove `hyprctl reload` from validator daemon

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Keep reload as "safety net" | Causes waybar crash every 2s on lid change | **Remove** — `hyprctl keyword` already applies monitor changes atomically |
| Replace with `hyprctl dispatch reload` | Same effect, same crash | **Remove** — no reload variant is safe |

### Decision: Filter workspaces 1-3 from external monitor rules

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Keep dual bindings (eDP-1 + externals) | Hyprland 0.55 `mergeLeft` creates hybrid rules, workspace jumps reset | **Filter** — `builtins.filter (w: w > 3)` eliminates dual-binding |
| Use `workspace = X, monitor: eDP-1` override in extraConfig only | Still conflicts with `workspace` rules list | **Filter** — clean separation at rule-generation level |

### Decision: Remove `monitoradded>>` reload from omarchy-nix

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Keep reload for "fast" hotplug response | Redundant with daemon 2s polling; triggers waybar crash | **Remove** — daemon handles layout within 2s |
| Replace with `hyprctl keyword` per-monitor | Duplicates daemon logic; fragile | **Remove** — single source of truth is the daemon |

### Decision: Append waybar stderr to log file

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Redirect to journalctl | Harder to correlate with specific crash | **Append** to `$HOME/.cache/waybar-stderr.log` — persistent, searchable |
| Overwrite log each launch | Loses previous crash context | **Append** (`>>`) — preserves history across restarts |

## Data Flow

```
                  BEFORE                              AFTER
  ┌─────────────────────────────┐     ┌─────────────────────────────┐
  │ Lid change / dock event     │     │ Lid change / dock event     │
  │         │                   │     │         │                   │
  │    hyprctl reload ──────┐   │     │    hyprctl keyword ────┐    │
  │         │               │   │     │    (no reload)         │    │
  │    Config re-parse      │   │     │    Monitor reposition  │    │
  │         │               │   │     │    (atomic, no crash)  │    │
  │    destroyworkspace>> ──┤──→│ waybar crash                 │    │
  │         │               │   │                              │    │
  │    waybar SIGSEGV       │   │     ┌────────────────────────┘    │
  └─────────────────────────────┘     │ Monitor-added event       │
                                      │    (no handler)           │
                                      │    daemon polls in ≤2s    │
                                      └───────────────────────────┘
```

## File Changes

| File | Repo | Action | Description |
|------|------|--------|-------------|
| `hosts/t14/home/scripts/monitor-lid-validator.sh` | nixos-hosts | Modify | Delete line 47: `hyprctl reload` |
| `hosts/t14/home/hypr/monitors.nix` | nixos-hosts | Modify | Add `builtins.filter (w: w > 3)` to `mkWorkspaceRules` |
| `bin/omarchy-hyprland-monitor-watch` | omarchy-nix | Modify | Delete `monitoradded>>` case branch (lines 9-11) |
| `modules/home-manager/hyprland/autostart.nix` | omarchy-nix | Modify | Append `2>>$HOME/.cache/waybar-stderr.log` to waybar launch |

## Exact Changes

### Change 1: `monitor-lid-validator.sh` line 47

```diff
 apply() {
   LID_STATE=$(grep -o 'open\|closed' /proc/acpi/button/lid/LID*/state 2>/dev/null || echo "open")
   case "$LID_STATE" in
     closed) persist 0; move_to_y0 ;;
     *)      persist 1; move_to_y420 ;;
   esac
-  hyprctl reload
 }
```

### Change 2: `monitors.nix` line 23

```diff
         lib.imap1 (
           idx: w:
           "${toString w}, monitor:desc:${monitor}, default:${lib.boolToString (idx == 1)}, persistent:${lib.boolToString (w <= 5)}"
-        ) workspaces
+        ) (builtins.filter (w: w > 3) workspaces)
```

### Change 3: `omarchy-hyprland-monitor-watch` lines 9-11

```diff
 socat -U - "UNIX-CONNECT:$SOCKET" | while read -r event; do
   case "$event" in
-    monitoradded\>\>*|monitoraddedv2\>\>*)
-      hyprctl reload
-      ;;
     monitorremoved\>\>*|monitorremovedv2\>\>*)
       omarchy-hyprland-monitor-internal recover
       omarchy-hyprland-monitor-internal-mirror recover
       ;;
   esac
 done
```

### Change 4: `autostart.nix` line 14

```diff
-      "pkill -x waybar; uwsm-app -- waybar"
+      "pkill -x waybar; uwsm-app -- waybar 2>>$HOME/.cache/waybar-stderr.log"
```

## Interactions Between Changes

- **Changes 1 + 3**: After both removals, NO `hyprctl reload` source remains in the monitor layout path. The daemon's `hyprctl keyword` calls and the lid-switch `bindl` inline commands are the only runtime monitor configuration mechanisms.
- **Change 2 + daemon**: When lid is closed (eDP-1 disabled), workspaces 1-3 are unbound by rules. Hyprland auto-assigns them. When lid opens, `extraConfig` conditional binds 1-3 to eDP-1. No dual-binding conflict.
- **Change 4**: Independent diagnostic. Does not affect behavior; only captures crash output for analysis.

## Verification Plan

### Build Verification
1. `nix flake check --no-build` — must pass (validates Nix syntax for both nixos-hosts files)
2. `format-nix` — must pass (applies nixfmt-rfc-style to modified .nix files)
3. For omarchy-nix: `nix flake check --no-build` in `/home/glats/repos/omarchy-nix`

### Runtime Verification
1. Stop validator daemon: `systemctl --user stop monitor-lid-validator.service` (or kill PID)
2. Switch workspaces rapidly (Super+1 through Super+9) — waybar must NOT flicker
3. Check waybar stderr: `cat ~/.cache/waybar-stderr.log` — should be empty or show no SIGSEGV
4. Test lid close/open: waybar must survive without restart
5. Test dock connect: daemon must detect within 2s, no reload triggered

### Fallback Paths (if waybar still crashes)
1. **Diagnose via stderr**: Read `~/.cache/waybar-stderr.log` for crash signature
2. **ext/workspaces module**: Switch to Hyprland's experimental workspace module (avoids `destroyworkspace>>` events entirely)
3. **Rebuild waybar from git**: Apply PR #5103 fix (upstream waybar crash fix)
4. **Downgrade Hyprland**: Pin to version before 0.55 if regression confirmed

## Open Questions

- None — all changes are well-scoped and reversible.
