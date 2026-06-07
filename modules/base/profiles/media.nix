# Media profile
# Audio/video tools and GPU acceleration for media playback.
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
