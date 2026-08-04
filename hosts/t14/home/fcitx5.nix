{ config
, pkgs
, lib
, ...
}:

{
  # fcitx5 IME — accented characters (dead keys, backtick) and
  # multi-layout switching. The omarchy-nix module provides packages,
  # env vars, config, and autostart; we just opt in.
  # lib.mkForce required: the osConfig sync in
  # omarchy-nix.homeManagerModules.default copies NixOS-level omarchy.*
  # into HM at the same priority as user-defined options, which would
  # conflict with the submodule's `enable = false` default when
  # osConfig.omarchy doesn't carry fcitx5 itself. mkForce wins the
  # priority tug-of-war. Same pattern as omarchy.rotate_on_start above.
  omarchy.fcitx5.enable = lib.mkForce true;

  # Fcitx5: pass --disable notificationitem to remove the tray icon
  # from Waybar while keeping IME functional for accented characters.
  systemd.user.services.fcitx5.Service.ExecStart =
    lib.mkForce "${pkgs.fcitx5}/bin/fcitx5 --disable notificationitem";

  # Override fcitx5's XDG autostart .desktop so systemd-xdg-autostart-generator
  # skips it. The package ships org.fcitx.Fcitx5.desktop that starts fcitx5
  # WITHOUT --disable notificationitem, which races with our custom service
  # and prevents it from binding DBUS. X-systemd-skip=true tells the generator
  # to ignore this entry entirely, leaving startup to our fcitx5.service.
  xdg.configFile."autostart/org.fcitx.Fcitx5.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Fcitx 5
    Exec=fcitx5 --disable notificationitem
    Terminal=false
    NoDisplay=true
    X-systemd-skip=true
  '';

  # Strip fcitx5 profile to a single layout (es) and disable its trigger
  # so it doesn't try to manage keyboard layouts — Hyprland + kb-toggle.sh
  # handle that. fcitx5 stays running as an IME bridge for apps that need
  # it (acentos, XCompose) but won't intercept Ctrl+Space or show popups.
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
