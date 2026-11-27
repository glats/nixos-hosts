{
  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="pci", ATTR{vendor}=="0x10ec", ATTR{device}=="0x5229", ATTR{power/control}="on"
  '';
}
