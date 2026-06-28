# T14-specific Home Manager overlays on top of omarchy-nix.
# Omarchy's theme runtime owns the visual layer (waybar theme, mako theme,
# ghostty theme).  This module adds only the non-visual delta:
#   - Hyprland t14-specific config fragments (monitor, input, bindings, looknfeel)
#   - Helper scripts (kb-toggle, kb-layout)
#   - Ghostty + kitty settings (imported directly from home-linux/ because
#     t14's curated import list omits home-linux/shared-modules.nix)
#   - iwd-wifi waybar indicator script (iwd-specific, not in omarchy)
#   - mouse-wiggle launcher
{ ... }:

{
  imports = [
    ./hypr/monitors.nix
    ./hypr/input.nix
    ./hypr/bindings.nix
    ./hypr/looknfeel.nix
    ./hypr/hyprlock.nix
    ./hypr/hyprsunset.nix
    ../../../home-linux/ghostty.nix
    ../../../home-linux/kitty.nix
    ./mouse-wiggle.nix
  ];

  # ------------------------------------------------------------------
  # Helper scripts (accessible from PATH via omarchy's bin directory)
  # ------------------------------------------------------------------
  home.file = {
    # Keyboard layout toggle (es <-> latam)
    ".local/share/omarchy/bin/kb-toggle.sh" = {
      source = ./scripts/kb-toggle.sh;
      executable = true;
    };

    # Keyboard layout set (es or latam)
    ".local/share/omarchy/bin/kb-layout.sh" = {
      source = ./scripts/kb-layout.sh;
      executable = true;
    };

    # ------------------------------------------------------------------
    # kb-layout.sh / kb-toggle.sh — the symlink copies into
    # ~/.config/hypr/ are kept for any waybar module / hyprland plugin
    # that resolves helper scripts at that path.  The canonical
    # source lives in scripts/; the bin copies above expose them on
    # PATH.  Both paths point to the same source file (no duplicate
    # content).
    # ------------------------------------------------------------------
    ".config/hypr/kb-layout.sh" = {
      source = ./scripts/kb-layout.sh;
      executable = true;
    };
    ".config/hypr/kb-toggle.sh" = {
      source = ./scripts/kb-toggle.sh;
      executable = true;
    };
  };

  # ------------------------------------------------------------------
  # Waybar — iwd WiFi status indicator
  # ------------------------------------------------------------------
  # omarchy-nix owns the waybar config via home.file (recursive dir
  # copy of config/waybar/). We add only the iwd-wifi indicator
  # script (iwd-specific, not in upstream). The script deploys but is
  # not yet referenced by upstream's waybar modules-right
  # (follow-up: patch upstream waybar config to include
  # custom/iwd-wifi).
  home.file.".config/waybar/indicators/iwd-wifi.sh" = {
    text = ''
      #!/bin/bash
      # waybar custom module: iwd WiFi status
      state=$(iwctl station wlan0 show 2>/dev/null | awk '/State/ {print $2}')
      ssid=$(iwctl station wlan0 show 2>/dev/null | awk '/Connected network/ {$1=""; $2=""; print}' | xargs)
      if [ "$state" = "connected" ] && [ -n "$ssid" ]; then
        echo "{\"text\": \" $ssid\", \"class\": \"connected\", \"tooltip\": \"WiFi: $ssid (iwd)\"}"
      else
        echo "{\"text\": \"󰤮\", \"class\": \"disconnected\", \"tooltip\": \"WiFi disconnected\"}"
      fi
    '';
    executable = true;
  };
}
