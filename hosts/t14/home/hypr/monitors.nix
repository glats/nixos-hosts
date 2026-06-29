# T14 Hyprland monitor configuration.
# eDP-1 enable/disable driven by hyprlang conditionals + persisted settings.conf
# instead of exec-once + sleep, so monitor state is correct at config parse time.
{ lib, ... }:

let
  # Workspace distribution across external monitors (cyclic mod 3):
  #   AOC 24P1W1  (DP-5): 1, 4, 7, 10, 13, 16, 19
  #   Lenovo G24-10 (DP-4): 2, 5, 8, 11, 14, 17, 20
  #   AOC 2470W   (DP-3): 3, 6, 9, 12, 15, 18
  maxWorkspace = 20;
  genSeq =
    start: step: limit:
    builtins.filter (w: w <= limit) (builtins.genList (k: start + k * step) (limit / step + 1));

  mkWorkspaceRules = lib.flatten (
    lib.mapAttrsToList
      (monitor: workspaces: map (w: "${toString w}, monitor:desc:${monitor}") workspaces)
      {
        "AOC 24P1W1 OTNQ4HA000101" = genSeq 1 3 maxWorkspace;
        "Lenovo Group Limited LEN G24-10 U5B4GWF1" = genSeq 2 3 maxWorkspace;
        "AOC 2470W GGZM3HA438259" = genSeq 3 3 maxWorkspace;
      }
  );
in

{
  wayland.windowManager.hyprland.settings = {
    # Workspace → monitor bindings (cyclic distribution).
    # eDP-1 has no fixed workspaces — when only the laptop panel is
    # active, workspaces land there by default.
    workspace = mkWorkspaceRules;

    # Explicit GDK_SCALE=1 to prevent GTK apps from using default scaling.
    # The T14 panel is 1920x1080 @ 1x — no HiDPI scaling needed.
    env = [ "GDK_SCALE,1" ];
  };

  wayland.windowManager.hyprland.extraConfig = ''
    # Persisted lid state — updated by lid-switch bindings and startup
    # validator.  Read at config parse time so eDP-1 starts disabled
    # when the lid was closed at last logout.
    source = /home/glats/.config/hypr/settings.conf

    # Conditional eDP-1: enabled when lid open, disabled when closed
    # (e.g. docked with externals).  The startup validator below fixes
    # state mismatches (lid changed between sessions).
    # hyprlang if ENABLE_LAPTOP
    monitor = eDP-1, preferred, 4920x420, 1
    # hyprlang endif

    # hyprlang if !ENABLE_LAPTOP
    monitor = eDP-1, disable
    # hyprlang endif

    # External monitors positioned below eDP-1 (laptop panel at y=0..1080)
    # hyprlang if ENABLE_LAPTOP
    monitor = desc:AOC 24P1W1 OTNQ4HA000101,1920x1080@60,0x420,1,transform,1
    monitor = desc:Lenovo Group Limited LEN G24-10 U5B4GWF1,1920x1080@60,1080x420,1
    monitor = desc:AOC 2470W GGZM3HA438259,1920x1080@60,3000x420,1
    # hyprlang endif

    # External monitors at y=0 (eDP-1 disabled — docked, lid closed)
    # hyprlang if !ENABLE_LAPTOP
    monitor = desc:AOC 24P1W1 OTNQ4HA000101,1920x1080@60,0x0,1,transform,1
    monitor = desc:Lenovo Group Limited LEN G24-10 U5B4GWF1,1920x1080@60,1080x0,1
    monitor = desc:AOC 2470W GGZM3HA438259,1920x1080@60,3000x0,1
    # hyprlang endif

    # Lid close — persist + runtime disable eDP-1, move externals to y=0.
    # Hyprland emits "switch:on:Lid Switch" (capital L) — regex must match.
    bindl = , switch:on:.*[Ll]id.*, exec, printf '$ENABLE_LAPTOP = 0\n' > $HOME/.config/hypr/settings.conf && hyprctl keyword monitor "eDP-1,disable" && hyprctl keyword monitor "desc:AOC 24P1W1 OTNQ4HA000101,1920x1080@60,0x0,1,transform,1" && hyprctl keyword monitor "desc:Lenovo Group Limited LEN G24-10 U5B4GWF1,1920x1080@60,1080x0,1" && hyprctl keyword monitor "desc:AOC 2470W GGZM3HA438259,1920x1080@60,3000x0,1"
    # Lid open — persist + runtime enable eDP-1, move externals to y=420.
    bindl = , switch:off:.*[Ll]id.*, exec, printf '$ENABLE_LAPTOP = 1\n' > $HOME/.config/hypr/settings.conf && hyprctl keyword monitor "eDP-1,preferred,4920x420,1" && hyprctl keyword monitor "desc:AOC 24P1W1 OTNQ4HA000101,1920x1080@60,0x420,1,transform,1" && hyprctl keyword monitor "desc:Lenovo Group Limited LEN G24-10 U5B4GWF1,1920x1080@60,1080x420,1" && hyprctl keyword monitor "desc:AOC 2470W GGZM3HA438259,1920x1080@60,3000x420,1"

    # Startup state validator — catches lid-state mismatches from
    # previous session.  udevadm settle (injected via systemd drop-in)
    # ensures DRM devices are ready before Hyprland starts.
    exec-once = bash -c 's=$(grep -o "[01]" $HOME/.config/hypr/settings.conf 2>/dev/null); grep -q closed /proc/acpi/button/lid/LID*/state 2>/dev/null && l=0 || l=1; omarchy-hw-external-monitors && e=1 || e=0; if [ "$e" = 0 ]; then [ "$s" != 1 ] && echo "\$ENABLE_LAPTOP = 1" > "$HOME/.config/hypr/settings.conf" && hyprctl keyword monitor "eDP-1,preferred,4920x420,1" && hyprctl keyword monitor "desc:AOC 24P1W1 OTNQ4HA000101,1920x1080@60,0x420,1,transform,1" && hyprctl keyword monitor "desc:Lenovo Group Limited LEN G24-10 U5B4GWF1,1920x1080@60,1080x420,1" && hyprctl keyword monitor "desc:AOC 2470W GGZM3HA438259,1920x1080@60,3000x420,1"; elif [ "$l" = 1 ]; then [ "$s" != 1 ] && echo "\$ENABLE_LAPTOP = 1" > "$HOME/.config/hypr/settings.conf" && hyprctl keyword monitor "eDP-1,preferred,4920x420,1" && hyprctl keyword monitor "desc:AOC 24P1W1 OTNQ4HA000101,1920x1080@60,0x420,1,transform,1" && hyprctl keyword monitor "desc:Lenovo Group Limited LEN G24-10 U5B4GWF1,1920x1080@60,1080x420,1" && hyprctl keyword monitor "desc:AOC 2470W GGZM3HA438259,1920x1080@60,3000x420,1"; else [ "$s" != 0 ] && echo "\$ENABLE_LAPTOP = 0" > "$HOME/.config/hypr/settings.conf" && hyprctl keyword monitor "eDP-1,disable" && hyprctl keyword monitor "desc:AOC 24P1W1 OTNQ4HA000101,1920x1080@60,0x0,1,transform,1" && hyprctl keyword monitor "desc:Lenovo Group Limited LEN G24-10 U5B4GWF1,1920x1080@60,1080x0,1" && hyprctl keyword monitor "desc:AOC 2470W GGZM3HA438259,1920x1080@60,3000x0,1"; fi'
  '';
}
