# Exploration: Video Acceleration on t14 (ThinkPad T14 AMD Gen 4)

> Investigation answer: **YES, the t14 has the basic hardware video acceleration stack
> configured.** The required kernel driver (`amdgpu`), the VA-API runtime, and the
> userspace decoder/player packages are all wired in. There is room for small
> follow-up polish (explicit Mesa VA driver, per-user `mpv` hwdec default) but the
> configuration is functional as-is. This document explains what's there, how to
> verify it on the live machine, and what (if anything) is still worth adding.

## Current State

### 1. Kernel & graphics driver enablement

`hosts/t14/default.nix` (line 43) imports `modules/hardware/amd-laptop.nix`, which
contains exactly one line that matters for video acceleration:

```nix
# modules/hardware/amd-laptop.nix:8
hardware.graphics.enable = true;
```

That single option is what activates NixOS's AMD/Intel graphics support: it adds
`amdgpu` (and on Intel systems, `i915`) to `boot.initrd.kernelModules` (early
KMS), to `services.xserver.videoDrivers`, and pulls in the
`hardware.graphics.extraPackages` defaults from nixpkgs. On the T14 AMD Gen 4
the integrated GPU is Radeon 780M (Phoenix, RDNA3) or Radeon 660M/680M
(Rembrandt, RDNA2), so the `amdgpu` kernel driver is the right one — no
firmware blobs beyond what `hardware.enableRedistributableFirmware` already
ships via `hardware-configuration.nix` are needed.

The `nixos-hardware` T14 profile (wired in via `flake.nix:221` as
`nixos-hardware.nixosModules.lenovo-thinkpad-t14-amd-gen4`) layers on:

- amdgpu in the initrd (early KMS — required for clean boot on amdgpu),
- 32-bit graphics support (DRM, mesa, etc. — needed only for Steam/proprietary
  32-bit games, not for video),
- `amd_pstate=active` (CPU, not GPU),
- fstrim, backlight, touchpad.

None of these conflict with the T14 host config; they merge via `mkDefault`.

### 2. Userspace VA-API packages

`hosts/t14/default.nix` (line 28) imports `modules/base/packages.nix`, which in
turn imports `modules/base/profiles/media.nix`. That profile is the source of
truth for media acceleration packages on every Linux host in this repo:

```nix
# modules/base/profiles/media.nix
[
  mpv                        # player with VA-API hwdec backend
  wiremix                    # PipeWire mixer
  ffmpeg                     # CLI encoder/decoder; has h264_vaapi, hevc_vaapi, vp9_vaapi, av1_vaapi
  intel-vaapi-driver         # iHD — the modern VA-API driver (works for AMD iGPU too)
  libva-vdpau-driver         # VDPAU bridge (legacy apps that only speak VDPAU)
  libva-utils                # provides `vainfo` (the canonical verification tool)
  intel-gpu-tools            # provides `intel_gpu_top` (also works for AMD iGPU on modern kernels)
  gst_all_1.gst-plugins-base # GStreamer
  gst_all_1.gst-plugins-good # GStreamer
]
```

The `intel-vaapi-driver` package ships the iHD media driver. On AMD systems the
Mesa-based driver (`libva-mesa-driver`, exposed as the `radeonsi` VA-API
backend) is the primary choice; `iHD` works as a fallback for H.264/HEVC when
Mesa's driver doesn't support a given codec profile. Together they cover
H.264, HEVC, VP9, and AV1 decode on the T14's RDNA2/RDNA3 iGPU.

> The T14 currently does **not** explicitly add `libva-mesa-driver`. nixpkgs's
> `hardware.graphics.extraPackages` list (used implicitly when
> `hardware.graphics.enable = true`) is expected to include it on `x86_64-linux`
> in unstable. If `vainfo` reports only `i965` (the legacy Intel driver) the
> Mesa driver was not pulled in transitively and will need to be added
> explicitly. Verification with `vainfo` on the live host resolves this.

### 3. Player / decoder binaries

- `mpv` (from `media.nix`) — auto-detects VA-API at runtime; can be pinned to
  always use it with `hwdec=vaapi` in `~/.config/mpv/mpv.conf`.
- `ffmpeg` (from `media.nix`) — compiled with `--enable-vaapi` in nixpkgs by
  default; `ffmpeg -hwaccels` lists `vaapi`, `vdpau`, etc.
- `wiremix` (PipeWire mixer) — unrelated to VA-API, just a UI tool.
- `libva-utils` → `vainfo` (the test command for "is VA-API working?").

### 4. Wayland / Hyprland specifics

Hyprland (provided by `omarchy-nix`) is a wlroots-based compositor. It does
**not** need any VA-API config to render. The relevant facts:

- wlroots uses `libdrm` + `amdgpu` for direct scanout and GBM buffers. This
  works because of the `amdgpu` kernel module loaded by `hardware.graphics.enable`.
- Screen capture (e.g. `wlrobs`, OBS Wayland, `grim`) uses DMA-BUF / `wlr-screencopy`
  — that path is independent of VA-API. "Hardware video acceleration" is **not**
  the same thing as "screen capture works".
- Browser GPU decoding (Brave, set as `omarchy.browser` in `hosts/t14/default.nix:158`)
  uses `--enable-features=VaapiVideoDecodeLinuxGL` by default in modern Chromium;
  no extra config needed.

### 5. Environment variables

`LIBVA_DRIVER_NAME` is **not** set anywhere in the t14 config (or anywhere
else in the repo). On modern Mesa + libva (≥ 2.20), the autodetect path picks
the right driver (`radeonsi` for AMD, `iHD` for Intel). Forcing a value is
rarely needed; if a specific driver is desired, that is a per-user concern in
`~/.config/environment.d/`.

## Affected Areas

| File | Why it is relevant |
|------|--------------------|
| `hosts/t14/default.nix` | Imports `amd-laptop.nix` and `packages.nix` — the two load-bearing modules for VA-API. |
| `modules/hardware/amd-laptop.nix` | The single line `hardware.graphics.enable = true` is what enables the AMD/Intel GPU stack. |
| `modules/base/packages.nix` | Imports the `media.nix` profile that supplies `mpv`, `ffmpeg`, `libva-utils`, `intel-vaapi-driver`, etc. |
| `modules/base/profiles/media.nix` | The actual package list. Adding `libva-mesa-driver` (if not pulled in transitively) would happen here. |
| `flake.nix` (`nixosModules.lenovo-thinkpad-t14-amd-gen4`) | The nixos-hardware profile layered on top. Currently contributes early-KMS amdgpu + 32-bit graphics. |
| `hosts/t14/home/omarchy.nix` | Where a per-user `programs.mpv` or `mpv.conf` with `hwdec=vaapi` would go. (Not present today.) |
| `modules/hardware/nvidia.nix` (reference only) | Shows the equivalent `hardware.graphics.extraPackages` pattern for NVIDIA. The AMD path needs much less because nixpkgs already includes the Mesa drivers in the default `extraPackages`. |

## Approaches

### Option A — Confirm and document (no code change)

Acknowledge that the existing config is functionally complete. Add a short
verification recipe to this artifact (or a follow-up doc) explaining how to run
`vainfo` and `intel_gpu_top` to confirm the driver is loaded and active on
the live machine.

- **Pros**: Zero risk, zero rebuild time. Surfaces the answer to the user
  immediately. The existing setup is enough for the canonical use cases
  (mpv with `--hwdec=vaapi`, Brave GPU-decoded video, ffmpeg with
  `-hwaccel vaapi`).
- **Cons**: Doesn't make the behavior deterministic. If `vainfo` on the live
  host reports the wrong driver (e.g. `i965` instead of `radeonsi`), the
  user still needs to add an explicit `libva-mesa-driver` package.
- **Effort**: Low (write a doc, verify on host).

### Option B — Make VA-API explicit (small, low-risk)

Add `libva-mesa-driver` to `modules/base/profiles/media.nix` so the AMD
`radeonsi` VA driver is always present in the closure (in addition to iHD
and the legacy i965 path). Optionally set `LIBVA_DRIVER_NAME=radeonsi` as a
system env var in `modules/hardware/amd-laptop.nix` to lock the choice.

- **Pros**: Deterministic. Survives nixpkgs changes that might drop the Mesa
  driver from `hardware.graphics.extraPackages` defaults. Removing a single
  moving part for the user.
- **Cons**: Slightly larger closure. Risk of pinning a specific driver name
  and breaking if Mesa renames it (low risk in practice).
- **Effort**: Low (2-3 lines, one file).

### Option C — Per-user mpv config on t14

Add a small `home.file.".config/mpv/mpv.conf".text = "hwdec=vaapi\n...` to
`hosts/t14/home/omarchy.nix` (or a new `hosts/t14/home/mpv.nix` fragment).
Optionally enable `programs.mpv` to manage the config declaratively.

- **Pros**: Per-user preference becomes reproducible. mpv always uses VA-API
  hardware decoding by default.
- **Cons**: Strictly personal preference; not all users want hwdec forced.
  One more file under HM.
- **Effort**: Low.

## Recommendation

**Run Option A first.** The user asked "do I have it?" — the answer is yes,
subject to verifying with `vainfo` on the live host. The fastest way to
close the loop is to run:

```sh
# On the t14, after a rebuild that already includes media.nix:
vainfo
# Should show: "Driver version: ..." and a list of profile entries
# (H264, HEVC, VP9, AV1) for the radeonsi or iHD driver.

# Optional smoke test: decode a 1080p H.264 clip with VA-API and check
# that intel_gpu_top shows video engine activity:
mpv --hwdec=vaapi --vo=gpu /path/to/some.mp4
intel_gpu_top
```

If `vainfo` shows the radeonsi driver and a non-empty profile list, the
existing config is enough and no code change is needed. Document the
verification recipe as a comment in `modules/hardware/amd-laptop.nix` and
call it done.

**Escalate to Option B only if `vainfo` shows a missing/legacy driver.**
That is a real signal that `libva-mesa-driver` is not being pulled in by
the nixpkgs defaults and must be added explicitly.

**Option C is optional polish.** It only matters if the user wants mpv
to default to hardware decoding without passing `--hwdec=vaapi` on the
command line. This is taste, not correctness.

## Risks

- **No real risk** in the current state: the kernel driver, the libva
  runtime, and the user-facing tools are all present.
- **Autodetect edge case**: if a future nixpkgs release stops shipping
  `libva-mesa-driver` as part of `hardware.graphics.extraPackages` defaults
  for `x86_64-linux`, the T14's VA-API stack would silently fall back to
  `i965` (which is unmaintained and may not support newer codecs). Pinning
  the Mesa driver in `media.nix` (Option B) insures against this.
- **Hyprland / Wayland screen capture is unrelated to VA-API.** A user
  confusing the two (e.g., asking "does screen recording use hardware
  acceleration?") would get the wrong mental model. Worth a one-line
  clarification in any user-facing doc.
- **No `services.xserver.videoDrivers` override for t14.** With
  `hardware.graphics.enable = true` and the nixos-hardware profile layered
  on, this is set automatically to `["amdgpu"]`. X11 fallback is a
  non-issue on Hyprland, but worth being aware of.
- **T14 does not import `nvidia.nix`.** It is pure AMD/iGPU. Do not
  recommend NVIDIA VA-API packages (`nvidia-vaapi-driver`) here — the
  iGPU is what gets used.

## Ready for Proposal

**Yes — but the proposal should be tiny.**

The investigative answer is sufficient. The recommended next step is a
**documentation-only change** plus an optional **verify-and-pin task**:

1. Add a brief verification recipe (the `vainfo` / `mpv --hwdec=vaapi` /
   `intel_gpu_top` sequence) as a comment in
   `modules/hardware/amd-laptop.nix`, or as a `README`/`RUNBOOK.md` style
   note in the t14 host folder. This makes the answer reproducible for the
   user without forcing a code change.
2. **Conditionally**, if `vainfo` on the live host does not show the
   radeonsi driver, add `libva-mesa-driver` to
   `modules/base/profiles/media.nix` and re-test. This is a 1-line
   addition and falls under Option B.

The proposal does **not** need a full spec/design/tasks cycle. It can
proceed as a single small apply task gated on the live verification.

If the user wants Option C (per-user mpv default), that can be a separate
proposal or a follow-up — it is a preference, not a correctness fix.
