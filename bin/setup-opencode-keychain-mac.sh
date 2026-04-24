#!/usr/bin/env bash
# Setup OpenCode API keys in macOS Keychain
# Usage: setup-opencode-keychain-mac.sh
# Run this on the Mac (mact2.local)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================"
echo "OpenCode Keychain Setup for macOS"
echo "========================================"
echo

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
  echo -e "${RED}Error: This script must run on macOS${NC}"
  exit 1
fi

# Check if security command is available
if ! command -v security &> /dev/null; then
  echo -e "${RED}Error: security command not found${NC}"
  exit 1
fi

# Function to add key to Keychain
add_key() {
  local service="$1"
  local key_name="$2"
  local key_value
  
  echo -e "${YELLOW}Setting up $key_name...${NC}"
  
  # Check if key already exists
  if security find-generic-password -s "$service" 2>/dev/null | grep -q "password"; then
    echo -e "${BLUE}  Key already exists in Keychain${NC}"
    read -p "  Update? [y/N]: " update
    if [[ ! "$update" =~ ^[Yy]$ ]]; then
      echo "  Skipped"
      return 0
    fi
  fi
  
  # Prompt for key (hidden input)
  read -s -p "  Enter $key_name: " key_value
  echo
  
  if [ -z "$key_value" ]; then
    echo -e "${YELLOW}  Warning: Empty key, skipping${NC}"
    return 0
  fi
  
  # Add to Keychain
  if security add-generic-password \
    -a "opencode" \
    -s "$service" \
    -w "$key_value" \
    -U 2>/dev/null; then
    echo -e "${GREEN}  ✓ $key_name added to Keychain${NC}"
  else
    echo -e "${RED}  ✗ Failed to add $key_name${NC}"
    return 1
  fi
}

# Function to read key from Keychain (for verification)
read_key() {
  local service="$1"
  security find-generic-password -s "$service" -w 2>/dev/null || echo ""
}

# Main setup
echo -e "${BLUE}This will store your OpenCode API keys in macOS Keychain${NC}"
echo "The keys will be securely stored and accessible only to your user."
echo

# Fireworks API Key
add_key "opencode-fireworks-api-key" "Fireworks API Key"

# Anthropic API Key
add_key "opencode-anthropic-api-key" "Anthropic API Key"

# OpenAI API Key
add_key "opencode-openai-api-key" "OpenAI API Key"

# GitHub Token (for MCP)
add_key "opencode-github-token" "GitHub Personal Access Token"

echo
echo "========================================"
echo -e "${GREEN}Keychain setup complete!${NC}"
echo "========================================"
echo
echo "Keys stored:"
echo "  - opencode-fireworks-api-key"
echo "  - opencode-anthropic-api-key"
echo "  - opencode-openai-api-key"
echo "  - opencode-github-token"
echo
echo "These keys will be automatically injected into opencode.json"
echo "when the Home Manager configuration activates."
echo
echo "To verify a key is stored correctly:"
echo "  security find-generic-password -s opencode-fireworks-api-key -w"
