{ pkgs, ... }:

let
  scannerConfig = pkgs.writeTextDir "dll.conf" "brother4\n";
  simpleScan = pkgs.simple-scan.overrideAttrs (previous: {
    preFixup = (previous.preFixup or "") + ''
      gappsWrapperArgs+=(
        --set SANE_CONFIG_DIR ${scannerConfig}
        --prefix LD_LIBRARY_PATH : /etc/sane-libs
        --set ADW_DISABLE_PORTAL 1
      )
    '';
  });
in
{
  services.printing = {
    enable = true;
    drivers = [ pkgs.brlaser ];
    defaultShared = false;
  };

  hardware.printers.ensurePrinters = [
    {
      name = "brother";
      description = "Brother DCP-1610NW";
      deviceUri = "socket://brother.lan:9100";
      model = "drv:///brlaser.drv/br1610.ppd";
    }
  ];

  hardware.sane = {
    enable = true;
    brscan4 = {
      enable = true;
      netDevices.brother = {
        model = "DCP-1610NW";
        nodename = "brother.lan";
      };
    };
  };

  environment.systemPackages = [ simpleScan ];
}
