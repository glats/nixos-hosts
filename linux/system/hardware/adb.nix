# ADB (Android Debug Bridge) — USB udev rules for remote/X11 sessions.
#
# systemd 258+ has built-in uaccess rules in 70-uaccess.rules, but those
# only work for local seat sessions (t14/Hyprland). Remote sessions via
# XRDP (rog, thinkcentre) don't get a seat assigned by logind, so uaccess
# never applies. We use explicit GROUP ownership instead.
#
# GROUP/MODE assignments work at priority 99 (extraRules → 99-local.rules)
# because they don't depend on the 73-seat-late.rules uaccess builtin.
#
# Vendor IDs:
#   18d1  — Google (phones, tablets, dev boards)
#   1d6b:0104 — Linux Foundation Multifunction Composite Gadget (Knulli, etc.)
{ ... }:
{
  services.udev.extraRules = ''
    # Android devices with Google vendor ID
    SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", MODE="0660", GROUP="adbusers"

    # Linux Foundation Multifunction Composite Gadget (g_multi, Knulli, etc.)
    SUBSYSTEM=="usb", ATTR{idVendor}=="1d6b", ATTR{idProduct}=="0104", MODE="0660", GROUP="adbusers"
  '';
}
