# Design: Patch FreeRDP macOS display probe

## Technical Approach

Approach 1 of the proposal: backport FreeRDP PR #13564 (commit `dc5c7eee…`) onto the macm5 `freerdp` 3.30.0 overlay. The pre-connect probe then reads display geometry from SDL display APIs plus an AppKit notch inset, with no window and no Space. Once the patched build is verified, the launcher stops forcing `SDL_VIDEO_MAC_FULLSCREEN_SPACES=0`.

Verified in scratch while designing (GNU patch 2.8; no repo files touched):

- Normalized upstream patch (CMake excluded) applies to 3.30.0 `sdl_window.cpp`. **Hunk 4 applies with fuzz 1** (offset -175): its context is `createPopup`'s tail, which 3.30.0 lacks. The exploration said all hunks applied cleanly, which was wrong. nixpkgs `patchPhase` uses GNU `patch` (default max fuzz 2). Inserted position was checked: `queryWithoutWindow` lands directly before `createDummy`.
- The adapter below applies after it. `sdl_macos.mm` passes `clang++ -std=c++20 -fsyntax-only -x objective-c++` against sdl3 3.4.10 headers.
- `project(sdl-freerdp LANGUAGES CXX)` does not enable OBJCXX. A minimal nested-project CMake 4.x test compiled and linked `.mm` with and without `enable_language(OBJCXX)`. We keep it explicit and cheap.
- Full FreeRDP build NOT run.

## Architecture Decisions

| Decision | Choice | Rejected | Why |
|---|---|---|---|
| Delivery | `fetchpatch` pinned to SHA + local CMake adapter | vendor full patch | Visible upstream drop condition; small local file. Switch to vendoring only if fuzz or fetch is a blocker (see fallback). |
| CMake hunk | Local `patches/freerdp/sdl-macos-cmake.patch`, applied after upstream | `postPatch` substitute | Repo convention is `patches/<pkg>/*.patch`; `postPatch` silently misses on context drift. |
| Order | Build and verify new freerdp, then remove setenv | Both in one step | Removing setenv before the patch exists brings the hopping back. |
| Launcher | Delete the whole block; keep `<Carbon/Carbon.h>` | Keep conditional | Carbon is still needed for `rdpKeyboardLayout()`. `CGGetActiveDisplayList` needs no separate include. |

## Data Flow

    sdl_freerdp.cpp -> detectDisplays() -> SdlWindow::query(id)
       cocoa:  queryWithoutWindow(): SDL_GetDisplayBounds + desktop pixel_density
               + SDL_GetDisplayContentScale + sdl_macos_fullscreen_space_top_inset (AppKit)
               -> makeMonitor()          (no window, no Space)
       other:  createDummy() probe window (unchanged)

## File Changes

| File | Action | Description |
|---|---|---|
| `overlays/darwin.nix` (freerdp, L30-38) | Modify | add `patches` |
| `patches/freerdp/sdl-macos-cmake.patch` | Create | 3.30.0 CMake adapter (below) |
| `darwin/home/remote-desktop.nix` (~L85-96) | Modify | remove comment + `displayCount`/`setenv` block |

## Interfaces / Contracts

Overlay (add inside the `freerdp` override, next to `buildInputs`/`cmakeFlags`):

```nix
patches = (old.patches or [ ]) ++ [
  # Drop both once nixpkgs freerdp includes FreeRDP PR #13564.
  (prev.fetchpatch {
    name = "freerdp-sdl-macos-window-free-display-query.patch";
    url = "https://github.com/FreeRDP/FreeRDP/commit/dc5c7eeef2bb92f1b8cd767d278ec1c99a6534d2.patch?full_index=1";
    excludes = [ "client/SDL/SDL3/CMakeLists.txt" ];
    hash = "sha256-DQtyqMWp9LqPX3ZamArPHCxRBdXdk9zBwyIUxTNwgNE=";
  })
  ../patches/freerdp/sdl-macos-cmake.patch
];
```

The hash was computed with `fetchpatch` (it normalizes, so `nix-prefetch-url` would give the wrong value). I used `lib.fakeHash` plus a temporary `curlOptsList = ["--insecure"]`, then re-built with the real hash and it succeeded. The hash is content-only, so `--insecure` is not needed or committed. Re-derive by setting `lib.fakeHash` and reading `got:` from the error.

`patches/freerdp/sdl-macos-cmake.patch` (verified against 3.30.0, applies after the upstream patch):

```diff
--- a/client/SDL/SDL3/CMakeLists.txt
+++ b/client/SDL/SDL3/CMakeLists.txt
@@ -49,6 +49,12 @@
     sdl_context.cpp
 )
 
+# Native macOS display helpers (AppKit screen geometry for window-free monitor queries).
+if(APPLE)
+  enable_language(OBJCXX)
+  list(APPEND SRCS sdl_macos.hpp sdl_macos.mm)
+endif()
+
 add_win_console_manifest(SRCS)
 
 list(
@@ -64,6 +70,12 @@
   sdl-common-prefs
 )
 
+if(APPLE)
+  find_library(APPKIT_FRAMEWORK AppKit REQUIRED)
+  find_library(COREGRAPHICS_FRAMEWORK CoreGraphics REQUIRED)
+  list(APPEND LIBS ${APPKIT_FRAMEWORK} ${COREGRAPHICS_FRAMEWORK})
+endif()
+
 if(NOT WITH_SDL_LINK_SHARED)
   list(APPEND LIBS SDL3::SDL3-static)
 else()
```

Launcher: remove the whole `/* sdl-freerdp probes every display … */` comment and the `uint32_t displayCount … setenv(...) }` block (current L85-96). `const char *rdpbin` follows directly.

## Testing Strategy

| Step | Command / check |
|---|---|
| 1 Build | `nix fmt -- overlays/darwin.nix darwin/home/remote-desktop.nix`; `NEW=$(nix build .#darwinConfigurations.macm5.pkgs.freerdp --no-link --print-out-paths)`; confirm `sdl_macos.mm` built (`nix log` shows `Building OBJCXX`/`sdl_macos.mm`) and `otool -L $NEW/bin/sdl-freerdp \| grep AppKit` |
| 2 Eval | `nix eval .#darwinConfigurations.macm5.config.system.build.toplevel.drvPath` |
| 3 Timing | `OLD=/nix/store/39v8515j6nn4bpsjjnwpmgsxs48yz3bj-freerdp-3.30.0` (current build; add a gcroot first). Spaces on: `env -u SDL_VIDEO_MAC_FULLSCREEN_SPACES`. See script below. |
| 4 Values | Diff the stripped `monitor.*` lines of OLD vs NEW per display. Expect identical, including the built-in notch `y` inset. |
| 5 Session | Real session via the new launcher: initial size/scale, green button enters a native Space on 1 and 3 displays, no hopping. |

```sh
run() { perl -e 'alarm 25; exec @ARGV' "$1/bin/sdl-freerdp" /v:127.0.0.1:1 /u:probe /p:probe /cert:ignore /log-level:DEBUG 2>&1; }
for b in OLD NEW; do eval "d=\$$b"; env -u SDL_VIDEO_MAC_FULLSCREEN_SPACES run "$d" > /tmp/$b.log
  awk '/monitor\.orig_screen/{split(substr($1,2,12),t,":");ms=((t[1]*60+t[2])*60+t[3])*1000+t[4];if(p)print ms-p" ms";p=ms}' /tmp/$b.log
  sed -nE 's/.*APPLICATION\] (monitor\.[^ ]+ +.*)$/\1/p' /tmp/$b.log > /tmp/$b.mon; done
diff /tmp/OLD.mon /tmp/NEW.mon && echo IDENTICAL
```

Expected: OLD gaps ~650 ms, NEW a few ms. The log pattern was checked on the current binary with `SDL_VIDEODRIVER=dummy`. The cocoa run flashes windows briefly.

## Threat Matrix

N/A: no routing, shell, subprocess or VCS automation is added. The launcher `execv` is unchanged, and the patch only adds a build-time dependency on a pinned, hash-verified source.

## Migration / Rollout

Apply order: overlay + adapter, build and verify (steps 1-4), then the launcher edit, then `nixos-build` on macm5 and step 5.

Fallback (approach 4): triggered if the `.mm` fails to compile or link, if hunk 4 needs more than fuzz 2, or if the monitor values differ. Replace the fetchpatch with a vendored `patches/freerdp/*.patch` containing only `queryWithoutWindow` without `sdl_macos.*` (no notch inset), or hand-fix hunk 4 context into a vendored copy. Vendor too if the sandboxed fetch fails (below).

Rollback: remove the `patches` entry and `patches/freerdp/`, restore the launcher `setenv` (the unconditional one from 944fbb7), rebuild macm5. No state migration.

## Apply Deviations

- `enable_language(OBJCXX)` from the `client/SDL/SDL3` subdirectory failed at generate time (`CMAKE_OBJCXX_COMPILE_OBJECT` not set, CMake 4.x in the Nix build). The adapter now compiles `sdl_macos.mm` with the CXX toolchain via `set_source_files_properties(... LANGUAGE CXX COMPILE_OPTIONS "-x;objective-c++")`; hunk line counts adjusted accordingly.
- The sandboxed `fetchpatch` from github.com worked with the committed hash (no self-signed certificate failure), so no vendored upstream patch was needed. Hunk 4 applied with fuzz 1 (within GNU patch limit).
- Verified: OLD vs NEW `monitor.*` output identical (33 lines, 3 displays, notch `y` 39 included); probe gaps OLD 671/667 ms vs NEW 0/1 ms.

## Open Questions

- [ ] Fetching github.com from this machine's Nix sandbox failed with `self-signed certificate in certificate chain` (proxy). The first real build may fail the same way. If so, commit the normalized patch instead of fetching.
- [ ] Does the probed w/h/scale change the real session under `/workarea /w /h`? Step 5 settles it.
