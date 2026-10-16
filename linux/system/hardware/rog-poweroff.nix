{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hardware.rog.s5-recovery;

  netconsoleCfg = cfg.netconsole;
in
{
  options.hardware.rog.s5-recovery = {
    diagnostics.enable = lib.mkEnableOption ''
      rog S5 shutdown diagnostics: persistent kmsg dumping
      (printk.always_kmsg_dump=1 + EFI pstore) and the netconsole pipeline
      (configfs target on enp3s0 to the thinkcentre receiver, verified by a
      nonce/ACK handshake at boot). This changes nothing about how the
      system powers off — it only makes shutdown hangs observable.
    '';

    netconsole = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Wire the netconsole readiness probe oneshot (netconsole-setup).
          The kernel modules and the persistent-dump kernel parameters stay
          active even when this is off — they belong to diagnostics.
        '';
      };
      interface = lib.mkOption {
        type = lib.types.str;
        default = "enp3s0";
        description = "Interface whose current (DHCP) IPv4 is the netconsole source address.";
      };
      localPort = lib.mkOption {
        type = lib.types.port;
        default = 6665;
        description = "UDP source port rog binds; the receiver ACKs the nonce probe back to it.";
      };
      remoteIP = lib.mkOption {
        type = lib.types.str;
        default = "172.16.0.11";
        description = "Netconsole receiver address (thinkcentre static, slice 1).";
      };
      remoteMAC = lib.mkOption {
        type = lib.types.str;
        default = "6c:4b:90:2d:97:42";
        description = "Netconsole receiver MAC (thinkcentre enp0s31f6).";
      };
      remotePort = lib.mkOption {
        type = lib.types.port;
        default = 6666;
        description = "Netconsole receiver UDP port (netconsole-log on thinkcentre).";
      };
    };

    s5Write.enable = lib.mkEnableOption ''
      stage 2: the firmware-derived PM1a S5 write from the shutdown ramfs
      hook. Requires diagnostics.enable; enable only after Gate 1 evidence.
    '';

    efiFallback.enable = lib.mkEnableOption ''
      stage 3: the DMI-scoped EFI ResetSystem shutdown fallback kernel
      module, registered below the ACPI prepare path. Requires
      diagnostics.enable; enable only after Gate 2/3 evidence.
    '';
  };

  config = {
    assertions = [
      {
        assertion = !(cfg.s5Write.enable && !cfg.diagnostics.enable);
        message = "hardware.rog.s5-recovery.s5Write.enable requires diagnostics.enable";
      }
      {
        assertion = !(cfg.efiFallback.enable && !cfg.diagnostics.enable);
        message = "hardware.rog.s5-recovery.efiFallback.enable requires diagnostics.enable";
      }
    ];

    boot.kernelModules = lib.mkMerge [
      (lib.mkIf cfg.diagnostics.enable [
        "configfs"
        "netconsole"
      ])
      (lib.mkIf cfg.efiFallback.enable [
        "rog-efi-poweroff"
      ])
    ];
    boot.kernelParams = lib.mkIf cfg.diagnostics.enable [
      "printk.always_kmsg_dump=1"
      "efi_pstore.pstore_disable=0"
    ];

    boot.consoleLogLevel = lib.mkIf cfg.diagnostics.enable (lib.mkForce 7);

    systemd.services.netconsole-setup = lib.mkIf (cfg.diagnostics.enable && netconsoleCfg.enable) {
      description = "Configure netconsole target and verify receiver readiness";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "systemd-modules-load.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = ''
          ${pkgs.nixos-scripts}/bin/netconsole-setup \
            -interface ${netconsoleCfg.interface} \
            -local-port ${toString netconsoleCfg.localPort} \
            -remote-ip ${netconsoleCfg.remoteIP} \
            -remote-mac ${netconsoleCfg.remoteMAC} \
            -remote-port ${toString netconsoleCfg.remotePort}
        '';
      };
    };

    systemd.services.rog-poweroff-stage = lib.mkIf cfg.s5Write.enable {
      description = "Stage validated S5 poweroff values for the shutdown ramfs hook";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        RuntimeDirectory = "rog-poweroff";
        RuntimeDirectoryPreserve = "yes";
        ExecStart = "${pkgs.nixos-scripts}/bin/rog-poweroff-hook stage";
      };
    };

    systemd.shutdownRamfs.contents."/etc/systemd/system-shutdown/rog-poweroff" =
      lib.mkIf cfg.s5Write.enable
        {
          source = "${pkgs.nixos-scripts}/bin/rog-poweroff-hook";
        };
    systemd.shutdownRamfs.storePaths = lib.mkIf cfg.s5Write.enable [
      "${pkgs.nixos-scripts}/bin"
    ];

    boot.extraModulePackages = lib.mkIf cfg.efiFallback.enable [
      (pkgs.callPackage ../../../pkgs/rog-efi-poweroff {
        kernel = config.boot.kernelPackages.kernel;
      })
    ];
  };
}
