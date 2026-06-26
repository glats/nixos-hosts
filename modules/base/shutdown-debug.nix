{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.shutdownDebug;

  capture-script = pkgs.writeShellScript "shutdown-debug-capture" ''
    set +e

    BOOT_ID=$(tr -d '\n' < /proc/sys/kernel/random/boot_id)
    OUT_DIR="/var/log/shutdown-debug/$BOOT_ID"
    mkdir -p "$OUT_DIR"
    cd "$OUT_DIR" || exit 0

    # All commands are best-effort. Each MUST use `|| true` so a single
    # hung or missing tool cannot block the shutdown sequence.
    journalctl -b -o short-precise > journal.log 2>&1 || true
    dmesg -T                            > dmesg.log    2>&1 || true
    ${pkgs.psmisc}/bin/pstree -ap       > pstree.log   2>&1 || true
    ps auxf                             > ps.log       2>&1 || true
    lsmod                               > lsmod.log    2>&1 || true
    mount                               > mount.log    2>&1 || true
    df -h                               > df.log       2>&1 || true
    ${pkgs.lsof}/bin/lsof +L1           > lsof-deleted.log 2>&1 || true
    cat /proc/cmdline                   > cmdline.log  2>&1 || true
    cat /proc/acpi/wakeup               > acpi-wakeup.log 2>&1 || true
    ${pkgs.lm_sensors}/bin/sensors       > sensors.log  2>&1 || true

    # Optional: nvidia-smi only present on hosts with the proprietary driver
    if [ -x /run/current-system/sw/bin/nvidia-smi ]; then
      nvidia-smi > nvidia-smi.log 2>&1 || true
    fi

    # Self-clean: keep last 7 days of diagnostic dirs
    find /var/log/shutdown-debug -mindepth 1 -maxdepth 1 \
      -type d -mtime +7 -exec rm -rf {} \; 2>/dev/null || true

    # Flush all writes to disk so they survive a hard poweroff
    sync
  '';
in
{
  options.my.shutdownDebug = {
    enable = lib.mkEnableOption "" // {
      default = false;
      description = ''
        Capture diagnostic state (journal, dmesg, ps, mounts, etc.) to
        `/var/log/shutdown-debug/{boot-id}/` before poweroff/reboot/halt.
        Intended for hosts that experience shutdown hangs and need
        post-mortem evidence.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # `lsof` is not in every minimal profile, so we ship it explicitly.
    environment.systemPackages = [ pkgs.lsof ];

    systemd.services.shutdown-debug-capture = {
      description = "Capture diagnostic state to /var/log/shutdown-debug before shutdown";
      # DefaultDependencies is a systemd unit setting, not a NixOS service
      # option — it lives in unitConfig. We disable it so the service is
      # NOT auto-pulled into the shutdown graph with all the other
      # implicit ordering; we control the graph explicitly below.
      unitConfig.DefaultDependencies = false;
      # `shutdown.target` is the umbrella for all three exit targets
      # (poweroff, reboot, halt). We want to run as the system is
      # winding down, before the actual switch to systemd-shutdown.
      after = [
        "local-fs.target"
        "systemd-journald.service"
        "shutdown.target"
      ];
      before = [ "shutdown.target" ];
      wantedBy = [ "shutdown.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # Capture must not stall the shutdown. Both bounds are intentional.
        TimeoutStartSec = 0;
        TimeoutStopSec = "10s";
        ExecStart = capture-script;
      };
    };
  };
}
