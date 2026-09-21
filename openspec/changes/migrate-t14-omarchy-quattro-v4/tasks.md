# Tasks: Migrate T14 Omarchy to Quattro v4

## Review Workload Forecast

| Field | Value |
|---|---|
| Estimated changed lines | 350–500 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | Portable fork commit(s) → consumer boundary → live acceptance |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: pending
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|---|---|---|---|---|---|
| 1 | Portable Quattro v4 runtime | omarchy-nix direct commit | `nix flake check --no-build` (read-only) | Fresh user session; shell IPC | Revert omarchy-nix commit |
| 2 | t14 package boundary and policy wiring | nixos-hosts consumer bump | `nix flake check --no-build` | ReGreet → login → UWSM | Revert consumer bump |
| 3 | Acceptance and cutover | follow-up phase commit | `nixos-build build` | Dock/lid, Wi-Fi, VNC, auth | Select retained v3 generation |

## Phase 1: Boundary and Portable Foundation

- [ ] 1.1 In `/home/glats/Project/omarchy-nix`, pin the Quattro source, Quickshell, Hyprland, and matching HM boundary; document every Nix-only deviation in adjacent module comments. Verify fork evaluation; rollback by reverting the portable commit.
- [ ] 1.2 In `/home/glats/Project/omarchy-nix`, add the Quattro NixOS/HM module interfaces and immutable runtime/default assets under `modules/nixos/{default.nix,system.nix,quattro.nix}` and `modules/home-manager/{default.nix,quattro.nix,hyprland-lua.nix,quattro-theme.nix}`. Verify module evaluation; rollback by disabling `omarchy.quattro.enable`.
- [ ] 1.3 Gate PAM mapping in `/home/glats/Project/omarchy-nix/modules/nixos/quattro.nix` against `openspec/changes/migrate-t14-omarchy-quattro-v4/design.md` (read-only): prove rendered NixOS service names/includes, not Arch `system-local-login`; stop on ambiguity and retain v3 auth.

## Phase 2: Runtime Ownership and Host Consumer

- [ ] 2.1 In `/home/glats/Project/omarchy-nix`, wire Lua autostart to exactly one post-login `omarchy-shell`; remove v3 daemon imports/assets only after shell IPC, lock, polkit, and restart checks pass. Verify no replaced daemon units/processes; revert this fork commit as one unit.
- [ ] 2.2 In `/home/glats/.nixos/flake.nix` and `lib/mkHost.nix`, add the coherent t14-only package/HM inputs without changing global 26.05 or mact2. Gate a locked revision set for nixpkgs/HM/Hyprland/Quickshell; verify t14 and mact2 evaluation, rollback the input bump.
- [ ] 2.3 In `/home/glats/.nixos/hosts/t14/{default.nix,omarchy-config.nix,home/default.nix,home/omarchy.nix}`, select NetworkManager, retain greetd+ReGreet pre-login, and keep Quickshell post-login only. Gate NM ownership: no standalone iwd, unmanaged `wlan0`, or competing DHCP/DNS; rollback to v3 input/configuration.
- [ ] 2.4 Preserve `/home/glats/.nixos/hosts/t14/hdm/{config.toml,hyprconfigs/*.conf}` and WayVNC/Edge/SOPS policy; explicitly prevent Lua or Quattro monitor hooks from writing profiles. HDM remains the sole UPower/Hyprland-IPC dock/lid writer.

## Phase 3: Verification and Live Cutover

- [ ] 3.1 Verify `/home/glats/.nixos/flake.nix`: `format-nix && nix flake check --no-build`, t14 HM, mact2 global-26.05, and coherent Quickshell closure; rollback on failure.
- [ ] 3.2 Live-test `/home/glats/.nixos/hosts/t14`: independent ReGreet keyboard/focus/greeter-VNC, then user VNC, shell IPC/restart, lock recovery, `pkexec`, and fingerprint fallback; retain the known-good generation.
- [ ] 3.3 Gate `/home/glats/.nixos/hosts/t14/omarchy-config.nix`: NM Wi-Fi/Ethernet, DHCP/DNS, mDNS, Docker, resume, and persistent `~/.config/omarchy/shell.toml` theme override without rebuild.
- [ ] 3.4 Gate `/home/glats/.nixos/hosts/t14/hdm/{config.toml,hyprconfigs/*.conf}`: dock/undock and lid transitions show one writer, no duplicate writes, and no oscillation; restore v3 on failure.
- [ ] 3.5 Record acceptance for no v3 daemons, HDM, VNC, Edge/MIME, SOPS, themes, network, auth, and rollback; activate only when every spec scenario passes.
