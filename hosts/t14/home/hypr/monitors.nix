# T14 Hyprland monitor configuration.
# Primary display: built-in 14" 1920x1080 panel.
# External monitors are hot-plugged via monitor-hotplug-handler.sh.
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
    # T14 built-in display — 1920x1080 @ 60Hz
    # This is the laptop panel that should always be active.
    # External monitors added with desc: matching for stable identification
    # across reconnects (connector names like DP-3/DP-4/DP-5 shift on hot-plug).
    # y=420 centra los landscape (1080px alto) verticalmente con DP-5
    # (rotado, 1920px alto post-rotación) para evitar dead zone del cursor.
    monitor = lib.mkForce [
      "eDP-1,preferred,4920x420,1"
      "desc:AOC 24P1W1 OTNQ4HA000101,1920x1080@60,0x0,1,transform,1"
      "desc:Lenovo Group Limited LEN G24-10 U5B4GWF1,1920x1080@60,1080x420,1"
      "desc:AOC 2470W GGZM3HA438259,1920x1080@60,3000x420,1"
    ];

    # Workspace → monitor bindings (cyclic distribution).
    # eDP-1 (laptop) has no fixed workspaces — when no external monitors
    # are connected the lid-switch handler keeps eDP-1 active and workspace
    # 1 lands there by default (only one monitor active).
    workspace = mkWorkspaceRules;

    # Explicit GDK_SCALE=1 to prevent GTK apps from using default scaling.
    # The T14 panel is 1920x1080 @ 1x — no HiDPI scaling needed.
    # This list merges with looknfeel.nix's env via Nix attrset union.
    env = [ "GDK_SCALE,1" ];
  };

  wayland.windowManager.hyprland.extraConfig = ''
    exec-once = bash -c 'sleep 2 && if grep -q closed /proc/acpi/button/lid/LID*/state 2>/dev/null && omarchy-hw-external-monitors; then echo "monitor=eDP-1,disable" > "$HOME/.local/state/omarchy/toggles/hypr/internal-monitor-disable.conf" && hyprctl keyword monitor "eDP-1, disable"; fi'
  '';
}
