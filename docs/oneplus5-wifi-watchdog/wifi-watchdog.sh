#!/bin/sh
set -u

STATE_DIR=/var/lib/wifi-watchdog
STATE=$STATE_DIR/state
DRV=/sys/bus/platform/drivers/ath10k_snoc
DEVICE=18800000.wifi
log() { printf '%s rung=%s %s\n' "$(date -Is)" "${RUNG:-detect}" "$*"; }
load_state() {
    failures=0; next_rung=0; last_rung=0; last_result=init; substep=unbind
    last_reboot=0
    [ -r "$STATE" ] || return 0
    while IFS='=' read -r key value; do
        case "$key" in
            version) [ "$value" = 1 ] || continue ;;
            failures|next_rung|last_rung|last_reboot)
                case "$value" in ''|*[!0-9]*) continue ;; esac
                eval "$key=$value" ;;
            last_result) case "$value" in ''|*[!A-Za-z0-9_-]*) continue ;; esac; last_result=$value ;;
            substep) case "$value" in unbind|bind) substep=$value ;; esac ;;
        esac
    done < "$STATE"
}
save_state() {
    tmp=$(mktemp "$STATE_DIR/.state.XXXXXX") || return 1
    if ! { printf '%s\n' "version=1" "failures=$failures" "next_rung=$next_rung" \
        "last_rung=$last_rung" "last_result=$last_result" "substep=$substep" "last_reboot=$last_reboot"; } > "$tmp"; then
        rm -f "$tmp"; return 1
    fi
    chmod 0600 "$tmp" && chown root:root "$tmp" && mv -f "$tmp" "$STATE"
}
associated() {
    nmcli -t -f GENERAL.STATE device show wlan0 2>/dev/null | grep -q '^GENERAL.STATE:100' || return 1
    iw dev wlan0 link 2>/dev/null | grep -q '^Connected to ' || return 1
}
healthy() {
    associated || return 1
    ip -4 -o addr show dev wlan0 scope global 2>/dev/null | grep -q ' 172\.16\.0\.12/'
}
recent_crash() {
    journalctl -k --since '-10 min' --no-pager -n 1 \
        -g 'ath10k_snoc .*firmware crashed!|qcom-q6v5-mss .*fatal error received' \
        2>/dev/null | grep -q .
}
verify_health() {
    i=0
    while [ "$i" -lt 8 ]; do
        healthy && return 0
        i=$((i + 1)); sleep 2
    done
    return 1
}
rung0() {
    RUNG=0; log 'starting NetworkManager recovery'
    timeout 8 nmcli --wait 8 device connect wlan0 >/dev/null 2>&1 || \
        timeout 8 nmcli --wait 8 connection up JICS >/dev/null 2>&1 || true
    verify_health
}
rung1_phase_a() {
    [ -w "$DRV/unbind" ] || return 1
    log 'rung-1 phase=unbind; no graceful disconnect'
    timeout 5 sh -c 'printf "%s\n" "$1" > "$2/unbind"' sh "$DEVICE" "$DRV"
    result=$?
    if [ "$result" -ne 0 ]; then
        if [ ! -e /sys/class/net/wlan0 ]; then
            log 'unbind completed asynchronously after timeout'
        else
            log 'unbind timed out while wlan0 remained present; escalating'
            next_rung=2; rung1_escalate=1; return 0
        fi
    fi
    i=0; while [ "$i" -lt 5 ] && [ -e /sys/class/net/wlan0 ]; do i=$((i + 1)); sleep 1; done
    if [ -e /sys/class/net/wlan0 ]; then
        log 'unbind did not remove wlan0; escalating'; next_rung=2; rung1_escalate=1; return 0
    fi
    substep=bind; next_rung=1; rung1_deferred=1
    return 0
}
rung1_phase_b() {
    [ -w "$DRV/bind" ] || return 1
    log 'rung-1 phase=bind'
    timeout 5 sh -c 'printf "%s\n" "$1" > "$2/bind"' sh "$DEVICE" "$DRV" || return 1
    i=0; while [ "$i" -lt 10 ] && [ ! -e /sys/class/net/wlan0 ]; do i=$((i + 1)); sleep 1; done
    [ -e /sys/class/net/wlan0 ] || return 1
    timeout 8 nmcli --wait 8 connection up JICS >/dev/null 2>&1 || return 1
    verify_health
}
rung1() {
    RUNG=1; rung1_deferred=0; rung1_escalate=0
    [ -w "$DRV/unbind" ] && [ -w "$DRV/bind" ] || return 1
    if [ "${substep:-unbind}" = bind ] || [ ! -e /sys/class/net/wlan0 ]; then
        rung1_phase_b
    else
        rung1_phase_a
    fi
}
rung1_test() {
    RUNG=1; rung1_deferred=0; rung1_escalate=0; substep=unbind
    rung1_phase_a || return $?
    [ "$rung1_escalate" -eq 0 ] || return 1
    rung1_phase_b
}
rung2() {
    RUNG=2; now=$(date +%s)
    if [ "$last_reboot" -gt 0 ] && [ $((now - last_reboot)) -lt 21600 ]; then
        last_result=reboot-suppressed
        log 'reboot suppressed by six-hour guard'; save_state; return 1
    fi
    last_reboot=$now; last_result=rebooting; save_state || return 1
    log 'last resort reboot'; systemctl reboot
}

main() {
    mkdir -p "$STATE_DIR" 2>/dev/null || return 1
    load_state
    if [ "${1:-}" = --test-rung1 ]; then
        log 'isolated rung-1 test; state and escalation disabled'
        rung1_test; result=$?
        log "isolated rung-1 result=$result"; return "$result"
    fi
    RUNG=detect
    if healthy; then
        failures=0; next_rung=0; last_result=healthy; save_state; log 'healthy'; return 0
    fi
    failures=$((failures + 1))
    if [ "$failures" -lt 2 ]; then
        last_result=loss-deferred; save_state; log "loss deferred failures=$failures"; return 0
    fi
    RUNG=$next_rung
    [ "$next_rung" -eq 0 ] && recent_crash && RUNG=1
    rung1_escalate=0; rung1_deferred=0
    case "$RUNG" in 0) rung0 ;; 1) rung1 ;; 2) rung2 ;; *) return 1 ;; esac
    result=$?
    last_rung=$RUNG
    if [ "$result" -eq 0 ] && [ "$rung1_escalate" -eq 1 ]; then
        last_result=failure; next_rung=2
    elif [ "$result" -eq 0 ] && [ "$rung1_deferred" -eq 1 ]; then
        failures=0; next_rung=1; last_result=unbind-complete
    elif [ "$result" -eq 0 ]; then failures=0; next_rung=0; substep=unbind; last_result=success
    else next_rung=$((RUNG + 1)); [ "$next_rung" -gt 2 ] && next_rung=2; last_result=failure; fi
    save_state || return 1
    log "result=$result next_rung=$next_rung"; return "$result"
}

main "$@"
