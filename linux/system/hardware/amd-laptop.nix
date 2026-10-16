{ lib, ... }:

{
  hardware.cpu.amd.updateMicrocode = true;
  hardware.graphics.enable = true;

  services.fwupd.enable = true;
  services.power-profiles-daemon.enable = lib.mkDefault true;

  services.upower = {
    enable = true;
    percentageLow = 15;
    percentageCritical = 8;
    percentageAction = 5;
    criticalPowerAction = "PowerOff";
  };

  zramSwap.enable = lib.mkDefault true;

}
