# Review Checkpoint: VNC regreet + hyprland — Slice 1

**Date**: 2026-07-02
**Slice**: 1 (Config Inspection + Bug Fix)

## Verdict

**changes-requested**

## What Was Tested

| Task | Result | Notes |
|------|--------|-------|
| 1.1 Access | PASS | On t14 |
| 1.2 Deploy state | PASS | Config deployed |
| 2.1 hyprland.conf | PASS | wayvnc before regreet, correct |
| 2.2 wayvnc config | FAIL -> FIXED | `f` type bug, fixed with `C+` |
| 3.1 Deploy | DONE | Rebuilt with fix |
| 3.2 E2E VNC | BLOCKED | Captures wrong monitor |

## Issues Found

### Bug 1: tmpfiles `f` type writes literal `+` prefix (FIXED)
- **Root cause**: `system.nix:77` used `f` type with `+ ${wayvncConfigFile}`. systemd-tmpfiles `f` type treats argument as literal content — the `+ ` prefix was written literally.
- **Fix**: Changed to `C+` type (copy with overwrite). Committed to omarchy-nix (7e34e85), flake lock updated in nixos-hosts (af5c957).
- **Status**: FIXED and deployed on t14.

### Bug 2: wayvnc captures wrong monitor (OPEN)
- **Symptom**: VNC connects but shows DP-5 (AOC 24P1W1, portrait, transform:1 at 0x0) instead of DP-3 (AOC 2470W, landscape at 3000x420) where regreet is visible.
- **Root cause**: wayvnc captures the focused/primary output. The greeter's focused monitor is DP-5 (portrait). Regreet shows on DP-3.
- **Impact**: Cannot complete E2E VNC verification (tasks 3.2, 3.3, 3.4 depend on VNC working correctly).
- **Proposed fix**: Add `-a` (capture all outputs) or `-o <output>` flag to wayvnc exec-once in omarchy-nix. Requires code change and rebuild.

## Guard Lines

```
Rework level: explore
Iteration decision needed: Yes
```

## Decision

Two bugs found. Bug 1 fixed. Bug 2 (monitor capture) requires a design change — wayvnc needs explicit output selection. Need to re-explore the monitor capture approach and update the design.
