{ config, pkgs, lib, ... }:

let
  # Wrapper script that reads GitHub PAT from sops and runs github-mcp-server
  github-mcp-server-wrapped = pkgs.writeShellScriptBin "github-mcp-server" ''
    #!${pkgs.runtimeShell}
    set -euo pipefail

    GITHUB_PAT_FILE="${config.sops.secrets."github/pat".path}"

    if [ ! -f "$GITHUB_PAT_FILE" ]; then
      echo "Error: GitHub PAT secret not found at $GITHUB_PAT_FILE" >&2
      exit 1
    fi

    GITHUB_PERSONAL_ACCESS_TOKEN=$(cat "$GITHUB_PAT_FILE")
    export GITHUB_PERSONAL_ACCESS_TOKEN

    exec ${pkgs.github-mcp-server}/bin/github-mcp-server "''${@:-stdio}"
  '';
in

{
  # GitHub MCP Server - Model Context Protocol server for GitHub
  # Provides AI tools with access to GitHub's platform via MCP protocol
  # Uses GitHub Personal Access Token from sops secrets

  environment.systemPackages = [
    github-mcp-server-wrapped
    pkgs.github-mcp-server # Also install original for reference
  ];

  # Ensure sops secret is available
  sops.secrets."github/pat" = {
    owner = "glats";
    group = "users";
    mode = "0400";
  };
}
