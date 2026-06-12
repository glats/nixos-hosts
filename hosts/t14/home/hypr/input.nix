# T14 Hyprland input configuration.
#
# Tuned for the ThinkPad T14 AMD Gen 4 keyboard / touchpad / gestures.
#
# NOTE: omarchy's hyprland/input.nix sets kb_layout = "us" via lib.mkDefault
# in its HM module.  T14 uses es+latam (Chile), so we must use lib.mkForce
# here to override.
#
# repeat_delay = 600 ms   — long enough that arrow-key navigation does not
#                            fire autorepeat when the key is briefly tapped.
# scroll_factor = 0.4     — slower scroll than omarchy default (1.0) for
#                            the touchpad.  Matches pre-migration feel.
# natural_scroll = true   — invert scroll direction (modern macOS/Windows
#                            convention; ThinkPad users expect it).
# cursor.no_hardware_cursors = true — software cursor so the OS pointer
#                            shows in screenshots / recordings.
# workspace_swipe = on    — trackpad gestures for workspace switching.
# follow_mouse = 1        — focus follows mouse pointer (lazy).
{ lib, ... }:

{
  wayland.windowManager.hyprland.settings = {
    input = {
      # Keyboard: es (Spain) primary, latam (Latin America) as secondary;
      # Alt+Shift toggles between them.  Caps acts as Compose for accents.
      # mkForce required because omarchy's input.nix also sets kb_layout.
      kb_layout = lib.mkForce "es,latam";
      kb_options = lib.mkForce "grp:alt_shift_toggle,compose:caps";

      # Touchpad: natural scroll (modern feel), no hardware cursors
      # (so screenshots show the pointer), tap-to-click already handled
      # by omarchy's touchpad module.
      touchpad = {
        natural_scroll = true;
        disable_while_typing = true;
        middle_button_emulation = true;
        tap-to-click = true;
      };

      # Pointer: software cursor (visible in screenshots, recording tools,
      # and screen-sharing).  Omarchy's default is hardware cursors.
      cursor = {
        no_hardware_cursors = true;
      };

      # Gestures: enable trackpad swipe gestures for workspace switching.
      gestures = {
        workspace_swipe = true;
        workspace_swipe_fingers = 3;
        workspace_swipe_distance = 300;
        workspace_swipe_invert = true;
      };

      # Window rules: per-window input overrides.
      windowrulev2 = [
        # Float picker dialogs (e.g., color picker, file dialogs).
        "float, class:^(xdg-desktop-portal-gtk)$"
        # Workspace 7 (special) gets a no-anim override for fullscreen games.
        "workspace 7 silent, class:^(steam_app_)"
      ];

      # Repeat / delay / sensitivity tuned for the laptop keyboard.
      repeat_rate = 40;
      repeat_delay = 600;
      follow_mouse = 1;
      sensitivity = 0;
      numlock_by_default = true;
      accel_profile = "flat";
    };
  };
}
