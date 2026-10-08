# Proposal: Patch FreeRDP macOS display probe

## Intent

On macm5 (3 displays), `sdl-freerdp` runs a pre-connect display probe (`SdlWindow::createDummy` → fullscreen 64x64 window per display). With native Spaces on (the SDL default), each probe creates a Space (~0.65s/display), so black windows hop across all monitors. The current workaround, a launcher `SDL_VIDEO_MAC_FULLSCREEN_SPACES=0` set when more than one display is active, removes the green-button native Space on multi-display. The user wants the green-button Space on single AND multi-display, without the hopping.

## Scope

### In Scope
- Backport upstream FreeRDP PR #13564 (commit `dc5c7eeef2bb92f1b8cd767d278ec1c99a6534d2`, window-free cocoa display query) into the macm5 `freerdp` overlay via `fetchpatch` pinned to the SHA, excluding `client/SDL/SDL3/CMakeLists.txt`.
- Add a small local adapter patch under `patches/freerdp/` for 3.30.0 CMake: register `sdl_macos.{hpp,mm}` in `set(SRCS` and add the AppKit/CoreGraphics link, because upstream hunk 1 fails on 3.30.0.
- After verification, remove the `SDL_VIDEO_MAC_FULLSCREEN_SPACES` setenv and the `CGGetActiveDisplayList` conditional (and any unused include) from `darwin/home/remote-desktop.nix`, so Spaces stay enabled.
- Add a drop-condition comment: remove the patches once nixpkgs freerdp includes #13564.

### Out of Scope
- Vendoring the full patch (chosen: fetchpatch + adapter, unless a blocker appears).
- Linux hosts, SDL3 changes (sdl3 is unchanged), `/f`, `/multimon` and dynamic-resolution validation.
- Flake input bumps (3.31/3.32 re-check happens at the next bump).

## Capabilities

### New Capabilities
- `macm5-rdp-window-free-display-probe`: the macm5 `sdl-freerdp` pre-connect probe creates no windows or Spaces and reports the same per-display monitor geometry. Native-Space fullscreen stays available.

### Modified Capabilities
- None (`openspec/specs/` is empty).

## Approach

Approach 1 from the exploration. On the cocoa driver, the patch computes geometry from `SDL_GetDisplayBounds`, the desktop display mode's `pixel_density` and `SDL_GetDisplayContentScale`, and trims the notch inset via AppKit `safeAreaInsets`. This keeps the Spaces-on values. Fallback: if the `.mm` does not build on 3.30.0, use Approach 4 (own window-free query without the AppKit inset).

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `overlays/darwin.nix:30-38` | Modified | `patches` on the `freerdp` override (fetchpatch + local adapter) |
| `patches/freerdp/*.patch` | New | CMake adapter for 3.30.0 |
| `darwin/home/remote-desktop.nix` (~80-96) | Modified | Remove setenv and display-count conditional (uncommitted; 944fbb7 set it unconditionally) |

Host scope: `macm5` only. freerdp rebuilds locally.

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| PR #13564 is open and unreviewed, so it may change | Med | Pin the commit SHA; fetchpatch hash stays stable |
| `.mm` fails to build or link on 3.30.0 | Med | Build the package first; fall back to Approach 4 |
| Probed values differ on our hardware (SDL 3.4.10, notch) | Low-Med | Compare `/log-level:DEBUG` monitor values before and after |
| Probed values affect the real session with `/workarea /w /h` (unverified) | Low | Real-session test |

## Rollback Plan

Revert the overlay `patches` entry and delete `patches/freerdp/`. Restore the launcher conditional `setenv` (or the unconditional one from 944fbb7). Rebuild macm5. No data or state migration is involved.

## Dependencies

- Network access to github.com for the fetchpatch.
- The 3-display Mac for the A/B probe-timing and debug-log checks.

## Success Criteria

- [ ] `nix eval` of the macm5 toplevel passes and the overridden freerdp builds with `sdl_macos.mm` compiled.
- [ ] With Spaces=1 and a closed localhost port, probe gaps drop from ~650ms to a few ms, with no Space transitions or hopping.
- [ ] `monitor.x/y/width/height/desktopScaleFactor` are identical before and after for each display, including the built-in notch `y` inset.
- [ ] In a real session, the green button enters a native Space on single and multi-display.
- [ ] The launcher no longer sets `SDL_VIDEO_MAC_FULLSCREEN_SPACES`.
