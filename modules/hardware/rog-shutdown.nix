{ config, lib, pkgs, ... }:

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
    wantedBy = [ "poweroff.target" ];
    before = [ "poweroff.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = rog-shutdown-script;
    };
  };
}
