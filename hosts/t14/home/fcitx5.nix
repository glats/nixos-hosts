{
  config,
  pkgs,
  lib,
  ...
}:

{
  omarchy.fcitx5.enable = lib.mkForce true;

  systemd.user.services.fcitx5.Service.ExecStart =
    lib.mkForce "${pkgs.fcitx5}/bin/fcitx5 --disable notificationitem";

  xdg.configFile."autostart/org.fcitx.Fcitx5.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Fcitx 5
    Exec=fcitx5 --disable notificationitem
    Terminal=false
    NoDisplay=true
    X-systemd-skip=true
  '';

  xdg.configFile."fcitx5/profile" = lib.mkForce {
    text = ''
      [Groups/0]
      Name=Default
      Default Layout=es
      DefaultIM=keyboard-es

      [Groups/0/Items/0]
      Name=keyboard-es
      Layout=es

      [GroupOrder]
      0=Default
    '';
  };

  xdg.configFile."fcitx5/config" = lib.mkForce {
    text = ''
      [Behavior]
      TriggerWhenFocus=False
      ShowInputMethodInformation=False

      [Hotkey]
      TriggerKeys=
    '';
  };
}
