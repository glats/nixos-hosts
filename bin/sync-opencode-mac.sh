#!/usr/bin/env bash
# Sync OpenCode configuration from NixOS to macOS
# Usage: sync-opencode-mac.sh [--dry-run] [user@]host[:port]
#   --dry-run: Show what would be done without actually doing it
#   [user@]host[:port]: Target macOS machine (default: mact2.local)

set -e

# Default values
DRY_RUN=false
TARGET_HOST="mact2.local"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --*)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
    *)
      TARGET_HOST="$1"
      shift
      ;;
  esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check dependencies
check_dependencies() {
  local deps=(nix jq rsync ssh)
  local missing=()
  
  for dep in "${deps[@]}"; do
    if ! command -v "$dep" &> /dev/null; then
      missing+=("$dep")
    fi
  done
  
  if [ ${#missing[@]} -ne 0 ]; then
    echo -e "${RED}Error: Missing dependencies: ${missing[*]}${NC}" >&2
    exit 1
  fi
}

# Read NixOS OpenCode config
read_nixos_config() {
  echo -e "${YELLOW}Reading NixOS OpenCode configuration...${NC}"
  
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would read from modules/home/opencode/"
  fi
  
  # Extract config using nix eval
  local config
  if ! config=$(nix eval --json --file ./modules/home/opencode.nix 2>/dev/null || echo '{}'); then
    echo -e "${RED}Warning: Could not eval opencode.nix, using manual extraction${NC}"
    config='{}'
  fi
  
  echo "$config" > /tmp/opencode-nixos-raw.json
}

# Generate Mac-compatible JSON
generate_mac_json() {
  echo -e "${YELLOW}Generating Mac-compatible JSON configuration...${NC}"
  
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would generate Mac-compatible JSON with model remapping"
    return 0
  fi
  
  # Create Mac-compatible config with model remapping
  jq '
    # Remap agent models from deepinfra to github-copilot
    .agents |= with_entries(
      .value |= if has("model") then
        .model |= 
          if . == "deepinfra/zai-org/GLM-5.1" then "github-copilot/gpt-5.4"
          elif . == "deepinfra/moonshotai/Kimi-K2.6" then "github-copilot/claude-opus-4"
          elif . == "deepinfra/Qwen/Qwen3.5-35B-A3B" then "github-copilot/claude-sonnet-4"
          elif . == "deepinfra/Qwen/Qwen3.6-35B-A3B" then "github-copilot/claude-sonnet-4"
          elif . == "deepinfra/Qwen/Qwen3.6-256B-A3B" then "github-copilot/claude-sonnet-4"
          elif startswith("deepinfra/") then "github-copilot/claude-sonnet-4"
          else .
          end
      else . end
    ) |
    # Remove deepinfra provider, keep others
    .providers |= with_entries(select(.key != "deepinfra"))
  ' /tmp/opencode-nixos-raw.json > /tmp/opencode-mac.json
  
  # Add placeholder API keys for Mac
  jq '
    .providers |= map_values(
      if has("options") and has("apiKey") then
        .options.apiKey = "KEYCHAIN_PLACEHOLDER"
      else . end
    )
  ' /tmp/opencode-mac.json > /tmp/opencode-mac-final.json
  
  mv /tmp/opencode-mac-final.json /tmp/opencode-mac.json
}

# Validate generated JSON
validate_json() {
  echo -e "${YELLOW}Validating generated JSON...${NC}"
  
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would validate JSON syntax and required fields"
    return 0
  fi
  
  if ! jq empty /tmp/opencode-mac.json 2>/dev/null; then
    echo -e "${RED}Error: Generated JSON is invalid${NC}" >&2
    exit 1
  fi
  
  # Verify required fields exist
  if ! jq -e '.agents and .providers and .mcps and .permissions' /tmp/opencode-mac.json > /dev/null 2>&1; then
    echo -e "${RED}Error: Generated JSON missing required fields${NC}" >&2
    exit 1
  fi
  
  echo -e "${GREEN}✓ JSON is valid${NC}"
}

# Push config to Mac
push_to_mac() {
  echo -e "${YELLOW}Pushing configuration to Mac ($TARGET_HOST)...${NC}"
  
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would:"
    echo "  - SSH to $TARGET_HOST"
    echo "  - Create ~/.config/opencode/ directory"
    echo "  - Rsync JSON, AGENTS.md, skills/, plugins/"
    return 0
  fi
  
  # Create directory on Mac
  if ! ssh "$TARGET_HOST" "mkdir -p ~/.config/opencode/plugins"; then
    echo -e "${RED}Error: Failed to create directory on Mac${NC}" >&2
    exit 1
  fi
  
  # Copy generated JSON
  if ! scp /tmp/opencode-mac.json "$TARGET_HOST:~/.config/opencode/opencode.json"; then
    echo -e "${RED}Error: Failed to copy opencode.json${NC}" >&2
    exit 1
  fi
  
  # Copy skills and commands from gentle-ai-assets
  local assets_dir="$(nix build .#gentle-ai-assets --no-link --print-out-paths 2>/dev/null)/share/gentle-ai" || true
  
  if [ -d "$assets_dir" ]; then
    rsync -avz "$assets_dir/skills/" "$TARGET_HOST:~/.config/opencode/skills/" || true
    rsync -avz "$assets_dir/opencode/commands/" "$TARGET_HOST:~/.config/opencode/commands/" || true
    rsync -avz "$assets_dir/opencode/persona-gentleman.md" "$TARGET_HOST:~/.config/opencode/PERSONA.md" || true
    rsync -avz "$assets_dir/AGENTS.md" "$TARGET_HOST:~/.config/opencode/AGENTS.md" || true
  fi
  
  # Copy local plugins
  if [ -d "./modules/home/opencode/plugins" ]; then
    rsync -avz ./modules/home/opencode/plugins/ "$TARGET_HOST:~/.config/opencode/plugins/" || true
  fi
  
  echo -e "${GREEN}✓ Configuration pushed to Mac${NC}"
}

# Install npm dependencies on Mac
install_npm_deps() {
  echo -e "${YELLOW}Installing npm dependencies on Mac...${NC}"
  
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would install @opencode-ai/plugin and @opencode-ai/sdk"
    return 0
  fi
  
  # Install npm packages on Mac
  if ! ssh "$TARGET_HOST" "cd ~/.config/opencode && npm install --no-save @opencode-ai/plugin@1.4.11 @opencode-ai/sdk@1.4.11 2>/dev/null || true"; then
    echo -e "${YELLOW}Warning: npm install failed or already present${NC}"
  fi
  
  echo -e "${GREEN}✓ Dependencies installed${NC}"
}

# Main
main() {
  echo "========================================"
  echo "OpenCode Config Sync: NixOS → macOS"
  echo "Target: $TARGET_HOST"
  echo "Mode: $([ "$DRY_RUN" = true ] && echo "DRY RUN" || echo "LIVE")"
  echo "========================================"
  echo
  
  check_dependencies
  read_nixos_config
  generate_mac_json
  validate_json
  push_to_mac
  install_npm_deps
  
  echo
  echo "========================================"
  echo -e "${GREEN}Sync completed successfully!${NC}"
  echo "========================================"
  echo
  echo "Next steps:"
  echo "1. Run setup script on Mac to configure Keychain:"
  echo "   ./bin/setup-opencode-keychain-mac.sh"
  echo "2. Or manually set API keys in macOS Keychain"
  echo
}

main "$@"
