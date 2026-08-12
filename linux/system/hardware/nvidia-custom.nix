{ config
, pkgs
, lib
, ...
}:

{
  options.hardware.nvidia-custom = {
    enable = lib.mkEnableOption "NVIDIA hardware configuration" // {
      default = true;
    };
  };

  config = lib.mkIf config.hardware.nvidia-custom.enable (
    let
      btopWithCuda = pkgs.btop.override { cudaSupport = true; };
    in
    {
      boot.kernelModules = [
        "nvidia"
        "nvidia_modeset"
        "nvidia_uvm"
        "nvidia_drm"
      ];

      boot.extraModprobeConfig = ''
        options nvidia NVreg_PreserveVideoMemoryAllocations=0 NVreg_DynamicPowerManagement=0x00
        options nvidia-drm modeset=1
      '';

      hardware.nvidia = {
        open = false;
        nvidiaSettings = true;
        # GTX 1050 requires legacy 580.xx driver (595.xx dropped support for this GPU)
        package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
      };

      services.xserver.videoDrivers = [ "nvidia" ];

      hardware.nvidia-container-toolkit.enable = true;

      # nvidia-ctk cdi generate hangs indefinitely with legacy 580 driver
      # (NVML incompatibility with nvidia-container-toolkit 1.18.x).
      # Upstream module sets requiredBy = [ "docker.service" ], which means
      # systemd kills docker every time the CDI generator restarts (via udev).
      # Fix: demote to wantedBy so docker can start without CDI spec ready.
      # GPU passthrough in containers won't work, but docker itself will.
      # Refs: NixOS/nixpkgs#463645, #451912, #468385
      systemd.services.nvidia-container-toolkit-cdi-generator = {
        requiredBy = lib.mkForce [ ];
        serviceConfig.TimeoutStartSec = 120;
      };

      hardware.graphics = {
        enable = true;
        enable32Bit = true;
        extraPackages = with pkgs; [
          nvidia-vaapi-driver
        ];
      };

      environment.etc."X11/xorg.conf.d/10-nvidia-monitor.conf".text = ''
        Section "Monitor"
            Identifier      "eDP-1"
            Option          "ignore" "true"
        EndSection

        Section "Monitor"
            Identifier      "HDMI-1"
            Option          "Enable" "true"
        EndSection
      '';

      environment.systemPackages = with pkgs; [
        nvidia-container-toolkit
      ];

      security.wrappers.btop = {
        owner = "root";
        group = "root";
        capabilities = "cap_perfmon=ep";
        source = "${btopWithCuda}/bin/btop";
      };
    }
  );
}
