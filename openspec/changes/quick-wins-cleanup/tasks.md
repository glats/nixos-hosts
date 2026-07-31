# Tasks: Quick Wins Cleanup

## Commit 1: Rename files to match usage / option name
- [x] 1.1 Rename `linux/home/webcam-rog.nix` → `webcam.nix`; update imports in `hosts/rog/home/default.nix`, `hosts/t14/home/omarchy.nix`, and comment in `pkgs/nixos-scripts/default.nix`
- [x] 1.2 Rename `linux/system/hardware/nvidia.nix` → `nvidia-custom.nix`; update import in `hosts/rog/default.nix`

## Commit 2: Conky cleanup
- [x] 2.1 Delete `linux/system/features/conky/default.nix`
- [x] 2.2 Remove redundant `config.conky-config` defaults block in `linux/system/features/conky/options.nix`
- [x] 2.3 Update host imports from `../../linux/system/features/conky` → `../../linux/system/features/conky/options.nix` (rog, thinkcentre)

## Commit 3: Comment and dead-code cleanup
- [x] 3.1 Add comment `# Disables NixOS firewall` above `networking.firewall.enable = false` in `linux/system/networking/firewall.nix`
- [x] 3.2 Delete stale `# Force rebuild: 2026-05-03` comment in `linux/system/base/home-manager.nix`
- [x] 3.3 Translate Spanish comment to English in `hosts/rog/default.nix`
- [x] 3.4 Delete stale OpenCode comment block in `hosts/thinkcentre/default.nix`
- [x] 3.5 Remove `hypridle` from `linux/system/base/profiles/core.nix`

## Commit 4: Config pattern fixes
- [ ] 4.1 Unify shell-gpt enable pattern across hosts (import + inline `{ home.shell-gpt.enable = ...; }`)
- [ ] 4.2 Flatten nested `lib.mkIf` in `linux/system/networking/wol.nix`
- [ ] 4.3 Add `null` as explicit "no desktop" value in `linux/system/base/options.nix`
