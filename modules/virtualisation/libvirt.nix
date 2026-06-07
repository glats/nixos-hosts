{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.virtualisation.libvirt-custom = {
    enable = lib.mkEnableOption "Libvirt virtualisation" // {
      default = true;
    };
  };

  config = lib.mkIf config.virtualisation.libvirt-custom.enable {
    virtualisation.libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
      };
    };

    programs.virt-manager.enable = true;
  };
}
