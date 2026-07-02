# Apply Progress: fix-screensaver-idle-lock

## Completed
- [x] Edit omarchy-nix hypridle.nix: add `lib` to signature, add `Restart = lib.mkForce "on-failure"` (separate dot-path)
- [x] Nix syntax check: `nix-instantiate --parse` passed
- [x] Format: `nix fmt` applied
- [x] Commit + push to omarchy-nix/main (SHA: c9f7554)
- [x] Bump nixos-hosts flake.lock (omarchy-nix: 76e25f4 → c9f7554)
- [x] Run `nix flake check --no-build` — all checks passed (rog, thinkcentre, t14)
- [x] Commit + push to nixos-hosts/master (SHA: 551fea7)

## Files Changed
| File | Repo | Action |
|------|------|--------|
| modules/home-manager/hypridle.nix | omarchy-nix | Modified: +lib in sig, +Restart override (c9f7554) |
| flake.lock | nixos-hosts | Modified: bump omarchy-nix input (551fea7) |

## Key Implementation Detail
Used separate dot-path syntax for `Restart` (`systemd.user.services.hypridle.Service.Restart = lib.mkForce "on-failure"`) rather than replacing the entire `Service` attrset. This preserves Home Manager's `ExecStart` and all other defaults.
