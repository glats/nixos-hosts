# Remote desktop client launchers — unified module for all remote connections.
#
# Deploys .desktop launchers to the app menu that open Remmina
# with one-shot connections (no .remmina file persistence).
# Remmina itself is provided by modules/base/profiles/base.nix.
{ ... }:

{
  home.file = {
    # === wayvnc connection (t14) ===
    ".local/share/applications/remote-t14.desktop" = {
      text = ''
        [Desktop Entry]
        Type=Application
        Name=t14 (wayvnc)
        Comment=VNC connection to t14 via wayvnc
        Exec=remmina -c vnc://172.16.0.109:5900
        Icon=remmina
        Categories=Network;RemoteAccess;
        Terminal=false
        StartupWMClass=remmina
      '';
    };

    # === RDP / VNC connections (Remmina one-shot URLs) ===
    ".local/share/applications/remote-mact2.desktop" = {
      text = ''
        [Desktop Entry]
        Type=Application
        Name=mact2
        Comment=VNC connection to mact2.local
        Exec=remmina -c vnc://mact2.local
        Icon=remmina
        Categories=Network;RemoteAccess;
        Terminal=false
        StartupWMClass=remmina
      '';
    };

    ".local/share/applications/remote-oneplus5.desktop" = {
      text = ''
        [Desktop Entry]
        Type=Application
        Name=oneplus5
        Comment=RDP connection to 172.16.0.12
        Exec=remmina -c rdp://172.16.0.12
        Icon=remmina
        Categories=Network;RemoteAccess;
        Terminal=false
        StartupWMClass=remmina
      '';
    };

    ".local/share/applications/remote-rog.desktop" = {
      text = ''
        [Desktop Entry]
        Type=Application
        Name=rog
        Comment=RDP connection to 172.16.0.5
        Exec=remmina -c rdp://172.16.0.5
        Icon=remmina
        Categories=Network;RemoteAccess;
        Terminal=false
        StartupWMClass=remmina
      '';
    };

    ".local/share/applications/remote-thinkcentre.desktop" = {
      text = ''
        [Desktop Entry]
        Type=Application
        Name=thinkcentre
        Comment=RDP connection to 172.16.0.11
        Exec=remmina -c rdp://172.16.0.11
        Icon=remmina
        Categories=Network;RemoteAccess;
        Terminal=false
        StartupWMClass=remmina
      '';
    };
  };
}
