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

    # netconsole is a console driver: it only receives printk output that
    # passes console_loglevel. boot.nix sets consoleLogLevel = 0 (quiet
    # plymouth boot) and that loglevel=0 lands AFTER the diagnostic
    # loglevel=7 on the cmdline, so the kernel uses it — and every
    # breadcrumb below KERN_EMERG is silently filtered out before it can
    # reach thinkcentre (root cause of the first failed handshake,
    # 2026-09-07). Force the console loglevel to 7 while diagnostics are
    # enabled so the :kmsg breadcrumbs (user notice, level 5) are
    # delivered to the netconsole console.
    boot.consoleLogLevel = lib.mkIf cfg.diagnostics.enable (lib.mkForce 7);

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

    # Stage 2 (s5Write): firmware-derived S5 poweroff. Two pieces:
    #
    # 1. Boot-time staging unit: parses /sys/firmware/acpi/tables/{FACP,
    #    DSDT} + live DMI, validates strictly (fails closed, exit 1) and
    #    writes the derived values to /run/rog-poweroff/staged.json. By
    #    hook time /sys is unmounted, so the values MUST be computed here.
    #    RuntimeDirectoryPreserve keeps the JSON after the unit stops —
    #    without it systemd deletes /run/rog-poweroff at shutdown, before
    #    the ramfs hook could read it.
    systemd.services.rog-poweroff-stage = lib.mkIf cfg.s5Write.enable {
      description = "Stage validated S5 poweroff values for the shutdown ramfs hook";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        RuntimeDirectory = "rog-poweroff";
        RuntimeDirectoryPreserve = "yes";
        # Root context: reads /sys firmware tables, writes /run, breadcrumbs
        # /dev/kmsg. A nonzero exit leaves the unit visibly failed.
        ExecStart = "${pkgs.nixos-scripts}/bin/rog-poweroff-hook stage";
      };
    };

    # 2. Late shutdown hook: systemd-shutdown runs /etc/systemd/system-shutdown/*
    #    with no arguments (the Go binary defaults to the poweroff verb) in
    #    the ramfs, right before reboot(RB_POWER_OFF) — after umounts, which
    #    is exactly the pre-S5 window where the previous layers hung. The
    #    binary is fully static (pure Go), but the store path is copied into
    #    the ramfs via storePaths so the contents symlink resolves there.
    systemd.shutdownRamfs.contents."/etc/systemd/system-shutdown/rog-poweroff" =
      lib.mkIf cfg.s5Write.enable {
        source = "${pkgs.nixos-scripts}/bin/rog-poweroff-hook";
      };
    systemd.shutdownRamfs.storePaths = lib.mkIf cfg.s5Write.enable [
      "${pkgs.nixos-scripts}/bin"
    ];

    # Stage 3 (efiFallback): DMI-scoped out-of-tree kernel module that
    # registers a SYS_OFF_MODE_POWER_OFF handler at SYS_OFF_PRIO_FIRMWARE+1
    # (225), the same priority mainline's efi/reboot.c uses. It REPLACES the
    # final ACPI S5 entry (acpi_power_off, priority 224 — the step that
    # freezes this firmware, proven by the Gate 2 trial 2026-09-10) while
    # the kernel's own acpi_power_off_prepare (POWER_OFF_PREPARE) still runs
    # first, preserving _PTS/_GTS notification and wake-GPE disarming (T14
    # Gen 5 RFC v3 lesson). Gate 3 requires s5Write DISABLED: the ramfs hook
    # write freezes the box before the kernel's EFI handler could ever run.
    boot.extraModulePackages = lib.mkIf cfg.efiFallback.enable [
      (pkgs.callPackage ../../../pkgs/rog-efi-poweroff {
        kernel = config.boot.kernelPackages.kernel;
      })
    ];
  };
}
