# VNC client launchers — connect to remote VNC servers from this host.
#
# Deploys user-facing scripts under ~/.local/bin/ that wrap Remmina
# one-shot connections (no .remmina file persistence, no UI prompts).
# Remmina itself is provided by modules/base/profiles/base.nix so no
# extra `home.packages` entry is needed here.
#
# Usage from the host's shell:
#   connect-wayvnc-t14
#
# Currently deployed:
#   * connect-wayvnc-t14 — VNC viewer for the t14 wayvnc server
#                          (binds 0.0.0.0:5900, PAM auth).
#
# The server side lives in hosts/t14/home/wayvnc/.
{ pkgs, ... }:
{
  home.file.".local/bin/connect-wayvnc-t14" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      # Connect to wayvnc on t14 (port 5900, PAM auth).
      # Server is enabled via programs.wayvnc on t14; PAM uses the
      # unix password of the glats account on t14.
      # NOTE: t14 resolves to 127.0.0.2 in /etc/hosts, so we use the
      #       direct IP 172.16.0.109 instead of hostname.
      exec ${pkgs.remmina}/bin/remmina -c vnc://172.16.0.109:5900
    '';
  };

  # Desktop entry for the application menu
  xdg.desktopEntries.connect-wayvnc-t14 = {
    name = "Connect to t14 (VNC)";
    comment = "Remote desktop to t14 via wayvnc";
    exec = "connect-wayvnc-t14";
    icon = "remmina";
    categories = [
      "Network"
      "RemoteAccess"
    ];
    terminal = false;
  };
}
