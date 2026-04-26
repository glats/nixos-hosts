{ config, lib, pkgs, ... }:

let
  colors = {
    primary = config.colorScheme.palette.base0D;
    secondary = config.colorScheme.palette.base0E;
    tertiary = config.colorScheme.palette.base0C;
    light = config.colorScheme.palette.base05;
    dark = config.colorScheme.palette.base03;
    text = config.colorScheme.palette.base05;
  };

  nixosIcon = builtins.fromJSON "\"\\uF313\"";

  installDaysScript = pkgs.writeShellScriptBin "conky-install-days" ''
    set -euo pipefail
    export PATH="${lib.makeBinPath [ pkgs.coreutils pkgs.gnused pkgs.gawk ]}:$PATH"

    oldest_file=$(find /var/log -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | head -1 | awk '{print $2}')

    if [ -z "$oldest_file" ]; then
      echo "n/a"
      exit 0
    fi

    install_date=$(stat -c %y "$oldest_file" 2>/dev/null | cut -d' ' -f1)

    if [ -z "$install_date" ]; then
      echo "n/a"
      exit 0
    fi

    install_epoch=$(date -d "$install_date" +%s 2>/dev/null)
    current_epoch=$(date +%s)

    if [ -z "$install_epoch" ]; then
      echo "n/a"
      exit 0
    fi

    days=$(( (current_epoch - install_epoch) / 86400 ))

    if [ "$days" -lt 0 ]; then
      echo "n/a"
    else
      echo "$days"
    fi
  '';

  gpuTempsScript = pkgs.writeShellScriptBin "conky-gpu-temps" ''
    set -uo pipefail
    export PATH="${lib.makeBinPath [ pkgs.coreutils pkgs.gawk pkgs.lm_sensors ]}:$PATH"

    read_gpu_hwmon() {
      local path temp card label
      card="$1"
      path="$2"
      if [[ -f "$path" ]]; then
        temp=$(awk '{ printf "%.1f", $1 / 1000 }' "$path" 2>/dev/null)
        [[ -n "$temp" ]] && printf "%s°C" "$temp"
      fi
    }

    outputs=()

    if command -v nvidia-smi >/dev/null 2>&1; then
      mapfile -t temps < <(nvidia-smi --query-gpu=name,temperature.gpu --format=csv,noheader 2>/dev/null || true)
      if (( ''${#temps[@]} )); then
        for ((i=0; i<''${#temps[@]}; i++)); do
          line="''${temps[i]}"
          temp=''${line##*, }
          temp=''${temp//[^0-9.]/}
          [[ -n "$temp" ]] && outputs+=("''${temp}°C")
        done
      fi
    fi

    if (( ''${#outputs[@]} == 0 )); then
      shopt -s nullglob
      for card in /sys/class/drm/card*; do
        [[ -d "$card" ]] || continue
        for hw in "$card"/device/hwmon/hwmon*/temp1_input; do
          reading=$(read_gpu_hwmon "" "$hw")
          [[ -n "$reading" ]] && outputs+=("$reading")
        done
      done
      shopt -u nullglob
    fi

    if (( ''${#outputs[@]} == 0 )); then
      echo "n/a"
    else
      printf '%s\n' "''${outputs[*]}" | paste -sd ' | ' -
    fi
  '';

  fanSpeedScript = pkgs.writeShellScriptBin "conky-fan-speed" ''
    set -euo pipefail
    export PATH="${lib.makeBinPath [ pkgs.coreutils pkgs.gawk pkgs.lm_sensors ]}:$PATH"

    fan_output=$(sensors 2>/dev/null | awk '
      tolower($1) ~ /cpu_fan:/ {
        gsub(":", "", $1);
        printf "%s", $2;
        found=1;
        exit;
      }
      /fan[0-9]+:/ && !found {
        gsub(":", "", $1);
        printf "%s", $2;
        found=1;
        exit;
      }
    ')

    if [[ -n "''${fan_output}" ]]; then
      echo "''${fan_output} RPM"
    else
      echo "n/a"
    fi
  '';

  logoLua = pkgs.writeText "logo.lua" ''
    local logo_size = 250

    function conky_get_logo_line()
      if conky_window then
        local w = conky_window.width
        local env_w = os.getenv("CONKY_LOGO_TEST_WIDTH")
        if env_w and tonumber(env_w) then
          w = tonumber(env_w)
        end
        logo_size = math.floor(w * 0.16)
        if logo_size < 160 then
          logo_size = 160
        end
        if logo_size > 700 then
          logo_size = 700
        end
      end
      return string.format("''${color #${colors.primary}}''${font CaskaydiaCove Nerd Font:size=%d}${nixosIcon}''${font}", logo_size)
    end
  '';

  conkyConfig = pkgs.writeText "conky.conf" ''
    conky.config = {
        alignment = 'middle_middle',
        background = false,
        border_width = 1,
        cpu_avg_samples = 2,
        default_color = '${colors.text}',
        default_outline_color = '${colors.text}',
        default_shade_color = '${colors.text}',
        double_buffer = true,
        draw_borders = false,
        draw_graph_borders = true,
        draw_outline = false,
        draw_shades = false,
        extra_newline = false,
        font = 'CaskaydiaCove Nerd Font:size=12',
        gap_x = 0,
        gap_y = 0,
        minimum_height = 5,
        minimum_width = 1150,
        maximum_width = 1150,
        net_avg_samples = 2,
        no_buffers = true,
        out_to_console = false,
        out_to_ncurses = false,
        out_to_stderr = false,
        out_to_wayland = false,
        out_to_x = true,
        own_window = true,
        own_window_class = 'Conky',
        own_window_type = 'normal',
        own_window_hints = 'undecorated,sticky,below,skip_taskbar,skip_pager',
        own_window_argb_visual = true,
        own_window_argb_value = 0,
        own_window_transparent = true,
        show_graph_range = false,
        show_graph_scale = false,
        stippled_borders = 0,
        update_interval = 1.0,
        uppercase = false,
        use_spacer = 'none',
        use_xft = true,
        lua_load = '${config.xdg.configHome}/conky/logo.lua',
    }

    conky.text = [[

    ''${voffset -40}
    ''${goto 40}''${color #${colors.primary}}SYSTEM''${color}''${goto 440}''${color #${colors.secondary}}MEMORY''${color}''${goto 840}''${color #${colors.tertiary}}SENSORS''${color}
    ''${goto 40}''${color #${colors.light}}OS:''${goto 160}''${color} $sysname $machine''${goto 440}''${color #${colors.light}}RAM:''${goto 540}''${color} $mem/$memmax''${goto 840}''${color #${colors.light}}CPU Temp:''${goto 950}''${color} ''${acpitemp}°C
    ''${goto 40}''${color #${colors.light}}Host:''${goto 160}''${color} $nodename''${goto 440}''${color #${colors.secondary}}''${membar 5,200}''${color}''${goto 840}''${color #${colors.light}}GPU:''${goto 950}''${color} ''${execi 10 ${gpuTempsScript}/bin/conky-gpu-temps}
    ''${goto 40}''${color #${colors.light}}Kernel:''${goto 160}''${color} $kernel''${goto 440}''${color #${colors.light}}Swap:''${goto 540}''${color} $swap/$swapmax''${goto 840}''${color #${colors.light}}Fan:''${goto 950}''${color} ''${execi 10 ${fanSpeedScript}/bin/conky-fan-speed}
    ''${goto 40}''${color #${colors.light}}Install Days:''${goto 160}''${color} ''${execi 3600 ${installDaysScript}/bin/conky-install-days}''${goto 440}''${color #${colors.dark}}''${swapbar 5,200}''${color}
    ''${goto 40}''${color #${colors.light}}Uptime:''${goto 160}''${color} $uptime
    ''${goto 40}''${color #${colors.light}}CPU:''${goto 160}''${color} $cpu% ''${color #${colors.secondary}}''${cpubar 5,170}''${color}

    ''${voffset 60}
    ''${alignc}''${lua_parse get_logo_line}

    ''${voffset 60}
    ''${goto 40}''${color #${colors.dark}}STORAGE''${color}''${goto 440}''${color #${colors.tertiary}}NETWORK''${color}''${goto 840}''${color #${colors.primary}}TOP PROCESSES''${color}
    ''${goto 40}''${color #${colors.light}}root:''${goto 140}''${color} ''${fs_used /}/''${fs_size /}''${goto 440}''${color #${colors.light}}Interface:''${goto 540}''${color} ''${if_up enp3s0}enp3s0''${else}''${if_up wlp2s0}wlp2s0''${else}offline''${endif}''${endif}''${goto 840}''${color lightgrey}Name''${goto 990}CPU%''${goto 1060}MEM%
    ''${goto 40}''${color #${colors.dark}}''${fs_bar 5,200 /}''${color}''${goto 440}''${color #${colors.light}}Up:''${goto 540}''${color} ''${if_up enp3s0}''${upspeed enp3s0}''${else}''${if_up wlp2s0}''${upspeed wlp2s0}''${else}0''${endif}''${endif}''${goto 840}''${color #${colors.light}}''${top name 1}''${goto 990}''${top cpu 1}%''${goto 1060}''${top mem 1}%
    ''${goto 40}''${color #${colors.light}}home:''${goto 140}''${color} ''${fs_used /home}/''${fs_size /home}''${goto 440}''${color #${colors.light}}Down:''${goto 540}''${color} ''${if_up enp3s0}''${downspeed enp3s0}''${else}''${if_up wlp2s0}''${downspeed wlp2s0}''${else}0''${endif}''${endif}''${goto 840}''${color #${colors.light}}''${top name 2}''${goto 990}''${top cpu 2}%''${goto 1060}''${top mem 2}%
    ''${goto 40}''${color #${colors.secondary}}''${fs_bar 5,200 /home}''${color}''${goto 440}''${color #${colors.light}}IP:''${goto 540}''${color} ''${if_up enp3s0}''${addr enp3s0}''${else}''${if_up wlp2s0}''${addr wlp2s0}''${else}n/a''${endif}''${endif}''${goto 840}''${color #${colors.light}}''${top name 3}''${goto 990}''${top cpu 3}%''${goto 1060}''${top mem 3}%
    ''${goto 40}''${color #${colors.light}}archlinux:''${goto 140}''${color} ''${fs_used /run/media/archlinux}/''${fs_size /run/media/archlinux}''${goto 440}''${color #${colors.light}}SSID:''${goto 540}''${color} ''${if_up wlp2s0}''${wireless_essid wlp2s0}''${else}wired''${endif}''${goto 840}''${color #${colors.light}}''${top name 4}''${goto 990}''${top cpu 4}%''${goto 1060}''${top mem 4}%
    ''${goto 40}''${color #${colors.dark}}''${fs_bar 5,200 /run/media/archlinux}''${color}''${goto 840}''${color #${colors.light}}''${top name 5}''${goto 990}''${top cpu 5}%''${goto 1060}''${top mem 5}%
    ''${goto 40}''${color #${colors.light}}library:''${goto 140}''${color} ''${fs_used /run/media/library}/''${fs_size /run/media/library}
    ''${goto 40}''${color #${colors.secondary}}''${fs_bar 5,200 /run/media/library}''${color}
    ''${goto 40}''${color #${colors.light}}stuff:''${goto 140}''${color} ''${fs_used /run/media/stuff}/''${fs_size /run/media/stuff}
    ''${goto 40}''${color #${colors.dark}}''${fs_bar 5,200 /run/media/stuff}''${color}
    ''${goto 40}''${color #${colors.light}}IO:''${goto 140}''${color} ''${diskio} R:''${diskio_read} W:''${diskio_write}
    ]]
  '';

  localeArchive = "${pkgs.glibcLocales}/lib/locale/locale-archive";

  conkyWrapper = pkgs.writeShellScriptBin "conky" ''
    export LOCALE_ARCHIVE_2_27="${localeArchive}"
    export LANG=''${LANG:-en_US.UTF-8}
    exec ${pkgs.conky}/bin/conky "$@"
  '';

  conkyLauncher = pkgs.writeShellScript "conky-launcher" ''
    export LOCALE_ARCHIVE_2_27="${localeArchive}"
    export LANG=''${LANG:-en_US.UTF-8}
    exec ${pkgs.conky}/bin/conky -c ${config.xdg.configHome}/conky/conky.conf
  '';

in
{
  home.packages = with pkgs; [
    conkyWrapper
    installDaysScript
    gpuTempsScript
    fanSpeedScript
  ];

  xdg.configFile."conky/conky.conf".source = conkyConfig;
  xdg.configFile."conky/logo.lua".source = logoLua;

  xdg.configFile."autostart/conky.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Version=1.0
    Name=Conky
    Comment=System monitor for X
    Categories=System;Monitor;
    Exec=${conkyLauncher}
    Icon=utilities-system-monitor
    Terminal=false
  '';
}
