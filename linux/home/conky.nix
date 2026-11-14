{
  config,
  lib,
  pkgs,
  conkyConfig ? {
    enable = false;
    networkInterface = "eth0";
    additionalInterfaces = [ ];
    mountPoints = [ ];
  },
  ...
}:

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
    export PATH="${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.gnused
        pkgs.gawk
      ]
    }:$PATH"

    log_files=$(find /var/log -type f -printf '%T@ %p\n' 2>/dev/null || true)
    oldest_file=$(printf '%s\n' "$log_files" | sort -n | head -1 | awk '{print $2}')

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

    if [ -z "$install_epoch" ]; then
      echo "n/a"
      exit 0
    fi

    current_epoch=$(date +%s)
    days=$(( (current_epoch - install_epoch) / 86400 ))

    if [ "$days" -lt 0 ]; then
      echo "n/a"
    else
      echo "$days"
    fi
  '';

  cpuTempScript = pkgs.writeShellScriptBin "conky-cpu-temp" ''
    set -uo pipefail
    export PATH="${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.gawk
      ]
    }:$PATH"

    max_from() {
      local max="" input value
      for input in "$@"; do
        [ -f "$input" ] || continue
        value=$(cat "$input" 2>/dev/null) || continue
        [ -z "$value" ] && continue
        case "$value" in
          *[!0-9]*) continue ;;
        esac
        if [ -z "$max" ] || [ "$value" -gt "$max" ]; then
          max="$value"
        fi
      done
      printf '%s' "$max"
    }

    cpu_dirs=()
    for dir in /sys/class/hwmon/hwmon*; do
      [ -d "$dir" ] || continue
      name=$(cat "$dir/name" 2>/dev/null) || continue
      case "$name" in
        coretemp|x86_pkg_temp|k10temp|zenpower) cpu_dirs+=("$dir") ;;
      esac
    done

    raw=""
    for dir in "''${cpu_dirs[@]:-}"; do
      [ -n "$dir" ] || continue
      value=$(max_from "$dir"/temp*_input)
      [ -n "$value" ] || continue
      if [ -z "$raw" ] || [ "$value" -gt "$raw" ]; then
        raw="$value"
      fi
    done

    if [ -z "$raw" ]; then
      raw=$(max_from /sys/class/thermal/thermal_zone*/temp)
    fi

    if [ -z "$raw" ]; then
      echo "n/a"
    else
      awk -v t="$raw" 'BEGIN { printf "%.0f°C\n", t / 1000 }'
    fi
  '';

  desktopScript = pkgs.writeShellScriptBin "conky-desktop" ''
    set -uo pipefail
    export PATH="${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.procps
      ]
    }:$PATH"

    raw=$(printf '%s %s' "''${XDG_CURRENT_DESKTOP:-}" "''${DESKTOP_SESSION:-}" | tr '[:lower:]' '[:upper:]')

    case "$raw" in
      *KDE*|*PLASMA*) echo "KDE Plasma"; exit 0 ;;
      *MATE*) echo "MATE"; exit 0 ;;
      *HYPRLAND*) echo "Hyprland"; exit 0 ;;
      *GNOME*) echo "GNOME"; exit 0 ;;
    esac

    if pgrep -f '(^|/)plasmashell( |$)|startplasma' >/dev/null 2>&1; then
      echo "KDE Plasma"
    elif pgrep -f '(^|/)mate-panel( |$)' >/dev/null 2>&1; then
      echo "MATE"
    elif pgrep -f '(^|/)Hyprland( |$)' >/dev/null 2>&1; then
      echo "Hyprland"
    elif pgrep -f '(^|/)gnome-shell( |$)' >/dev/null 2>&1; then
      echo "GNOME"
    else
      echo "n/a"
    fi
  '';

  gpuTempsScript = pkgs.writeShellScriptBin "conky-gpu-temps" ''
    set -uo pipefail
    export PATH="${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.gawk
        pkgs.lm_sensors
      ]
    }:$PATH"

    read_gpu_hwmon() {
      local path temp
      path="$1"
      if [ -f "$path" ]; then
        temp=$(awk '{ printf "%.1f", $1 / 1000 }' "$path" 2>/dev/null)
        [ -n "$temp" ] && printf "%s°C" "$temp"
      fi
    }

    outputs=()

    if command -v nvidia-smi >/dev/null 2>&1; then
      mapfile -t temps < <(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null || true)
      for line in "''${temps[@]:-}"; do
        temp=''${line//[^0-9.]/}
        [ -n "$temp" ] && outputs+=("''${temp}°C")
      done
    fi

    if [ "''${#outputs[@]}" -eq 0 ]; then
      shopt -s nullglob
      for hw in /sys/class/drm/card*/device/hwmon/hwmon*/temp1_input; do
        reading=$(read_gpu_hwmon "$hw")
        [ -n "$reading" ] && outputs+=("$reading")
      done
      shopt -u nullglob
    fi

    if [ "''${#outputs[@]}" -eq 0 ]; then
      echo "n/a"
    else
      printf '%s\n' "''${outputs[*]}" | paste -sd ' | ' -
    fi
  '';

  fanSpeedScript = pkgs.writeShellScriptBin "conky-fan-speed" ''
    set -uo pipefail
    export PATH="${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.gawk
        pkgs.lm_sensors
      ]
    }:$PATH"

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

    if [ -n "''${fan_output}" ]; then
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

  interfaces = [ conkyConfig.networkInterface ] ++ conkyConfig.additionalInterfaces;

  wirelessInterfaces = builtins.filter (name: lib.hasPrefix "wl" name) interfaces;

  ifUpOn =
    candidates: render: fallback:
    let
      go =
        rest:
        if rest == [ ] then
          fallback
        else
          "\${if_up ${builtins.head rest}}${render (builtins.head rest)}\${else}${go (builtins.tail rest)}\${endif}";
    in
    go candidates;

  ifUp = ifUpOn interfaces;

  mountSpecs =
    lib.imap0
      (
        index: entry:
        entry
        // {
          color = if lib.mod index 2 == 0 then colors.dark else colors.secondary;
        }
      )
      (
        [
          {
            path = "/";
            label = "root";
          }
        ]
        ++ map (path: {
          inherit path;
          label = baseNameOf path;
        }) conkyConfig.mountPoints
      );

  usageRow =
    entry:
    "\${goto 40}\${color #${colors.light}}${entry.label}:\${goto 140}\${color} \${fs_used ${entry.path}}/\${fs_size ${entry.path}}";

  barRow = entry: "\${goto 40}\${color #${entry.color}}\${fs_bar 5,200 ${entry.path}}\${color}";

  storageColumn = lib.concatMap (entry: [
    (usageRow entry)
    (barRow entry)
  ]) mountSpecs;

  networkColumn = [
    "\${goto 440}\${color #${colors.light}}Interface:\${goto 540}\${color} ${ifUp (name: name) "offline"}"
    "\${goto 440}\${color #${colors.light}}Up:\${goto 540}\${color} ${
      ifUp (name: "\${upspeed ${name}}") "0"
    }"
    "\${goto 440}\${color #${colors.light}}Down:\${goto 540}\${color} ${
      ifUp (name: "\${downspeed ${name}}") "0"
    }"
    "\${goto 440}\${color #${colors.light}}IP:\${goto 540}\${color} ${
      ifUp (name: "\${addr ${name}}") "n/a"
    }"
    "\${goto 440}\${color #${colors.light}}SSID:\${goto 540}\${color} ${
      if wirelessInterfaces == [ ] then
        "n/a"
      else
        ifUpOn wirelessInterfaces (name: "\${wireless_essid ${name}}") "wired"
    }"
  ];

  topColumn = lib.imap0 (
    index: _:
    "\${goto 840}\${color #${colors.light}}\${top name ${toString (index + 1)}}\${goto 990}\${top cpu ${toString (index + 1)}}%\${goto 1060}\${top mem ${toString (index + 1)}}%"
  ) (lib.range 0 4);

  headerRow = "\${goto 40}\${color #${colors.dark}}STORAGE\${color}\${goto 440}\${color #${colors.tertiary}}NETWORK\${color}\${goto 840}\${color #${colors.primary}}TOP PROCESSES\${color}";

  columnLength = builtins.length;

  maxColumnLength = lib.lists.foldl (acc: current: if current > acc then current else acc) 0 [
    (columnLength storageColumn)
    (columnLength networkColumn)
    (columnLength topColumn)
  ];

  cell = column: index: if index < columnLength column then builtins.elemAt column index else "";

  detailLines = lib.concatMapStringsSep "\n" (
    index: cell storageColumn index + cell networkColumn index + cell topColumn index
  ) (lib.range 0 (maxColumnLength - 1));

  conkyConfigText = pkgs.writeText "conky.conf" ''
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
    ''${goto 40}''${color #${colors.light}}OS:''${goto 160}''${color} $sysname $machine''${goto 440}''${color #${colors.light}}RAM:''${goto 540}''${color} $mem/$memmax''${goto 840}''${color #${colors.light}}CPU Temp:''${goto 950}''${color} ''${execi 5 ${cpuTempScript}/bin/conky-cpu-temp}
    ''${goto 40}''${color #${colors.light}}Host:''${goto 160}''${color} $nodename''${goto 440}''${color #${colors.secondary}}''${membar 5,200}''${color}''${goto 840}''${color #${colors.light}}GPU:''${goto 950}''${color} ''${execi 10 ${gpuTempsScript}/bin/conky-gpu-temps}
    ''${goto 40}''${color #${colors.light}}Kernel:''${goto 160}''${color} $kernel''${goto 440}''${color #${colors.light}}Swap:''${goto 540}''${color} $swap/$swapmax''${goto 840}''${color #${colors.light}}Fan:''${goto 950}''${color} ''${execi 10 ${fanSpeedScript}/bin/conky-fan-speed}
    ''${goto 40}''${color #${colors.light}}Desktop:''${goto 160}''${color} ''${execi 30 ${desktopScript}/bin/conky-desktop}''${goto 440}''${color #${colors.dark}}''${swapbar 5,200}''${color}
    ''${goto 40}''${color #${colors.light}}Install Days:''${goto 160}''${color} ''${execi 3600 ${installDaysScript}/bin/conky-install-days}
    ''${goto 40}''${color #${colors.light}}Uptime:''${goto 160}''${color} $uptime
    ''${goto 40}''${color #${colors.light}}CPU:''${goto 160}''${color} $cpu% ''${color #${colors.secondary}}''${cpubar 5,170}''${color}

    ''${voffset 60}
    ''${alignc}''${lua_parse get_logo_line}

    ''${voffset 60}
    ${headerRow}
    ${detailLines}
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
lib.mkIf conkyConfig.enable {
  home.packages = [
    conkyWrapper
    installDaysScript
    cpuTempScript
    desktopScript
    gpuTempsScript
    fanSpeedScript
  ];

  xdg.configFile."conky/conky.conf".source = conkyConfigText;
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
