let
  flake = builtins.getFlake ("path:" + toString ../.);
  hosts = [
    "rog"
    "thinkcentre"
    "t14"
  ];
  checkHost =
    host:
    let
      config = flake.nixosConfigurations.${host}.config;
      printers = builtins.filter (
        printer: printer.name == "brother"
      ) config.hardware.printers.ensurePrinters;
      scanner = config.hardware.sane.brscan4.netDevices.brother or { };
    in
    assert config.services.printing.enable;
    assert builtins.any (driver: (driver.pname or "") == "brlaser") config.services.printing.drivers;
    assert builtins.length printers == 1;
    assert (builtins.head printers).deviceUri == "socket://brother.lan:9100";
    assert (builtins.head printers).model == "drv:///brlaser.drv/br1610.ppd";
    assert config.services.printing.browsing == (host == "t14");
    assert config.services.printing.listenAddresses == [ "localhost:631" ];
    assert !config.services.printing.defaultShared;
    assert config.hardware.sane.enable;
    assert config.hardware.sane.brscan4.enable;
    assert scanner.model == "DCP-1610NW";
    assert scanner.nodename == "brother.lan";
    assert scanner.ip == null;
    assert builtins.any (
      package: (package.pname or "") == "simple-scan"
    ) config.environment.systemPackages;
    {
      name = host;
      value = "passed";
    };
in
builtins.listToAttrs (map checkHost hosts)
