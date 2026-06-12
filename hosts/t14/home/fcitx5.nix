# T14 fcitx5 IME overlay.
#
# fcitx5 is a Next-Generation Chinese/Asian input method framework.
# The t14 configures it for Spanish (es) + LatAm (latam) + an English
# (us) fallback so that switching with Ctrl+Space gives all three
# layouts in the panel.
#
# REQ-006 / T3-003: port fcitx5 IME config to t14/home.  The actual
# fcitx5 package is brought in by the omarchy HM module
# (omarchy's environment.systemPackages includes fcitx5 via its
# packages.nix).  This module wires the user-level addons and
# environment variables.
{ ... }:

{
  # The IME environment variables are set at the session level so
  # GTK and Qt apps pick up fcitx5 as the input method backend.
  # Wayland-native apps (which most omarchy apps are) get fcitx5
  # automatically once GTK_IM_MODULE / QT_IM_MODULE are set.
  home.sessionVariables = {
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    XMODIFIERS = "@im=fcitx";
  };

  # fcitx5 config file — pin the available input methods and the
  # default layout.  Deployed to ~/.config/fcitx5/profile.
  xdg.configFile."fcitx5/profile".text = ''
    [Groups/0]
    Name=Default
    Default Layout=es
    DefaultIM=keyboard-es

    [Groups/0/Items/0]
    Name=keyboard-es
    Layout=es

    [Groups/0/Items/1]
    Name=keyboard-latam
    Layout=latam

    [Groups/0/Items/2]
    Name=keyboard-us
    Layout=us

    [GroupOrder]
    0=Default
  '';

  # Configure the fcitx5 addons to use Wayland portals where possible.
  xdg.configFile."fcitx5/config".text = ''
    [Behavior]
    TriggerWhenFocus=True
    ShowInputMethodInformation=True
  '';
}
