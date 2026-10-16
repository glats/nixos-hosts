#!/bin/sh
set -u

BAT=/sys/class/power_supply/bq27411-0
CHG=/sys/class/power_supply/pmi8998_charger
STATE_DIR=/var/lib/power-monitor
STATE=$STATE_DIR/state
ENV_FILE=/home/glats/Work/don-bot/.env
CONF=/etc/oneplus5-notify.conf
LOW_PCT=15
REMIND_SECS=1800

log() { echo "power-monitor: $1"; }

read_state() {
	version=1; prev_status=; tx_confirm=0; lost_pending=0; low_warned=0; remind_at=0; last_capacity=
	[ -f "$STATE" ] || return 0
	while IFS='=' read -r k v; do
		case $k in
		prev_status) prev_status=$v ;; tx_confirm) tx_confirm=$v ;;
		lost_pending) lost_pending=$v ;; low_warned) low_warned=$v ;;
		remind_at) remind_at=$v ;; last_capacity) last_capacity=$v ;;
		esac
	done < "$STATE"
}

write_state() {
	tmp=$(mktemp "$STATE_DIR/.state.XXXXXX") || { log "state mktemp failed"; return 1; }
	chmod 640 "$tmp"
	printf 'version=1\nprev_status=%s\ntx_confirm=%s\nlost_pending=%s\nlow_warned=%s\nremind_at=%s\nlast_capacity=%s\n' \
		"$prev_status" "$tx_confirm" "$lost_pending" "$low_warned" "$remind_at" "$last_capacity" > "$tmp"
	mv "$tmp" "$STATE" || { log "state mv failed"; rm -f "$tmp"; return 1; }
}

sample() {
	if [ -n "$SIM_STATUS" ]; then
		status=$SIM_STATUS; capacity=$SIM_CAPACITY
	else
		status=$(cat "$BAT/status" 2>/dev/null || echo Unknown)
		capacity=$(cat "$BAT/capacity" 2>/dev/null || echo 0)
	fi
	case $capacity in '' | *[!0-9]*) capacity=0 ;; esac
	chg=$(cat "$CHG/status" 2>/dev/null || echo Unknown)
}

is_plugged() { case $1 in Charging | Full | "Not charging" | Unknown) return 0 ;; *) return 1 ;; esac; }

notify() {
	token=$(awk -F= '/^TELEGRAM_TOKEN=/{print $2; exit}' "$ENV_FILE" 2>/dev/null)
	chat_id=$(awk -F= '/^CHAT_ID=/{print $2; exit}' "$CONF" 2>/dev/null)
	if [ -z "${token:-}" ] || [ -z "${chat_id:-}" ]; then
		log "degraded: token or CHAT_ID missing; alert stays pending: $1"
		return 1
	fi
	cfg=$(mktemp) || { log "degraded: mktemp failed"; return 1; }
	{
		printf 'url = "https://api.telegram.org/bot%s/sendMessage"\n' "$token"
		printf 'data = "chat_id=%s"\n' "$chat_id"
		printf 'data-urlencode = "text=%s"\n' "$1"
	} > "$cfg"
	http=$(curl -m 10 -sS -o /dev/null -w '%{http_code}' -K "$cfg" 2>/dev/null)
	rc=$?
	rm -f "$cfg"
	if [ $rc -ne 0 ] || [ "$http" != "200" ]; then
		log "degraded: sendMessage failed (rc=$rc http=$http); state preserved"
		return 1
	fi
	log "alert delivered: $1"
	return 0
}

decide() {
	now=$(date +%s)
	if [ "$status" = "Unknown" ] && [ "$prev_status" != "Unknown" ]; then
		log "status Unknown; treated as plugged (quirk guard)"
	fi
	prev_plugged=0; is_plugged "$prev_status" && prev_plugged=1
	if is_plugged "$status"; then
		tx_confirm=0
		if [ "$lost_pending" = 1 ] && notify "✅ OnePlus 5: cargador conectado de nuevo (batería al ${capacity}%)"; then
			lost_pending=0; low_warned=0; remind_at=0
		fi
		return 0
	fi
	if [ "$prev_plugged" = 1 ] && [ "$tx_confirm" = 0 ]; then
		tx_confirm=1
		log "plugged->Discharging: first sample, awaiting confirmation"
	elif [ "$tx_confirm" = 1 ] && [ "$lost_pending" = 0 ]; then
		if notify "⚠️ OnePlus 5: cargador desconectado — batería al ${capacity}%"; then
			lost_pending=1; tx_confirm=0
		fi
	fi
	if [ "$capacity" -le "$LOW_PCT" ] && [ "$now" -ge "$remind_at" ]; then
		if notify "🔋 OnePlus 5: batería baja — ${capacity}%"; then
			low_warned=1; remind_at=$((now + REMIND_SECS))
		fi
	fi
}

SIM_STATUS=; SIM_CAPACITY=
case ${1:-} in
--simulate | --simulate=*)
	spec=${2:-}
	case $1 in --simulate=*) spec=${1#--simulate=} ;; esac
	SIM_STATUS=${spec%%,*}; SIM_CAPACITY=${spec#*,}
	log "simulate status=$SIM_STATUS capacity=$SIM_CAPACITY"
	;;
esac
read_state
sample
log "sample: battery=$status ${capacity}% charger=$chg"
decide
prev_status=$status; last_capacity=$capacity
write_state
