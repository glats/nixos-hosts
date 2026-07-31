{ config, lib, pkgs, ... }:

let
  atlassianMcpWrapper = pkgs.writeShellScriptBin "atlassian-mcp-server" ''
    #!${pkgs.runtimeShell}
    set -euo pipefail

    # Load Atlassian credentials from sops-nix secrets
    atlassian_jira_url="${config.sops.secrets."opencode/atlassian_jira_url".path}"
    atlassian_username="${config.sops.secrets."opencode/atlassian_username".path}"
    atlassian_api_token="${config.sops.secrets."opencode/atlassian_api_token".path}"
    confluence_url="${config.sops.secrets."opencode/confluence_url".path}"
    confluence_pat="${config.sops.secrets."opencode/confluence_pat".path}"

    # Validate all secret files exist
    for secret in \
      "$atlassian_jira_url" \
      "$atlassian_username" \
      "$atlassian_api_token" \
      "$confluence_url" \
      "$confluence_pat"; do
      if [ ! -f "$secret" ]; then
        echo "Error (atlassian-mcp): secret file not found: $secret" >&2
        exit 1
      fi
    done

    export JIRA_URL="$(cat "$atlassian_jira_url")"
    export JIRA_USERNAME="$(cat "$atlassian_username")"
    export JIRA_API_TOKEN="$(cat "$atlassian_api_token")"
    export CONFLUENCE_URL="$(cat "$confluence_url")"
    export CONFLUENCE_PERSONAL_TOKEN="$(cat "$confluence_pat")"

    exec ${config.home.homeDirectory}/.local/share/uv/tools/mcp-atlassian/bin/python3 \
      ${config.home.homeDirectory}/.local/bin/mcp-atlassian-wrapper.py
  '';
in
{
  home.packages = [ atlassianMcpWrapper ];
}
