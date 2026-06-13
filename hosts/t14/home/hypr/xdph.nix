# T14 xdg-desktop-portal-hyprland configuration.
#
# This module replaces the upstream omarchy xdph.conf with the same
# content (the upstream already ships these exact values, but t14
# declares them explicitly as a t14 delta so the configuration is
# self-documented in the t14 tree).
#
# The screencopy block is the source for xdg-desktop-portal-hyprland's
# screen-share picker.  Two key settings:
#   - allow_token_by_default = true
#       Allow any window to request a screencopy token without an
#       explicit user click on the picker UI.  This is convenient for
#       the user's screenshot/screenrecord workflow.
#   - custom_picker_binary = hyprland-preview-share-picker
#       Use omarchy's preview-share-picker (which shows a thumbnail
#       of the selected region) instead of the default Hyprland
#       picker.
#
# The settings are written as a standalone xdph.conf file (matching
# the upstream approach).  The file is sourced by xdg-desktop-portal
# at startup, not by hyprland.conf.
{ ... }:

{
  xdg.configFile."hypr/xdph.conf".text = ''
    screencopy {
        allow_token_by_default = true
        custom_picker_binary = hyprland-preview-share-picker
    }
  '';
}
