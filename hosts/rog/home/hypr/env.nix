# Rog Hyprland environment -- Intel iGPU DRM device selection.
#
# Forces Hyprland to use the Intel iGPU for Wayland rendering, preventing
# the NVIDIA GTX 1050 from being used for framebuffer allocation.
# Overrides omarchy HM's default NVIDIA env vars (which are injected
# because services.xserver.videoDrivers contains "nvidia").
#
# IMPORTANT: /dev/dri/card0 is assumed to be Intel iGPU. Verify at
# deploy time via `ls /dev/dri/by-path/` on the rog host. If the Intel
# iGPU is on a different card path, update both WLR_DRM_DEVICES and
# AQ_DRM_DEVICES.
{ lib, ... }:

{
  wayland.windowManager.hyprland.settings = {
    env = [
      # Force Hyprland to Intel iGPU DRM device only
      "WLR_DRM_DEVICES,/dev/dri/card0"
      "AQ_DRM_DEVICES,/dev/dri/card0"

      # Override omarchy HM's NVIDIA env vars (since videoDrivers contains "nvidia")
      "LIBVA_DRIVER_NAME,iHD" # Intel VA-API
      "__GLX_VENDOR_LIBRARY_NAME,mesa" # Mesa GLX (not NVIDIA)
    ];
  };
}
