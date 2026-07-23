# Media profile
# Audio/video tools and GPU acceleration for media playback.
#
# Note: mpv, wiremix, and ffmpeg are now ungated. t14 evaluates them
# from BOTH nixos-hosts and omarchy-nix; the Nix store deduplicates
# the derivations, so there is no runtime cost.
#
# VA-API driver notes
# -------------------
# The Mesa gallium VA-API drivers (including radeonsi_drv_video.so for
# AMD, and the r600/nouveau legacy drivers) are provided directly by the
# `mesa` package in modern nixpkgs — there is no separate
# `libva-mesa-driver` package to pin.  On t14, `mesa` is pulled in
# transitively via `hardware.graphics.enable` and the
# `nixos-hardware` T14 AMD Gen 4 profile, so the radeonsi VA driver
# is available automatically.
#
# The packages below cover the rest of the VA-API stack:
#   * intel-vaapi-driver   — legacy Intel i965 driver (kept as fallback
#                            in case Mesa's iris driver regresses on a
#                            rogue/thinkcentre Intel iGPU).
#   * libva-vdpau-driver   — VDPAU → VA-API shim (some apps still probe
#                            for it on first use).
#   * libva-utils          — provides `vainfo`, the canonical
#                            verification tool documented in
#                            modules/hardware/amd-laptop.nix.
#   * intel-gpu-tools      — provides `intel_gpu_top` for activity
#                            monitoring (works on AMD too, since Linux
#                            exposes the Video engine via /dev/dri/renderD128).
{ pkgs }:
with pkgs;
[
  # Playback
  mpv
  wiremix
  ffmpeg

  # GPU acceleration (VA-API stack — see comment block above)
  libva-utils
  intel-gpu-tools

  # GStreamer plugins for media frameworks
  gst_all_1.gst-plugins-base
  gst_all_1.gst-plugins-good
]
