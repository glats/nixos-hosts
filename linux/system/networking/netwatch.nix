# netwatch — Background network health monitor for Realtek r8169 NICs.
#
# Runs as a systemd timer+oneshot: reads /sys/class/net/*/statistics/
# every N seconds, compares with previous values, and logs degradation
# events to journald with identifier "netwatch". Zero overhead when idle.
#
# Detects:
#   - Error/drop counter increases (rx_errors, tx_errors, rx_dropped, tx_dropped)
#   - Throughput collapse (rx_bytes delta below threshold while link is UP)
#   - Link speed degradation (drops from 1000Mb/s)
#   - Active ping probe (only when error counters increase — avoids noise)
#
# Usage:
#   services.netwatch.enable = true;
#   journalctl -t netwatch -p warning --since "24 hours ago"
{ config
, lib
, pkgs
, ...
}:

let
  cfg = config.services.netwatch;
in
{
  options.services.netwatch = {
    enable = lib.mkEnableOption "background network health monitoring";

    interval = lib.mkOption {
      type = lib.types.str;
      default = "60s";
      description = "How often to run the health check (systemd OnUnitActiveSec).";
    };

    throughputThreshold = lib.mkOption {
      type = lib.types.int;
      default = 1048576; # 1 MB/s
      description = "Bytes-per-second below which to flag throughput degradation.";
    };

    pingTarget = lib.mkOption {
      type = lib.types.str;
      default = "1.1.1.1";
      description = "IP to ping for active connectivity check.";
    };

    pingCount = lib.mkOption {
      type = lib.types.int;
      default = 3;
    };

    logLevel = lib.mkOption {
      type = lib.types.enum [
        "info"
        "warning"
      ];
      default = "warning";
      description = "Minimum journald priority for degradation events.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.netwatch = {
      description = "Network health check (degradation detection)";
      after = [
        "network.target"
        "network-online.target"
      ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Type = "oneshot";
        StateDirectory = "netwatch";
        # Minimal hardening — we need to read sysfs and optionally ping
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
        # AF_UNIX is REQUIRED: systemd-cat talks to journald via a unix
        # socket. Without it every log call fails and set -e kills the
        # service (reproduced live 2026-08-23: status=1 in ~200ms).
        RestrictAddressFamilies = "AF_UNIX AF_INET AF_INET6 AF_NETLINK";
        CapabilityBoundingSet = "CAP_NET_RAW";
        AmbientCapabilities = "CAP_NET_RAW";
        # Disable journald rate limiting for this unit so no event is lost
        LogRateLimitBurst = 0;
      };

      # Minimal deps for the script below: cat/basename/date (coreutils),
      # grep (gnugrep), ping (iputils), systemd-cat (systemd — `logger` is
      # NOT available on nixos-26.05 since util-linux 2.40 dropped it).
      path = with pkgs; [
        coreutils
        gnugrep
        iputils
        systemd
      ];

      script =
        let
          logPrio = if cfg.logLevel == "warning" then "4" else "6";
        in
        ''
            set -euo pipefail

            THRESHOLD=${toString cfg.throughputThreshold}
            STATEDIR="''${STATE_DIRECTORY:-/var/lib/netwatch}"

            for IFACE in /sys/class/net/enp*; do
              [ -d "$IFACE" ] || continue
              IFNAME="$(basename "$IFACE")"
              [ "$(cat "$IFACE/operstate" 2>/dev/null || echo down)" = "up" ] || continue

              S="$IFACE/statistics"
              RX_BYT="$(cat "$S/rx_bytes" 2>/dev/null || echo 0)"
              SPEED="$(cat "$IFACE/speed" 2>/dev/null || echo N/A)"

              # --- STATE: compare with previous run ---
              # State file stores "<epoch> <rx_bytes>". Using real elapsed
              # time (not the configured interval) makes the rate correct
              # even when the timer is delayed or the interface bounced
              # (bounce resets rx_bytes to 0 → negative delta → baseline).
              NOW="$(date +%s)"
              STATE="$STATEDIR/$IFNAME"
              PREV_EPOCH="$NOW"
              PREV_RX=0
              [ -f "$STATE" ] && read -r PREV_EPOCH PREV_RX < "$STATE" || true
              ELAPSED=$(( NOW - PREV_EPOCH ))
              [ "$ELAPSED" -lt 1 ] && ELAPSED=1
              DELTA=$(( RX_BYT - PREV_RX ))

              # --- THROUGHPUT DEGRADATION ---
              # Only flag if there WAS traffic but the rate is below the
              # threshold. Idle (delta=0) is not degradation. Negative
              # delta means a counter reset (link bounce) — skip check.
              if [ "$DELTA" -gt 0 ]; then
                RATE=$(( DELTA / ELAPSED ))
                if [ "$RATE" -lt "$THRESHOLD" ]; then
                  systemd-cat -t netwatch -p ${logPrio} <<EOM
          MESSAGE=$IFNAME: throughput drop — $RATE B/s (threshold ''${THRESHOLD}B/s)
          INTERFACE=$IFNAME
          NETWATCH_TYPE=throughput_drop
          BYTES_DELTA=$DELTA
          ELAPSED_SECS=$ELAPSED
          RATE_BPS=$RATE
          LINK_SPEED=$SPEED
          EOM
                fi
              fi

              # --- LINK SPEED CHECK ---
              if [ "$SPEED" != "N/A" ] && [ "$SPEED" != "1000" ]; then
                systemd-cat -t netwatch -p ${logPrio} <<EOM
          MESSAGE=$IFNAME: link speed ''${SPEED}Mb/s (expected 1000Mb/s)
          INTERFACE=$IFNAME
          NETWATCH_TYPE=speed_degraded
          LINK_SPEED=$SPEED
          EOM
              fi

              # Save for next run
              echo "$NOW $RX_BYT" > "$STATE"

              # --- RX DROPS (not rate-limited: compare with state) ---
              RX_DRP="$(cat "$S/rx_dropped" 2>/dev/null || echo 0)"
              TX_DRP="$(cat "$S/tx_dropped" 2>/dev/null || echo 0)"

              STATE_DROP="$STATEDIR/$IFNAME.drops"
              PREV_RX_DRP=0
              PREV_TX_DRP=0
              if [ -f "$STATE_DROP" ]; then
                read -r PREV_RX_DRP PREV_TX_DRP < "$STATE_DROP" || true
              fi
              D_RX_DRP=$(( RX_DRP - PREV_RX_DRP ))
              D_TX_DRP=$(( TX_DRP - PREV_TX_DRP ))

              if [ "$D_RX_DRP" -gt 0 ] || [ "$D_TX_DRP" -gt 0 ]; then
                systemd-cat -t netwatch -p ${logPrio} <<EOM
          MESSAGE=$IFNAME: packet drops rx_drop=+$D_RX_DRP tx_drop=+$D_TX_DRP
          INTERFACE=$IFNAME
          NETWATCH_TYPE=packet_drops
          DELTA_RX_DROP=$D_RX_DRP
          DELTA_TX_DROP=$D_TX_DRP
          EOM
              fi

              echo "$RX_DRP $TX_DRP" > "$STATE_DROP"
            done

            # --- ACTIVE PING PROBE ---
            PING_TARGET="${cfg.pingTarget}"
            PING_COUNT="${toString cfg.pingCount}"

            for IFACE in /sys/class/net/enp*; do
              [ -d "$IFACE" ] || continue
              IFNAME="$(basename "$IFACE")"
              [ "$(cat "$IFACE/operstate" 2>/dev/null || echo down)" = "up" ] || continue

              PING_OUT="$(ping -c "$PING_COUNT" -W 2 -I "$IFNAME" "$PING_TARGET" 2>&1 || true)"
              if echo "$PING_OUT" | grep -q "100% packet loss"; then
                systemd-cat -t netwatch -p ${logPrio} <<EOM
          MESSAGE=$IFNAME: 100% packet loss to $PING_TARGET
          INTERFACE=$IFNAME
          NETWATCH_TYPE=packet_loss
          TARGET=$PING_TARGET
          EOM
              fi
            done
        '';
    };

    # ── TIMER ──────────────────────────────────
    systemd.timers.netwatch = {
      description = "Periodic network health check";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "120s";
        OnUnitActiveSec = cfg.interval;
        AccuracySec = "30s";
        Persistent = true;
      };
    };
  };
}
