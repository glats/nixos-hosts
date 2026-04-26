{ config, pkgs, lib, ... }:

{
  # System-wide XFCE defaults for all users and monitors
  # This provides the fallback xfconf values for xfce4-desktop
  # so any new monitor (including XRDP sessions) gets solid black background
  environment.etc."xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml" = {
    text = ''
      <?xml version="1.1" encoding="UTF-8"?>

      <channel name="xfce4-desktop" version="1.0">
        <property name="desktop-icons" type="empty">
          <property name="style" type="int" value="0"/>
        </property>
        <property name="backdrop" type="empty">
          <property name="screen0" type="empty">
            <property name="monitor0" type="empty">
              <property name="workspace0" type="empty">
                <property name="color-style" type="int" value="0"/>
                <property name="image-style" type="int" value="0"/>
                <property name="last-image" type="string" value=""/>
                <property name="rgba1" type="string" value="rgba(0,0,0,1.0)"/>
              </property>
            </property>
          </property>
        </property>
      </channel>
    '';
  };
}
