# T14-specific Home Manager overlays on top of omarchy-nix.
# Omarchy's theme runtime owns the visual layer (waybar theme, mako theme,
# ghostty theme).  This module adds only the non-visual delta:
#   - Hyprland t14-specific config fragments (monitor, input, bindings, looknfeel)
#   - Helper scripts (window-switcher, monitor-hotplug-handler, kb-*, mouse-wiggle)
#   - Ghostty t14 hardware tweaks on top of the shared
#     home-linux/ghostty.nix (imported via ./ghostty.nix)
#   - Kitty settings (imported directly from ../../../home-linux/kitty.nix
#     because omarchy-nix does not pull in that shared module — without this
#     import, t14 would only see omarchy's defaults and lose the nix-colors
#     palette and CaskaydiaCove font + size 11)
#   - Remmina remote-desktop launchers + connection files (./remmina.nix)
#   - mouse-wiggle launcher and its systemd user service
{
  lib,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ./hypr/monitors.nix
    ./hypr/input.nix
    ./hypr/bindings.nix
    ./hypr/looknfeel.nix
    ./hypr/autostart.nix
    ./hypr/hypridle.nix
    ./hypr/hyprlock.nix
    ./hypr/hyprsunset.nix
    ./hypr/xdph.nix
    ./ghostty.nix
    ../../../home-linux/kitty.nix
    ./remmina.nix
    ./mouse-wiggle.nix
    ./wayvnc
  ];

  # ------------------------------------------------------------------
  # Helper scripts (accessible from PATH via omarchy's bin directory)
  # ------------------------------------------------------------------
  home.file = {
    # Window switcher — uses omarchy's walker menu backend
    ".local/share/omarchy/bin/window-switcher.sh" = {
      source = ./scripts/window-switcher.sh;
      executable = true;
    };

    # Monitor hotplug handler — calls omarchy's monitor management
    ".local/share/omarchy/bin/monitor-hotplug-handler.sh" = {
      source = ./scripts/monitor-hotplug-handler.sh;
      executable = true;
    };

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
  # copy). We override JUST the config file to add a custom/iwd-wifi
  # module that reads WiFi status directly from iwd (since NM ignores
  # wlan0). The style.css and indicators/ dir remain from omarchy-nix.
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

  xdg.configFile."waybar/config" = lib.mkForce {
    source =
      let
        jsonFormat = pkgs.formats.json { };
        baseConfig = {
          reload_style_on_change = true;
          layer = "top";
          position = "top";
          spacing = 0;
          height = 26;
          modules-left = [
            "custom/omarchy"
            "hyprland/workspaces"
          ];
          modules-center = [
            "clock"
            "custom/update"
            "custom/voxtype"
            "custom/screenrecording-indicator"
            "custom/idle-indicator"
            "custom/notification-silencing-indicator"
          ];
          modules-right = [
            "group/tray-expander"
            "bluetooth"
            "network"
            "custom/iwd-wifi"
            "pulseaudio"
            "cpu"
            "battery"
          ];
          "hyprland/workspaces" = {
            on-click = "activate";
            format = "{icon}";
            format-icons = {
              default = "";
              "1" = "1";
              "2" = "2";
              "3" = "3";
              "4" = "4";
              "5" = "5";
              "6" = "6";
              "7" = "7";
              "8" = "8";
              "9" = "9";
              "10" = "0";
              "11" = "A";
              "12" = "B";
              "13" = "C";
              "14" = "D";
              "15" = "E";
              "16" = "F";
              "17" = "G";
              "18" = "H";
              "19" = "I";
              "20" = "J";
              active = "󱓻";
            };
            persistent-workspaces = {
              "1" = [ ];
              "2" = [ ];
              "3" = [ ];
              "4" = [ ];
              "5" = [ ];
            };
          };
          "custom/omarchy" = {
            format = "<span font='omarchy'>\ue900</span>";
            on-click = "omarchy-menu";
            on-click-right = "xdg-terminal-exec";
            tooltip-format = "Omarchy Menu\n\nSuper + Alt + Space";
          };
          "custom/update" = {
            format = "";
            exec = "omarchy-update-available";
            on-click = "omarchy-launch-floating-terminal-with-presentation omarchy-update";
            tooltip-format = "Omarchy update available";
            signal = 7;
            interval = 21600;
          };
          cpu = {
            interval = 5;
            format = "󰍛";
            on-click = "omarchy-launch-or-focus-tui btop";
            on-click-right = "alacritty";
          };
          clock = {
            format = "{:L%A %H:%M}";
            format-alt = "{:L%d %B W%V %Y}";
            tooltip = false;
            on-click-right = "omarchy-launch-floating-terminal-with-presentation omarchy-tz-select";
          };
          network = {
            format-icons = [
              "󰤯"
              "󰤟"
              "󰤢"
              "󰤥"
              "󰤨"
            ];
            format = "{icon}";
            format-wifi = "{icon}";
            format-ethernet = "󰀂";
            format-disconnected = "󰤮";
            tooltip-format-wifi = "{essid} ({frequency} GHz)";
            tooltip-format-ethernet = "Connected";
            tooltip-format-disconnected = "Disconnected";
            interval = 3;
            spacing = 1;
            on-click = "omarchy-launch-wifi";
          };
          "custom/iwd-wifi" = {
            exec = "~/.config/waybar/indicators/iwd-wifi.sh";
            return-type = "json";
            format = "{}";
            interval = 5;
            on-click = "omarchy-launch-wifi";
          };
          battery = {
            format = "{capacity}% {icon}";
            format-discharging = "{icon}";
            format-charging = "{icon}";
            format-plugged = "";
            format-icons = {
              charging = [
                "󰢜"
                "󰂆"
                "󰂇"
                "󰂈"
                "󰢝"
                "󰂉"
                "󰢞"
                "󰂊"
                "󰂋"
                "󰂅"
              ];
              default = [
                "󰁺"
                "󰁻"
                "󰁼"
                "󰁽"
                "󰁾"
                "󰁿"
                "󰂀"
                "󰂁"
                "󰂂"
                "󰁹"
              ];
            };
            format-full = "󰂅";
            tooltip-format-discharging = "{power:>1.0f}W↓ {capacity}%";
            tooltip-format-charging = "{power:>1.0f}W↑ {capacity}%";
            interval = 5;
            on-click = "omarchy-menu power";
            states = {
              warning = 20;
              critical = 10;
            };
          };
          bluetooth = {
            format = "";
            format-off = "󰂲";
            format-disabled = "󰂲";
            format-connected = "󰂱";
            format-no-controller = "";
            tooltip-format = "Devices connected: {num_connections}";
            on-click = "omarchy-launch-bluetooth";
          };
          pulseaudio = {
            format = "{icon}";
            on-click = "omarchy-launch-audio";
            on-click-right = "pamixer -t";
            tooltip-format = "Playing at {volume}%";
            scroll-step = 5;
            format-muted = "";
            format-icons = {
              headphone = "";
              headset = "";
              default = [
                ""
                ""
                ""
              ];
            };
          };
          "group/tray-expander" = {
            orientation = "inherit";
            drawer = {
              transition-duration = 600;
              children-class = "tray-group-item";
            };
            modules = [
              "custom/expand-icon"
              "tray"
            ];
          };
          "custom/expand-icon" = {
            format = "";
            tooltip = false;
            on-scroll-up = "";
            on-scroll-down = "";
            on-scroll-left = "";
            on-scroll-right = "";
          };
          "custom/screenrecording-indicator" = {
            on-click = "omarchy-cmd-screenrecord";
            exec = "~/.config/waybar/indicators/screen-recording.sh";
            signal = 8;
            return-type = "json";
          };
          "custom/idle-indicator" = {
            on-click = "omarchy-toggle-idle";
            exec = "~/.config/waybar/indicators/idle.sh";
            signal = 9;
            return-type = "json";
          };
          "custom/notification-silencing-indicator" = {
            on-click = "omarchy-toggle-notification-silencing";
            exec = "~/.config/waybar/indicators/notification-silencing.sh";
            signal = 10;
            return-type = "json";
          };
          "custom/voxtype" = {
            exec = "omarchy-voxtype-status";
            return-type = "json";
            format = "{icon}";
            format-icons = {
              idle = "";
              recording = "󰍬";
              transcribing = "󰔟";
            };
            tooltip = true;
            on-click-right = "omarchy-voxtype-config";
            on-click = "omarchy-voxtype-model";
          };
          tray = {
            icon-size = 12;
            spacing = 17;
          };
        };
      in
      jsonFormat.generate "waybar-config.json" baseConfig;
  };
}
