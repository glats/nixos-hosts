#!/usr/bin/env bash

@dbus@/bin/dbus-update-activation-environment --systemd --all

mkdir -p "$HOME/.local/state"
SYSTEM_PID_FILE="$HOME/.local/state/xrdp-system-pids-$DISPLAY"
pgrep -u "$USER" > "$SYSTEM_PID_FILE"

@systemd@/bin/systemctl --user start graphical-session.target 2>/dev/null || true

@xset@/bin/xset s off 2>/dev/null || true
@xset@/bin/xset -dpms 2>/dev/null || true
@xset@/bin/xset s noblank 2>/dev/null || true

while true; do
  LOG_FILE="$HOME/.local/state/xrdp-mate.log"

  {
    echo
    echo "===== $(date) ====="
    echo "Starting MATE session"
    echo "user=$USER"
    echo "display=$DISPLAY"
  } >> "$LOG_FILE"

  (
    exec >> "$LOG_FILE" 2>&1
    set -x

    export XRDP_SESSION=1
    export DESKTOP_SESSION=mate
    export XDG_CURRENT_DESKTOP=MATE

    @mate-session-manager@/bin/mate-session
  )

  echo "===== Cleaning up after MATE session =====" >> "$LOG_FILE"

  SYSTEM_PID_FILE="$HOME/.local/state/xrdp-system-pids-$DISPLAY"

  is_excluded() {
    local pid="$1"
    local comm cmdline
    comm=$(cat /proc/$pid/comm 2>/dev/null) || return 1
    cmdline=$(cat /proc/$pid/cmdline 2>/dev/null | tr '\0' ' ') || true
    case "$comm" in
      ssh-agent|gpg-agent|gnome-keyring-d|gnome-keyring-daemon|.gnome-keyring-*|tmux) return 0 ;;
    esac
    case "$cmdline" in
      *gnome-keyring*|*tmux*) return 0 ;;
      *) return 1 ;;
    esac
  }

  if [ -f "$SYSTEM_PID_FILE" ]; then
    for pid in $(pgrep -u "$USER"); do
      if ! grep -qw "$pid" "$SYSTEM_PID_FILE" && ! is_excluded "$pid"; then
        kill -TERM "$pid" 2>/dev/null || true
      fi
    done
  fi

  sleep 2

  if [ -f "$SYSTEM_PID_FILE" ]; then
    for pid in $(pgrep -u "$USER"); do
      if ! grep -qw "$pid" "$SYSTEM_PID_FILE" && ! is_excluded "$pid"; then
        kill -KILL "$pid" 2>/dev/null || true
      fi
    done
  fi

  rm -f "$HOME/.config/mate/session.state" 2>/dev/null || true
  rm -rf "$HOME/.cache/sessions" 2>/dev/null || true

  unset DESKTOP_SESSION XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE XDG_SEAT
  done

  rm -f "$SYSTEM_PID_FILE"
