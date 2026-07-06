# Apply Progress: VNC regreet + hyprland — verification

## Slice 1: Config Inspection + Bug Fix (2026-07-02)

### Completed

- [x] **1.1** Access to t14 — confirmed, running on t14
- [x] **1.2** Deployment state — config was already deployed (grep wayvnc = 1)
- [x] **2.1** Hyprland config inspection — PASS: wayvnc line 8, regreet line 9, full store path, backgrounded, correct addr/port
- [x] **2.2** wayvnc config inspection — FAIL found, then FIXED (see bugs)
- [x] **3.1** Deploy — rebuilt with C+ fix

### Bugs Found & Fixed

| Bug | Severity | Status |
|-----|----------|--------|
| tmpfiles `f` type wrote literal `+ /nix/store/...` instead of config content | High | **FIXED** — changed to `C+` type in omarchy-nix (commit 7e34e85), flake lock updated in nixos-hosts (commit af5c957), rebuilt on t14 |

### Blocked

- [ ] **3.2** E2E VNC test — VNC connects but shows WRONG monitor (DP-5, AOC 24P1W1 portrait at 0x0) instead of DP-3 (AOC 2470W landscape at 3000x420). Regreet is on DP-3 but wayvnc captures focused monitor (DP-5). Need to fix wayvnc output selection.

### Not Yet Started

- [ ] 1.3 VNC client availability
- [ ] 2.3 Reboot resistance check
- [ ] 3.3 Custom port test
- [ ] 3.4 Negative test
- [ ] 4.1 Restored state verify
- [ ] 4.2 Build verification
- [ ] 4.3 Verification summary

### Repos

| Repo | Branch | Commit | Status |
|------|--------|--------|--------|
| omarchy-nix | main | 7e34e85 | C+ fix pushed |
| nixos-hosts | master | af5c957 | flake lock updated, pushed |
