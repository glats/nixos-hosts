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
#                            NOTE: cursor:no_hardware_cursors lives at the
#                            TOP level of hyprland.settings (alongside
#                            general, decoration, etc.), NOT under input.
#                            In 0.54, putting it under input produces the
#                            config error "input cursor no hardware
#                            cursors does not exist".
# gesture = 3, horizontal, workspace — Hyprland 0.51+ removed the old
#                            gestures:workspace_swipe* family in favour of
#                            the new 1:1 gesture syntax.  The old keys
#                            cause "gestures workspace_swipe doesn't
#                            exist" at config parse time.
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

      # Touchpad: natural scroll (modern feel), tap-to-click, etc.
      # Omarchy also sets these as mkDefault; we re-assert them with
      # mkDefault to stay explicit about T14's choices.
      touchpad = {
        natural_scroll = true;
        disable_while_typing = true;
        middle_button_emulation = true;
        tap-to-click = true;
        scroll_factor = 0.4;
      };

      # Repeat / delay / sensitivity tuned for the laptop keyboard.
      repeat_rate = 40;
      repeat_delay = 600;
      follow_mouse = 1;
      sensitivity = 0;
      numlock_by_default = true;
      accel_profile = "flat";
    };

    # cursor block is at the top level of hyprland.settings (not under
    # input).  Omarchy's looknfeel.nix already sets hide_on_key_press and
    # warp_on_change_workspace here; Nix attribute union merges both
    # blocks so we only add no_hardware_cursors.
    cursor = {
      no_hardware_cursors = true;
    };

    # Gestures: Hyprland 0.51+ replaced the old gestures:workspace_swipe*
    # family with a 1:1 gesture syntax.  The old keys do not exist in
    # 0.54.x and cause a config parse error.  The equivalent of
    # "3-finger horizontal workspace swipe" is the single line below;
    # the old workspace_swipe_distance / workspace_swipe_invert knobs
    # have no direct equivalent and are intentionally dropped.
    gesture = "3, horizontal, workspace";

    # Window rules: per-window overrides.
    # NOTE: Hyprland 0.53+ renamed `windowrulev2` to `windowrule` and
    # replaced the bare `class:foo` / `title:foo` selectors with
    # `match:class foo` / `match:title foo` (the `match:` prefix
    # disambiguates rule rules from actions).  Using the old
    # `windowrulev2 = ...` form triggers a deprecation warning at
    # Hyprland startup ("windowrulev2 is deprecated, correct syntax
    # can be found in the wiki").  See
    # https://wiki.hyprland.org/0.54.0/Configuring/Window-Rules/
    windowrule = [
      # Float picker dialogs (e.g., color picker, file dialogs).
      "match:class ^(xdg-desktop-portal-gtk)$, float on"
      # Workspace 7 (special) gets a no-anim override for fullscreen games.
      "match:class ^(steam_app_), workspace 7 silent"
      # Scroll nicely in the terminal — matches the upstream omarchy
      # bindings.  Alacritty/kitty/foot use a faster scroll factor
      # (1.5); ghostty uses a slower factor (0.2) to keep the t14
      # touchpad feel close to other terminals.
      "match:class (Alacritty|kitty|foot), scroll_touchpad 1.5"
      "match:class com.mitchellh.ghostty, scroll_touchpad 0.2"
      # Full opacity for all windows by default; terminals with
      # explicit transparency in their own config still apply.
      "opacity 1.0 1.0, match:tag default-opacity"
    ];
  };
}
