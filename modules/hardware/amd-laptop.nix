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
}
