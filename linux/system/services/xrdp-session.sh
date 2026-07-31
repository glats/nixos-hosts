#!/usr/bin/env bash

# Common XRDP session preamble: dbus setup + disable screen blanking.
# DPMS/screen blanking causes disconnects in virtual sessions.

@dbus@/bin/dbus-update-activation-environment --systemd --all

# Take PID snapshot BEFORE activating graphical-session.target.
# Any process launched after this point (DE, autostarts, apps) will
# be considered session-spawned and killed on logout.
mkdir -p "$HOME/.local/state"
SYSTEM_PID_FILE="$HOME/.local/state/xrdp-system-pids-$DISPLAY"
pgrep -u "$USER" > "$SYSTEM_PID_FILE"

# xrdp-sesman creates the session directly (no display manager).
# Even though pam_systemd.so is present in the PAM config,
# graphical-session.target must be activated explicitly because
# there is no DM to do it for us.
@systemd@/bin/systemctl --user start graphical-session.target 2>/dev/null || true

@xset@/bin/xset s off 2>/dev/null || true
@xset@/bin/xset -dpms 2>/dev/null || true
@xset@/bin/xset s noblank 2>/dev/null || true

# Direct MATE session launcher for xrdp.
# Loop-based: after MATE logout, return to fresh MATE session instead of disconnect.
# Per-user override: create ~/startwm.sh to bypass entirely.

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

    # Export DE-specific env vars so the session and child processes know context
    export XRDP_SESSION=1
    export DESKTOP_SESSION=mate
    export XDG_CURRENT_DESKTOP=MATE

    @mate-session-manager@/bin/mate-session
  )

  # ── SESSION CLEANUP ──
  # Kill any process spawned during the DE session.
  # Uses the system snapshot taken in the preamble (before graphical-session.target).
  echo "===== Cleaning up after MATE session =====" >> "$LOG_FILE"

  SYSTEM_PID_FILE="$HOME/.local/state/xrdp-system-pids-$DISPLAY"

  # Check if a process is an agent that should survive DE logout
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

  # Phase 1: SIGTERM to all PIDs not in the system snapshot
  if [ -f "$SYSTEM_PID_FILE" ]; then
    for pid in $(pgrep -u "$USER"); do
      if ! grep -qw "$pid" "$SYSTEM_PID_FILE" && ! is_excluded "$pid"; then
        kill -TERM "$pid" 2>/dev/null || true
      fi
    done
  fi

  # Phase 2: Wait for graceful exit
  sleep 2

  # Phase 3: SIGKILL survivors
  if [ -f "$SYSTEM_PID_FILE" ]; then
    for pid in $(pgrep -u "$USER"); do
      if ! grep -qw "$pid" "$SYSTEM_PID_FILE" && ! is_excluded "$pid"; then
        kill -KILL "$pid" 2>/dev/null || true
      fi
    done
  fi

  # Phase 4: Clear session state files
  rm -f "$HOME/.config/mate/session.state" 2>/dev/null || true
  rm -rf "$HOME/.cache/sessions" 2>/dev/null || true

  # Phase 5: Unset DE-specific environment variables
  unset DESKTOP_SESSION XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE XDG_SEAT
  done

  # Final cleanup: remove system snapshot on disconnect
  rm -f "$SYSTEM_PID_FILE"
