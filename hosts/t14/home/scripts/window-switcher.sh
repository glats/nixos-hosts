#!/usr/bin/env bash
# window-switcher.sh — T14 window switcher using omarchy's walker menu.
# Wraps omarchy's walker backend with a window-mode filter.
#
# Usage: window-switcher.sh
# Keybinding: Super+Q (defined in hosts/t14/home/hypr/bindings.nix)

set -euo pipefail

WALKER_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/walker"

# Ensure walker cache dir exists (walker needs it for its socket)
mkdir -p "$WALKER_CACHE_DIR"

# Use walker in window-switcher mode (lists all windows in a flat menu).
# The -m windows flag tells walker to switch to window mode, and the
# empty string '' starts the menu immediately without a search query.
exec walker -m windows ''