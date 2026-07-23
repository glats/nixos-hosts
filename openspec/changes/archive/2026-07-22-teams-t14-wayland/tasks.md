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

- [x] 1.1 Wrap `teams-for-linux` in `environment.systemPackages` via `pkgs.symlinkJoin` + `wrapProgram --unset NIXOS_OZONE_WL` + `--add-flags "--ozone-platform=x11"` in `hosts/t14/default.nix`. **Deviation**: `symlinkJoin` wrapper instead of plain package — required for tray support (Electron#40936). `v4l-utils` omitted — PipeWire camera bridge provided by omarchy-nix.
- [x] 1.2 Set `NIXOS_OZONE_WL = "1"` in `environment.variables` in `hosts/t14/default.nix` (global — applies to Brave, VS Code, etc.)

## Phase 2: Teams Configuration (Home Manager)

- [x] 2.1 Add `xdg.configFile."teams-for-linux/config.json"` to `hosts/t14/home/omarchy.nix` using `builtins.toJSON` with: `disableGpu: false`, `electronCLIFlags` (`WebRTCPipeWireCapturer`, `WebRtcPipeWireCamera` enable + `HardwareMediaKeyHandling` disable), `notificationMethod: "electron"`, `followSystemTheme: true`, `screenSharing.thumbnail.enabled: false` (pattern: `home-linux/opencode-theme.nix:17`). **Addition**: `screenSharing.thumbnail.enabled = false` disables the preview/mirror window during screen sharing.

## Phase 3: Verification

- [x] 3.1 Run `nix flake check --no-build` — all hosts pass (t14, rog, thinkcentre)
- [x] 3.2 Confirm PipeWire + xdg-desktop-portal-hyprland are active (verified via omarchy-nix — no extra NixOS options needed)
