# Verify Report: fix-screensaver-idle-lock

**Date**: 2026-06-30  
**Machine**: t14 (direct)  
**Status**: PASS

## Results

| Test | Status | Detail |
|------|--------|--------|
| Restart=on-failure | ✅ | `systemctl --user show hypridle.service -p Restart` → `on-failure` |
| Toggle off stops hypridle | ✅ | `inactive` |
| screensaver-off flag created | ✅ | `~/.local/state/omarchy/toggles/screensaver-off` exists |
| No auto-restart (15s+) | ✅ | Still `inactive` — Restart=always bug fixed |
| Toggle on restarts hypridle | ✅ | `active`, flag deleted |

## Commits
- omarchy-nix: `c9f7554`
- nixos-hosts: `551fea7`
