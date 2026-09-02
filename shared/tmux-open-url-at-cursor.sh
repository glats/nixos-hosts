#!/usr/bin/env bash
set -eu

# Open the URL under the copy-mode cursor. A selection wins when present.
target=$(cat)
if [[ -z "${target//[[:space:]]/}" ]]; then
  x=$(tmux display-message -p '#{copy_cursor_x}')
  y=$(tmux display-message -p '#{copy_cursor_y}')
  line=$(tmux capture-pane -p | sed -n "$((y + 1))p")

  while [[ "$line" =~ (https?://[^[:space:]\<\>\"\'\)\]\}]+) ]]; do
    match=${BASH_REMATCH[1]}
    start=${line%%"$match"*}
    end=$(( ${#start} + ${#match} - 1 ))
    if (( x >= ${#start} && x <= end )); then
      target=$match
      break
    fi
    line=${line:${#start}+${#match}}
    x=$((x - ${#start} - ${#match}))
  done
fi

[[ -n "${target//[[:space:]]/}" ]] || exit 0
target=${target//$'\n'/}

if [[ "$(uname)" == Darwin ]]; then
  open "$target" >/dev/null 2>&1 &
elif command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$target" >/dev/null 2>&1 &
fi

tmux send-keys -X cancel 2>/dev/null || true
