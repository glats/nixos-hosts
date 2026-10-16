{ ... }:
{
  services.udev.extraRules = ''
    # Android devices with Google vendor ID
    SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", MODE="0660", GROUP="adbusers"

    # Linux Foundation Multifunction Composite Gadget (g_multi, Knulli, etc.)
    SUBSYSTEM=="usb", ATTR{idVendor}=="1d6b", ATTR{idProduct}=="0104", MODE="0660", GROUP="adbusers"
  '';
}
