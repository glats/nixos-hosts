# Media profile
# Audio/video tools and GPU acceleration for media playback.
#
# Note: mpv, wiremix, and ffmpeg are now ungated. t14 evaluates them
# from BOTH nixos-hosts and omarchy-nix; the Nix store deduplicates
# the derivations, so there is no runtime cost.
{ pkgs }:
with pkgs;
[
  # Playback
  mpv
  wiremix
  ffmpeg

  # GPU acceleration (Intel iGPU)
  intel-vaapi-driver
  libva-vdpau-driver
  libva-utils
  intel-gpu-tools

  # GStreamer plugins for media frameworks
  gst_all_1.gst-plugins-base
  gst_all_1.gst-plugins-good
]
