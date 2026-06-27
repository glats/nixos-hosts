{ config
, lib
, pkgs
, ...
}:

let
  rog-shutdown-script = pkgs.writeShellScript "rog-shutdown" ''
    sync
    echo '\_SI._SST' > /proc/acpi/call 2>/dev/null || true
  '';
in
{
  systemd.services.rog-shutdown = {
    description = "ROG ACPI S5 poweroff fallback";
    enable = true;
    # `wantedBy` pulls the service as a soft dependency — if it fails
    # the shutdown still proceeds. Previously `before=[poweroff.target]`
    # raced with unmounts; now we let systemd order it naturally late
    # in the shutdown sequence without a hard constraint.
    wantedBy = [
      "poweroff.target"
      "reboot.target"
      "halt.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = rog-shutdown-script;
      # S5 must not stall the shutdown. The script is a single sync +
      # echo; 10s is a generous upper bound.
      TimeoutStartSec = 0;
      TimeoutStopSec = "10s";
    };
  };
}
