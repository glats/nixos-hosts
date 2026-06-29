{ lib, ... }:

{
  # Minimal AMD laptop baseline for the t14 scaffold.
  # Hardware-specific tuning stays deferred until the generated
  # hardware-configuration.nix is available on the target machine.
  hardware.cpu.amd.updateMicrocode = true;
  hardware.graphics.enable = true;

  services.fwupd.enable = true;
  services.power-profiles-daemon.enable = lib.mkDefault true;

  # === UPower — battery notifications + critical poweroff ===
  # omarchy-nix provides the battery-monitor user service (mako "Time to
  # recharge!" at 10%) but does NOT enable services.upower.  Without it the
  # monitor silently fails because UPower D-Bus isn't running.  This block
  # enables UPower and adds a clean PowerOff at 5 % to prevent the EC from
  # cutting power abruptly at 0 % (dirty shutdown, btrfs corruption risk).
  # percentageLow/percentageCritical are lower than omarchy's 10 % script
  # threshold — UPower fires at 15 %/8 %, then omarchy's notify-send fires
  # at 10 % (the script reads upower -i, which reports the same percentages).
  #
  # If a future omarchy-nix version adds its own services.upower defaults,
  # this block may need lib.mkForce or merging.
  services.upower = {
    enable = true;
    percentageLow = 15;
    percentageCritical = 8;
    percentageAction = 5;
    criticalPowerAction = "PowerOff";
  };

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
