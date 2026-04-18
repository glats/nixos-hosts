{ ... }:

let
  iconName = "chrome-lodlkdfmihgonocnmddehnfgiljnadcf-Default.png";
  iconDir = ./chrome-app-icons;
  chromePath = "/run/current-system/sw/bin/google-chrome-stable";
in

{
  xdg.dataFile = {
    "applications/chrome-lodlkdfmihgonocnmddehnfgiljnadcf-Default.desktop".text = ''
      [Desktop Entry]
      Version=1.0
      Terminal=false
      Type=Application
      Name=X
      Comment=Social media platform
      Exec=${chromePath} --profile-directory=Default --app-id=lodlkdfmihgonocnmddehnfgiljnadcf
      Icon=chrome-lodlkdfmihgonocnmddehnfgiljnadcf-Default
      StartupWMClass=crx_lodlkdfmihgonocnmddehnfgiljnadcf
      Actions=Direct-Messages;Explore;New-post;Notifications

      [Desktop Action Direct-Messages]
      Name=Direct Messages
      Exec=${chromePath} --profile-directory=Default --app-id=lodlkdfmihgonocnmddehnfgiljnadcf "--app-launch-url-for-shortcuts-menu-item=https://x.com/messages?utm_source=jumplist&utm_medium=shortcut"

      [Desktop Action Explore]
      Name=Explore
      Exec=${chromePath} --profile-directory=Default --app-id=lodlkdfmihgonocnmddehnfgiljnadcf "--app-launch-url-for-shortcuts-menu-item=https://x.com/explore?utm_source=jumplist&utm_medium=shortcut"

      [Desktop Action New-post]
      Name=New post
      Exec=${chromePath} --profile-directory=Default --app-id=lodlkdfmihgonocnmddehnfgiljnadcf "--app-launch-url-for-shortcuts-menu-item=https://x.com/compose/post?utm_source=jumplist&utm_medium=shortcut"

      [Desktop Action Notifications]
      Name=Notifications
      Exec=${chromePath} --profile-directory=Default --app-id=lodlkdfmihgonocnmddehnfgiljnadcf "--app-launch-url-for-shortcuts-menu-item=https://x.com/notifications?utm_source=jumplist&utm_medium=shortcut"
    '';

    "applications/poweroff.desktop".text = ''
      [Desktop Entry]
      Version=1.0
      Terminal=false
      Type=Application
      Name=Power Off
      Comment=Shut down the system
      Exec=systemctl poweroff
      Icon=system-shutdown
    '';

    "applications/reboot.desktop".text = ''
      [Desktop Entry]
      Version=1.0
      Terminal=false
      Type=Application
      Name=Reboot
      Comment=Restart the system
      Exec=systemctl reboot
      Icon=system-reboot
    '';

    "icons/hicolor/512x512/apps/${iconName}".source = iconDir + "/${iconName}";
    "icons/hicolor/256x256/apps/${iconName}".source = iconDir + "/${iconName}";
    "icons/hicolor/128x128/apps/${iconName}".source = iconDir + "/${iconName}";
    "icons/hicolor/48x48/apps/${iconName}".source = iconDir + "/${iconName}";
    "icons/hicolor/32x32/apps/${iconName}".source = iconDir + "/${iconName}";
  };
}
