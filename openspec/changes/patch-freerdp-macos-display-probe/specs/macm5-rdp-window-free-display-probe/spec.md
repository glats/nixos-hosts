# Delta for macm5-rdp-window-free-display-probe

Host scope: `macm5` (all scenarios tagged `[macm5]` unless noted).

## ADDED Requirements

### Requirement: Window-free pre-connect display probe

On the cocoa video driver, the `sdl-freerdp` pre-connect display probe MUST NOT create any window, renderer, or native fullscreen Space, with `SDL_VIDEO_MAC_FULLSCREEN_SPACES` unset (Spaces enabled).

#### Scenario: Multi-display probe with Spaces enabled [macm5]

- GIVEN 3 active displays and Spaces enabled
- WHEN `sdl-freerdp` runs the probe against a closed localhost port
- THEN zero probe windows appear and zero Space transitions occur
- AND per-display probe gaps are in the low-millisecond range (previously ~650ms)

#### Scenario: Single display [macm5]

- GIVEN 1 active display and Spaces enabled
- WHEN the probe runs
- THEN no window or Space transition occurs

### Requirement: Monitor values unchanged per display

Each display's `monitor.x`, `monitor.y`, `monitor.width`, `monitor.height`, and `monitor.desktopScaleFactor` reported by the probe MUST equal the pre-patch Spaces-enabled values.

#### Scenario: Built-in display with notch [macm5]

- GIVEN a pre-patch `/log-level:DEBUG` capture with Spaces enabled
- WHEN the same capture is taken post-patch
- THEN built-in values are identical, including the notch-trimmed `y` inset

#### Scenario: External displays [macm5]

- GIVEN pre- and post-patch debug captures
- WHEN each external display is compared field by field
- THEN all five fields are identical

### Requirement: Native-Space fullscreen via green button

The launcher MUST NOT set `SDL_VIDEO_MAC_FULLSCREEN_SPACES`, so the green button enters a native fullscreen Space on single and multi-display setups.

#### Scenario: Green button on multi-display [macm5]

- GIVEN a real RDP session on 3 displays (`/workarea /w /h /smart-sizing`)
- WHEN the user clicks the green button
- THEN the window enters a native fullscreen Space

#### Scenario: Green button on single display [macm5]

- GIVEN a real session on 1 display
- WHEN the user clicks the green button
- THEN the window enters a native fullscreen Space

#### Scenario: Launcher environment [macm5]

- GIVEN the built launcher
- WHEN it is inspected (source or `strings`)
- THEN it contains no `SDL_VIDEO_MAC_FULLSCREEN_SPACES` setenv and no display-count conditional for it

### Requirement: Non-macOS behavior unchanged

The patch MUST NOT alter FreeRDP behavior on non-cocoa drivers or non-macOS hosts; those keep the existing probe window.

#### Scenario: Non-cocoa driver [all]

- GIVEN a non-cocoa SDL video driver
- WHEN the probe runs
- THEN the existing window-based probe is used

#### Scenario: Linux hosts [rog, thinkcentre, t14]

- GIVEN a Linux host evaluation
- WHEN its toplevel `drvPath` is evaluated
- THEN it is unaffected by the freerdp overlay change

### Requirement: Pinned, droppable patch

The upstream patch MUST be fetched pinned to commit `dc5c7eeef2bb92f1b8cd767d278ec1c99a6534d2` (not a PR ref), excluding `client/SDL/SDL3/CMakeLists.txt`, with a local CMake adapter for 3.30.0. A comment MUST document the drop condition: remove the patches once nixpkgs freerdp includes FreeRDP PR #13564.

#### Scenario: Pin and build [macm5]

- GIVEN the macm5 overlay
- WHEN the toplevel is evaluated and freerdp is built
- THEN the fetch references the SHA and `sdl_macos.mm` is compiled and linked

#### Scenario: Drop condition documented [macm5]

- GIVEN the overlay source
- WHEN a maintainer reads the `patches` entry
- THEN an adjacent comment states the drop condition and to re-check at the next flake bump
