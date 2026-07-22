# Tasks: teams-t14-wayland

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~30 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

## Phase 1: Package & Wayland Environment (Foundation)

- [ ] 1.1 Add `teams-for-linux` and `v4l-utils` to `environment.systemPackages` in `hosts/t14/default.nix`
- [ ] 1.2 Set `NIXOS_OZONE_WL = "1"` in `environment.variables` in `hosts/t14/default.nix` (same pattern as `modules/base/users.nix:52`)

## Phase 2: Teams Configuration (Home Manager)

- [ ] 2.1 Add `xdg.configFile."teams-for-linux/config.json"` to `hosts/t14/home/omarchy.nix` using `builtins.toJSON` with: `disableGpu: false`, `electronCLIFlags` (`WebRTCPipeWireCapturer`, `WebRtcPipeWireCamera` enable + `HardwareMediaKeyHandling` disable), `notificationMethod: "electron"`, `followSystemTheme: true` (pattern: `home-linux/opencode-theme.nix:17`)

## Phase 3: Verification

- [ ] 3.1 Run `nix flake check --no-build` — must exit 0 for all hosts
- [ ] 3.2 Confirm PipeWire + xdg-desktop-portal-hyprland are active (already configured via omarchy — verify no extra NixOS options needed for camera portal)
