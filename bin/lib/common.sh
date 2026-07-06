# Shared shell library for NixOS bin/ scripts
# Source: SCRIPT_DIR=$(dirname "$0") && source "$SCRIPT_DIR/lib/common.sh"

set -euo pipefail

# Detect repo root (works from bin/ or bin/lib/)
repo_root() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -d "$script_dir/../.git" ]]; then
        realpath "$script_dir/.."
    else
        git rev-parse --show-toplevel 2>/dev/null || {
            echo "ERROR: Cannot find repo root" >&2
            exit 1
        }
    fi
}

# Exit with error message
die() {
    echo "ERROR: $*" >&2
    exit 1
}

# Require root privileges
require_root() {
    if [[ $EUID -ne 0 ]]; then
        die "This command must be run as root (sudo)"
    fi
}

# Confirm action with user
confirm_action() {
    local prompt="${1:-Are you sure?}"
    read -r -p "$prompt [y/N] " response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
}
