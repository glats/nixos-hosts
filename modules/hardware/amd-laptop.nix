{ lib, ... }:

{
  # Minimal AMD laptop baseline for the t14 scaffold.
  # Hardware-specific tuning stays deferred until the generated
  # hardware-configuration.nix is available on the target machine.
  hardware.cpu.amd.updateMicrocode = true;
  hardware.graphics.enable = true;

  services.fwupd.enable = true;
  services.power-profiles-daemon.enable = lib.mkDefault true;

  zramSwap.enable = lib.mkDefault true;

  # ## VA-API Hardware Video Acceleration Verification
  #
  # To verify VA-API is working on an AMD GPU (e.g. t14 / Renoir):
  #   vainfo                          — should show "radeonsi" driver with H264/HEVC/VP9/AV1 profiles
  #   mpv --hwdec=vaapi <video>       — should show "Using hardware decoding (vaapi)"
  #   intel_gpu_top                   — "Video" engine should show >0% activity during playback
  #
  # Packages providing these tools are in modules/base/profiles/media.nix
  # The Mesa VA driver (radeonsi_drv_video.so) is provided by the `mesa`
  # package itself via the gallium VA-API interface (no separate
  # `libva-mesa-driver` package is needed in modern nixpkgs).
}
