{ lib, ... }:

{
  # Shutdown race-condition fix
  #
  # Symptom observed on rog: after `systemctl poweroff`, the system reached
  # shutdown.target and began a reboot (hardware watchdog armed), but logs
  # showed "watchdog: watchdog0: watchdog did not stop!" and the machine
  # failed to finish powering off.
  #
  # Root cause: the hardware watchdog (intel_oc_wdt) was armed by systemd
  # with the default ShutdownWatchdogSec=10min. If systemd-shutdown stalls
  # for any reason — killing lingering processes, unmounting filesystems,
  # releasing devices — the watchdog fires a hardware reset instead of the
  # clean ACPI S5 poweroff, producing the "did not stop" log and a
  # non-graceful shutdown.
  #
  # Fix: disable the hardware watchdog during shutdown. We keep the runtime
  # watchdog disabled too (RuntimeWatchdogSec=0) since this is a laptop,
  # not a server that benefits from self-reset on hang.
  #
  # See systemd-system.conf(5): RuntimeWatchdogSec, ShutdownWatchdogSec.
  systemd.settings.Manager = {
    RuntimeWatchdogSec = "0";
    ShutdownWatchdogSec = "0";
  };

  # Reduce shutdown stall tolerance. Default systemd TimeoutStopSec is 90s;
  # on this host that means every service that refuses SIGTERM stretches
  # shutdown by 1m30s. 20s is still generous for clean termination.
  systemd.settings.Manager.DefaultTimeoutStopSec = lib.mkDefault "20s";
}
