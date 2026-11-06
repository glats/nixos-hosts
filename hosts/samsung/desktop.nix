{ pkgs, ... }:

{
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

  services = {
    pulseaudio.enable = false;
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };

    printing.enable = true;
    resolved.enable = true;
    gvfs.enable = true;
    fstrim.enable = true;
    tumbler.enable = true;
  };

  security.rtkit.enable = true;

  hardware = {
    enableRedistributableFirmware = true;
    bluetooth.enable = true;
    graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver
        (intel-vaapi-driver.override { enableHybridCodec = true; })
        libva-vdpau-driver
        libvdpau-va-gl
        vpl-gpu-rt
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    pipewire-module-xrdp
    intel-vaapi-driver
    libva-vdpau-driver
  ];
}
