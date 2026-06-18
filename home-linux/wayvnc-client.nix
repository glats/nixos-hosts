# wayvnc client launcher — connect to t14 from rog.
#
# Deploys a .desktop launcher to the app menu that opens Remmina
# with a one-shot VNC connection to t14:5900.
# Remmina itself is provided by modules/base/profiles/base.nix.
{ ... }:

{
  home.file = {
    # Desktop launcher — visible in the app menu
    ".local/share/applications/wayvnc-t14.desktop" = {
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
  };
}
