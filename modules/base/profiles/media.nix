# Media profile
# Audio/video tools and GPU acceleration for media playback.
#
# `mpv`, `wiremix`, and `ffmpeg` are gated with `lib.mkIf (cfg !=
# "gnome")` because omarchy-nix already provides them on t14 (suite =
# "gnome"). See omarchy-nix/modules/packages.nix.
{ pkgs
, config
, lib
, ...
}:
let
  cfg = config.my.desktop.suite;
  nonGnome = p: lib.mkIf (cfg != "gnome") p;
in
with pkgs;
[
  # Playback
  (nonGnome mpv)
  (nonGnome wiremix)
  (nonGnome ffmpeg)

  # GPU acceleration (Intel iGPU)
  intel-vaapi-driver
  libva-vdpau-driver
  libva-utils
  intel-gpu-tools

  # GStreamer plugins for media frameworks
  gst_all_1.gst-plugins-base
  gst_all_1.gst-plugins-good
]
