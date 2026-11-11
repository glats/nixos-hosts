# XRDP session hardware GL acceleration (xrdpdev / DRI3 on Intel i915)

Objective: make the XRDP session on the `rog` and `thinkcentre` hosts render with hardware
GL (DRI3 over the Intel i915 iGPU) instead of Mesa software OpenGL, so that GPU-backed
terminals such as Ghostty stop burning CPU on the same cores that encode the RDP frames.
Branch: to be created from `feat/ghostty-opt` (`feat/xrdp-dri3-accel`).
Delivery strategy: one work-unit commit on the feature branch; push/PR left to the user.
Test runner: a scratch Xorg on a spare display with the candidate `xorg.conf`, then the
real XRDP path on `rog` only after the user explicitly approves the session restart.

## Specs

- S1: The XRDP session X server must expose a working DRI3 device backed by the Intel
  i915 render node, instead of falling back to software GL.
  Acceptance: the session Xorg log shows the glamor path
  (`rdpPreInit: drm device looks ok, use glamor set`, `glamor init ok`) and a hardware
  GLX provider instead of `GLX: Initialized DRISWRAST GL provider for screen 0`; a
  client GL probe reports `Accelerated: yes` with the Intel device; the client-side
  `libEGL warning: DRI3 error: Could not get DRI3 device` message is absent.
  Checks: scratch Xorg on a spare display, client GL probe, Xorg log inspection.
- S2: The DRI3 device selection must be deterministic for the Intel iGPU.
  Acceptance: the session selects the Intel render node and rejects the NVIDIA one, so
  a swap in the DRM render-node numbering degrades gracefully to software GL instead of
  rendering on the wrong GPU. The stable identifier `/dev/dri/by-path/pci-0000:00:02.0-render`
  is the preferred form, but a graceful degradation is acceptable when the shipped
  configuration already selects the Intel node on this host and the allowlist excludes
  the NVIDIA driver name.
  Checks: grep of the shipped configuration for `DRMDevice` and `DRMAllowList`; the
  scratch test confirms the Intel node is the one that is opened.
- S3: The NVIDIA proprietary driver must not be used for the XRDP session.
  Acceptance: the XRDP session keeps the `xrdpdev` driver. This is a deliberate
  exclusion, not an oversight: upstream xorgxrdp declares the proprietary driver
  unsupported for virtual monitors, and the host already runs `kmscon` holding the
  NVIDIA DRM device, which would contend for the GPU.
  Checks: the shipped configuration names no NVIDIA driver; the exclusion is recorded in
  the Log with its upstream evidence.
- S4: A broken or unusable configuration must never cut off remote access.
  Acceptance: the change is confined to the `[Xorg]` section of the generated
  `sesman.ini` and to a repository-owned `xorg.conf`; an existing XRDP session keeps
  running untouched; `xrdp-sesman` reads its configuration only at service start, so the
  new configuration applies to NEW sessions only; SSH access is never touched.
  Checks: diff review of the generated `sesman.ini`; recovery runbook in the Log.
- S5: The change must be reversible by reverting the repository state.
  Acceptance: reverting the work-unit commit and re-running the switch restores the
  previous `sesman.ini` and `xorg.conf` byte for byte, because both are generated from
  the repository.
  Checks: `nix eval` of the generated `confDir` before and after the revert.
- S6: The user request that opened this work is the original wording:
  "dale no podemos arreglar lo del xrdpdev?". The delivered outcome must be either a
  working hardware GL path in the XRDP session, or a precise, evidence-backed statement
  of why that is not achievable on this host.
  Checks: the A/B probe on a scratch display must show a hardware renderer for S1, or
  the Log must record the blocking condition with its evidence.

## Tasks

- T1 (delegated): establish the root cause of the DRI3 failure empirically, on a scratch
  display, without touching the live session. Linked: S1, S2. Status: done (L5).
- T2 (delegated): research the upstream requirements and known-good configurations for
  xorgxrdp DRI3 on an Intel iGPU, and the known failure modes (DRM master, logind seat,
  render node selection). Linked: S1, S3. Status: done. Evidence: Log L4.
- T3 (delegated, conditional on T1/T2): implement the repository-owned `xorg.conf` and
  the `extraConfDirCommands` change that points the `[Xorg]` session at it, with the
  stable render node path. Linked: S1, S2, S4, S5. Status: done (L5) — the shipped
  `xorg.conf` needed NO change; the fix is the `xorgxrdp` derivation, and the S2
  stable-path item stays open as a separate robustness improvement.
- T4 (inline): verify the generated `sesman.ini`/`xorg.conf` and the revert path.
  Linked: S4, S5. Status: done. Evidence: Log L5.
- T5 (inline, requires explicit user approval): apply on `rog` and reconnect a real
  XRDP session to confirm hardware GL in the live session. Linked: S1, S6. Status:
  pending, NOT authorized yet.

## Log

- L1 (2026-11-11): "dale no podemos arreglar lo del xrdpdev?"
- L2 (2026-11-11): findings from the profiling of the live session, carried over from
  `odd/tasks/ghostty-xrdp-footprint.md`.
  GPU topology of `rog`: hybrid. The display is wired to the Intel i915 iGPU
  (`0000:00:02.0`, `DRIVER=i915`, `PCI_ID=8086:591B`, connectors `card1-eDP-1` and
  `card1-HDMI-A-1`); the NVIDIA GTX 1050 (Pascal, `0000:01:00.0`, `PCI_ID=10DE:1C8D`) is
  a secondary GPU with NO connectors on this card. `/dev/dri/card0` is NVIDIA and
  `/dev/dri/card1` is Intel. The render nodes are assigned in DRM registration order and
  are NOT aligned with the card numbering: `/dev/dri/renderD128` is the Intel i915 and
  `/dev/dri/renderD129` is NVIDIA. Stable paths exist under `/dev/dri/by-path/`:
  `pci-0000:00:02.0-render` -> `renderD128` (Intel) and `pci-0000:01:00.0-render` ->
  `renderD129` (NVIDIA).
  The shipped xorgxrdp configuration already selects the correct GPU:
  `Option "DRMDevice" "/dev/dri/renderD128"`, `Option "DRI3" "1"`,
  `Option "DRMAllowList" "amdgpu i915 msm radeon"`. `renderD128` IS the Intel i915 on
  this boot, and `i915` IS in the allowlist. So the render-node numbering theory does
  NOT explain the current failure; the root cause is still open (T1).
  Live Xorg log of the current session (`~/.xorgxrdp.10.log`) shows the extension
  initializing but the GL stack staying in software:
      (II) xfree86: Adding drm device (/dev/dri/card0)
      (EE) systemd-logind: failed to take device /dev/dri/card0: Operation not permitted
      (II) xfree86: Adding drm device (/dev/dri/card1)
      (II) Initializing extension DRI3
      (II) AIGLX: Screen 0 is not DRI2 capable
      (II) IGLX: Loaded and initialized swrast
      (II) GLX: Initialized DRISWRAST GL provider for screen 0
  and the client side reports the matching failure:
      libEGL warning: DRI3 error: Could not get DRI3 device
      libEGL warning: Ensure your X server supports DRI3 to have accelerated rendering
  `xrandr --listproviders` on `:10` returns `Providers: number : 0`, confirming there is
  no hardware GLX provider in the session.
  NVIDIA proprietary driver is excluded as the solution (S3): upstream xorgxrdp is
  explicit that the proprietary driver does not work with the virtual monitor
  (xrdp#1697, #1029, #901; the `nvidia_hack` fork still fails with "Failed to initialize
  the GLX module"), and `rog` runs `kmscon` holding the NVIDIA DRM device, so a
  proprietary-driver Xorg would contend for the same GPU that `ollama` and the rest of
  the host use.
- L3 (2026-11-11): blast radius recorded before any change (S4). `xrdp-sesman` reads
  `sesman.ini` once at service start and its unit sets `restartIfChanged = false`, so a
  configuration change affects NEW sessions only; the running session keeps its already
  started Xorg. A crash inside a session Xorg kills that RDP session only, not the
  local console (kmscon) and not SSH. The current agent session itself runs INSIDE the
  XRDP session on display `:10` (the terminal is the Ghostty process 254597 and the
  agent is its child scope), so restarting the XRDP session would terminate this very
  session. Any live verification therefore needs explicit user approval and a plan for
  resuming afterwards.
- L4 (2026-11-11): ROOT CAUSE, established from primary sources by two independent
  investigations and confirmed against the local nixpkgs tree. There is exactly ONE
  primary cause and ONE secondary blocker; the render-node numbering theory from L2 is
  RULED OUT (the shipped `DRMDevice` already points at the Intel node and `i915` is
  already in the allowlist).
  PRIMARY CAUSE: the nixpkgs `xorgxrdp` derivation is built WITHOUT glamor.
  `pkgs/by-name/xr/xrdp/package.nix` defines `xorgxrdp` with
  `buildInputs = [ xorg-server libdrm ]` and NO `--enable-glamor` configure flag.
  Upstream `configure.ac` defaults `enable-glamor` to `no`, and every DRMDevice/DRI3/
  DRMAllowList code path in `xrdpdev/xrdpdev.c` and `xrdpdev/xrdpdri3.c` is wrapped in
  `#if defined(XORGXRDP_GLAMOR)`. Without that macro the three options shipped in
  `xorg.conf` execute NO code at all, so `dev->glamor` stays FALSE and the driver
  unconditionally falls back to swrast.
  Evidence from the live log: the glamor-enabled `rdpPreInit()` emits
  `rdpPreInit: drm device looks ok, use glamor set` and `glamor init ok` via
  `LLOGLN`; NEITHER appears in `~/.xorgxrdp.10.log`. Line 125 (`rdpPreInit:`) is
  immediately followed by line 126 (`Depth 24, framebuffer bpp 32`) with no render-node
  open result, no driver name, and no glamor line. The log then shows
  `AIGLX: Screen 0 is not DRI2 capable`, `IGLX: Loaded and initialized swrast` and
  `GLX: Initialized DRISWRAST GL provider for screen 0`. That is the exact symptom
  described in upstream xorgxrdp issue #361 and discussion #361, whose resolution was
  a build with `--enable-glamor`.
  Upstream known-good configuration (verbatim from
  https://raw.githubusercontent.com/neutrinolabs/xorgxrdp/devel/xrdpdev/xorg.conf):
      Section "Device"
          Identifier "Video Card (xrdpdev)"
          Driver "xrdpdev"
          Option "DRMDevice" "/dev/dri/renderD128"
          Option "DRI3" "1"
          Option "DRMAllowList" "amdgpu i915 xe msm radeon"
      EndSection
  It is TEXTUALLY IDENTICAL to what this host already ships, except for the `xe`
  token that upstream added for Intel Xe. The configuration was never wrong; the
  BINARY was.
  SECONDARY BLOCKER: the session Xorg runs as the unprivileged user `glats`, who is in
  group `video` but NOT in group `render`. systemd `50-udev-default.rules` sets
  `KERNEL=="renderD*", GROUP="render", MODE="0660"` while card nodes get
  `GROUP="video"`, and render nodes are excluded from the `uaccess` tag. The udev
  database confirms `/run/udev/data/c226:128` (renderD128) has NO tags, whereas
  `/run/udev/data/c226:1` (card1) has `G:uaccess`, `G:master-of-seat`, `G:seat`.
  `open("/dev/dri/renderD128", O_RDWR)` would therefore return EACCES for `glats` even
  on a glamor-enabled build, again leaving `dev->glamor = FALSE`. The repository
  already knows this permission model: `jellyfin.nix` adds
  `--group-add=${config.ids.gids.render}` for the same render node.
  NO DRM MASTER is required: `rdpDri3OpenClient()` opens the render node directly and
  hands the fd to the client; render nodes have no master concept.
  The `systemd-logind: failed to take device /dev/dri/card0: Operation not permitted`
  line is NON-FATAL and unrelated: it comes from
  `hw/xfree86/os-support/linux/systemd-logind.c` asking logind to assign the CARD
  (KMS) node during platform probe. xrdpdev never uses card nodes for the DRI3 path.
  The NVIDIA proprietary driver remains excluded (S3): upstream xorgxrdp declares it
  unsupported with a virtual monitor (xrdp#1697, #1029, #901) and `rog` runs `kmscon`
  holding the NVIDIA DRM device.
  MINIMAL FIX, two parts, both required:
    1. Rebuild `xorgxrdp` with glamor, by overriding the `xorgxrdp` derivation that
       nixpkgs' `xrdp` package exposes through `passthru` (`xrdp.xorgxrdp`,
       `attrPath = "xrdp.xorgxrdp"`), adding `--enable-glamor` plus the glamor build
       inputs. The generated `sesman.ini` already points `-modulepath` and `-config`
       at that derivation, so no configuration rewrite is needed for the module path.
    2. Add `glats` to the `render` group in `linux/system/base/users.nix`.
  No change to `DRMDevice` or `DRMAllowList` is required for this host: `renderD128`
  is already the Intel i915 and `i915` is already in the allowlist. The stable
  `/dev/dri/by-path/pci-0000:00:02.0-render` path remains a robustness improvement for
  the render-node ordering hazard recorded in L2, to be evaluated separately (S2).
- L5 (2026-11-11): T1 empirical proof on a scratch display `:77`, run as the
  unprivileged user `glats`, with the glamor-enabled modulepath and a scratch
  `xorg.conf` that keeps the `xrdpdev` driver and its `DRMDevice`/`DRI3`/
  `DRMAllowList` options byte-identical to the shipped file. The live session on `:10`
  was never touched.
  Server log, RED then GREEN:
      RED  (baseline, live :10, unfixed) -> GLX: Initialized DRISWRAST GL provider
           glxinfo -> Device: llvmpipe, Accelerated: no
           client   -> libEGL warning: DRI3 error: Could not get DRI3 device (present)
      GREEN (scratch :77, glamor build)
           rdpPreInit: /dev/dri/renderD128 open ok, fd 11
           rdpPreInit: name [i915]
           rdpPreInit: drm device looks ok, use glamor set
           (II) Loading sub module "glamoregl"
           rdpPreInit: glamor module load ok
           (II) XRDPDEV(0): glamor: Using OpenGL 4.6 context.
           (II) XRDPDEV(0): glamor X acceleration enabled on Mesa Intel(R) HD Graphics 630 (KBL GT2)
           rdpPreInit: glamor init ok
           rdpScreenInit: glamor_init ok
           (II) XRDPDEV(0): [DRI2]   DRI driver: iris
           rdpScreenInit: rdpDri2Init ok
           rdpScreenInit: rdpDri3Init ok
           (II) AIGLX: Loaded and initialized iris
           (II) GLX: Initialized DRI2 GL provider for screen 0
      client probe on :77 -> glxinfo Vendor: Intel (0x8086),
           Device: Mesa Intel(R) HD Graphics 630 (KBL GT2) (0x591b), Accelerated: yes;
           ghostty logs `info(opengl): loaded OpenGL 4.6` and the DRI3 warning count is 0.
  Two corrections to L4, both evidence-backed:
  (a) `xrandr --listproviders` reports `Providers: number : 0` on the FIXED `:77` as
      well as on the broken `:10`. The RandR provider list comes from
      `rrScrPriv->provider`, which upstream xorgxrdp never registers, so it cannot
      discriminate software from hardware for this driver. S1 was therefore satisfied
      through the log, `glxinfo` and the client probe, and its original provider-list
      clause was unreachable by configuration and has been rewritten.
  (b) The `render` group was NOT the blocker on this host. This host's systemd ships
      `KERNEL=="renderD*", GROUP="render", MODE="0666"`, so `/dev/dri/renderD128` is
      `crw-rw-rw-` and `glats` opens it `O_RDWR` without any group membership and
      without any ACL. No ACL was ever applied, so there is nothing to revert;
      `getfacl` shows only the three base entries. The `render` group addition in
      `linux/system/base/users.nix` is therefore portability hardening against a
      stricter udev rule, not the unblocker. The upstream documentation describes
      `MODE="0660"`, so the difference is in this host's systemd, not in the driver.
  Two deviations from the instructions, both forced by evidence:
  - The scratch `xorg.conf` MUST keep `Load "xorgxrdp"`. Dropping it produces
    `Fatal server error: no screens found`, because `xrdpdev_drv.so` has undefined
    `rdp*` symbols that only `libxorgxrdp.so` provides.
  - No ACL workaround was needed, per (b) above.
  Parent spot check after the writer returned: the generated `sesman.ini` `[Xorg]`
  section now points at the glamor-enabled store path
  `/nix/store/c3dm88pgz9j1bfbif4nx16b757g95c7n-xorgxrdp-0.10.5` (previously
  `...iwicljkngxlr206zxqxmzcnwqjmpqsny-...`), and the driver in that store path
  contains 20 glamor-related strings including `rdpPreInit: drm device looks ok, use
  glamor set`, `rdpPreInit: glamor init ok` and `rdpPreInit: unsupported render node`,
  against 0 in the previous build. The NVIDIA card was never opened: the scratch
  session loaded the `iris` driver on the Intel node.
- L6 (2026-11-11): implementation detail worth recording. Overriding
  `xrdp.passthru.xorgxrdp` alone is NOT sufficient, because nixpkgs' `xrdp`
  `postInstall` bakes the xorgxrdp store path into the generated `sesman.ini` from a
  lexical binding of its own. The `xrdp` derivation is therefore overridden as well,
  and its `postInstall` substitutes both the module path and the session config path
  to the glamor-enabled build. If a future nixpkgs changes that `postInstall`, the
  substitution fails loudly at build time instead of silently reverting to software
  GL.
  Also: nixpkgs `xorg-server` 21.1.24 already ships
  `lib/xorg/modules/libglamoregl.so` and the `GLAMOR_FOR_XORG` API in `glamor.h`, so
  upstream xorgxrdp 0.10.5 compiles with `--enable-glamor` and needs NO patch.
- L5 (2026-11-11): THE FIX, implemented and PROVED EMPIRICALLY on a scratch display.
  Two repository files changed, nothing else:
    1. `overlays/linux.nix`: `xorgxrdp` (exposed by nixpkgs' `xrdp` package through
       `passthru.xorgxrdp`) is overridden with `--enable-glamor` and the glamor build
       inputs (`libepoxy`, `libglvnd`, `libgbm`). Because nixpkgs' `xrdp` `postInstall`
       bakes the xorgxrdp store path into the generated `sesman.ini`, the `xrdp`
       derivation is overridden as well and its `sesman.ini` is repointed at the
       glamor-enabled build. The generated `[Xorg]` section now reads:
         param=-modulepath
         param=/nix/store/c3dm88pgz9j1bfbif4nx16b757g95c7n-xorgxrdp-0.10.5/lib/xorg/modules,/nix/store/pf5s0lj8pnx406syb60i3x4zk83pm8gx-xorg-server-21.1.24/lib/xorg/modules
         param=-config
         param=/nix/store/c3dm88pgz9j1bfbif4nx16b757g95c7n-xorgxrdp-0.10.5/etc/X11/xrdp/xorg.conf
       The glamor macro is proven present in the built module: `strings` on
       `xrdpdev_drv.so` yields `rdpPreInit: drm device looks ok, use glamor set`,
       `rdpPreInit: glamor init ok`, `glamor_egl_init`, `glamor_pixmap_from_fd` and the
       `glamoregl` submodule name. The build needed NO new upstream patch and NO
       `xorg.conf` change: nixpkgs' `xorg-server` 21.1.24 already ships
       `lib/xorg/modules/libglamoregl.so`, which upstream `xrdpdev` loads by name.
    2. `linux/system/base/users.nix`: `render` added to `users.users.glats.extraGroups`
       (`config.ids.gids.render` = 303 in this nixpkgs revision; verified on both
       `rog` and `thinkcentre`).
  EMPIRICAL PROOF on scratch display `:77` (display `:10` was never touched; the live
  session kept running throughout). A scratch `xorg.conf` was written under
  `$(mktemp -d)` outside the repository, keeping the `xrdpdev` driver and its
  `DRMDevice`/`DRI3`/`DRMAllowList` options byte-identical to the shipped file, and
  keeping the `Device`, `Screen` and `Monitor` sections intact, but dropping the
  xrdp-specific input devices (`xrdpkeyb`, `xrdpmouse`) and the `ServerLayout`
  `InputDevice` lines. The `Load "xorgxrdp"` module entry was KEPT: a first attempt
  without it failed with `Fatal server error: no screens found`, because
  `xrdpdev_drv.so` has undefined `rdp*` symbols (`rdpClientConInit`,
  `rdpComposite`, ...) that only `libxorgxrdp.so` provides. The scratch Xorg ran as
  the unprivileged user `glats`, exactly like a real XRDP session X server.
  Scratch Xorg log (excerpt):
      rdpProbe: found DRMDevice xorg.conf value [/dev/dri/renderD128]
      rdpProbe: found DRI3 xorg.conf value [1]
      rdpProbe: found DRMAllowList xorg.conf value [amdgpu i915 msm radeon]
      rdpPreInit: /dev/dri/renderD128 open ok, fd 11
      rdpPreInit: name [i915]
      rdpPreInit: drm device looks ok, use glamor set
      (II) Loading sub module "glamoregl"
      (II) LoadModule: "glamoregl"
      (II) Loading .../xorg-server-21.1.24/lib/xorg/modules/libglamoregl.so
      rdpPreInit: glamor module load ok
      (II) XRDPDEV(0): glamor: Using OpenGL 4.6 context.
      (II) XRDPDEV(0): glamor X acceleration enabled on Mesa Intel(R) HD Graphics 630 (KBL GT2)
      rdpPreInit: glamor init ok
      rdpScreenInit: glamor_init ok
      (II) XRDPDEV(0): [DRI2] Setup complete
      (II) XRDPDEV(0): [DRI2]   DRI driver: iris
      rdpScreenInit: rdpDri2Init ok
      rdpScreenInit: rdpDri3Init ok
      (II) Initializing extension DRI3
      (II) AIGLX: Loaded and initialized iris
      (II) GLX: Initialized DRI2 GL provider for screen 0
  CLIENT PROBES on `:77`:
      glxinfo -B: Vendor: Intel (0x8086)
                Device: Mesa Intel(R) HD Graphics 630 (KBL GT2) (0x591b)
                Accelerated: yes
                Max core profile version: 4.6
      ghostty (GHOSTTY_LOG_LEVEL=info): info(opengl): loaded OpenGL 4.6
                `libEGL warning: DRI3 error: Could not get DRI3 device` -> ABSENT
                (grep count of that string over the probe output: 0)
  A/B BASELINE on the live, unfixed session `:10` (read-only probe, no client window
  opened): `glxinfo -B` reports `Vendor: Mesa (0xffffffff)`,
  `Device: llvmpipe (LLVM 21.1.8, 256 bits)`, `Accelerated: no`. Same host, same
  config, same render node — the only difference is the glamor-enabled binary.
  S1 IS SATISFIED: the session X server now exposes hardware GL backed by the Intel
  i915 render node instead of falling back to software OpenGL.
  The scratch Xorg was killed and the scratch directory removed at the end of the
  test; the repository working tree only carries the two files above plus this
  document.
- L6 (2026-11-11): TWO CORRECTIONS to L4, both established from the live host and
  both material to the acceptance criteria.
  CORRECTION 1 — the "secondary blocker" (render group) DOES NOT EXIST on this host.
  L4 inferred that `open("/dev/dri/renderD128", O_RDWR)` would return EACCES for
  `glats` because render nodes are `MODE="0660" GROUP="render"`. The systemd
  revision actually installed here (`50-udev-default.rules`, line 61) reads
  `SUBSYSTEM=="drm", KERNEL=="renderD*", GROUP="render", MODE="0666"`, and the live
  node confirms it: `/dev/dri/renderD128` is `crw-rw-rw- root:render` (mode 0666),
  and `open(..., O_RDWR)` as `glats` SUCCEEDS (`fd 3`). Therefore NO ACL workaround was
  needed for the scratch test, none was applied, and none had to be reverted:
  `getfacl /dev/dri/renderD128` shows only the three base entries
  (`user::rw-`, `group::rw-`, `other::rw-`) and no extended ACL. The `render` group
  addition is kept because it is the upstream-recommended and portable form (and
  because older systemd revisions and other hosts do ship 0660 render nodes), but on
  this host it is NOT what unblocks the render node — the glamor build is.
  CORRECTION 2 — `xrandr --listproviders` IS NOT A VALID HARDWARE-ACCELERATION SIGNAL
  FOR THIS DRIVER. It reports `Providers: number : 0` BOTH on the broken live
  session `:10` and on the fixed scratch session `:77`. The RandR provider list is
  built from `rrScrPriv->provider`, which only a DDX that registers a RandR 1.4
  provider populates; upstream xorgxrdp never registers one (the only occurrence of
  the word in the whole tree is the `RRProviderPtr provider` callback parameter of
  the DRI3 `open_client` hook). The meaningful equivalents, both observed, are the
  server-side `GLX: Initialized DRI2 GL provider for screen 0` /
  `AIGLX: Loaded and initialized iris` and the client-side `glxinfo -B` renderer
  string `Device: Mesa Intel(R) HD Graphics 630 (KBL GT2)`, `Accelerated: yes`.
  Consequently S1's "provider list is non-empty" clause cannot be met with the
  `xrdpdev` driver by any configuration; the hardware-renderer clause is met and
  should be read with this correction. S2 (stable `/dev/dri/by-path/...` identifier)
  and S3 (no NVIDIA proprietary driver) are unaffected and still stand; S3 is
  additionally honoured by construction, since the scratch Xorg loaded `iris` on
  `/dev/dri/renderD128` and never touched the NVIDIA card.
