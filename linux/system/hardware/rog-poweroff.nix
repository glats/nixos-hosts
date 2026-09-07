{ config
, lib
, pkgs
, ...
}:

let
  cfg = config.hardware.rog.s5-recovery;

  # Staged opt-in gates for the rog S5 poweroff recovery (openspec change
  # rog-shutdown-s5-diagnose-and-fix). Each stage is independent and can be
  # rolled back by disabling its boolean; later stages REQUIRE diagnostics
  # (asserted below) while diagnostics alone never changes shutdown behavior.
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
    # Staging contract: the write/fallback stages are dangerous exactly
    # because they bypass parts of the normal poweroff path — they may only
    # be enabled while the diagnostic pipeline is capturing evidence.
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

    # Persistent diagnostic state (design row "Persistent dump"):
    #  - printk.always_kmsg_dump=1 dumps the full kmsg buffer on emergency
    #    and shutdown paths instead of only panic-level records.
    #  - efi_pstore.pstore_disable=0 keeps the EFI pstore backend
    #    registered (the rog kernel has PSTORE=y, EFI_VARS_PSTORE=y and the
    #    default-disable option unset, so this pins the intended state).
    #  - configfs + netconsole modules: the runtime target is created in
    #    configfs by netconsole-setup (CONFIG_NETCONSOLE_DYNAMIC=y).
    boot.kernelModules = lib.mkIf cfg.diagnostics.enable [
      "configfs"
      "netconsole"
    ];
    boot.kernelParams = lib.mkIf cfg.diagnostics.enable [
      "printk.always_kmsg_dump=1"
      "efi_pstore.pstore_disable=0"
    ];

    systemd.services.netconsole-setup = lib.mkIf (cfg.diagnostics.enable && netconsoleCfg.enable) {
      description = "Configure netconsole target and verify receiver readiness";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "systemd-modules-load.service"
      ];
      # configfs is auto-mounted by systemd PID 1 (/sys/kernel/config) and
      # pstore by its mount-setup as well; netconsole/configfs modules come
      # from boot.kernelModules via systemd-modules-load, which we order
      # after explicitly.
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # Needs /dev/kmsg, configfs writes and the :6665 UDP bind — the
        # root context, no sandboxing. A nonzero exit leaves the unit
        # failed so missing ACKs are visible in `systemctl --failed`.
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
  };
}
