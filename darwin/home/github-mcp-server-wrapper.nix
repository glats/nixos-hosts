{ pkgs, config, ... }:

let
  # Helper: create a named GitHub MCP wrapper that reads PAT from a sops secret path
  mkGithubMcpWrapper =
    { name, secretPath }:
    pkgs.writeShellScriptBin name ''
      #!${pkgs.runtimeShell}
      set -euo pipefail

      GITHUB_PAT_FILE="${secretPath}"

      if [ ! -f "$GITHUB_PAT_FILE" ]; then
        echo "Error: GitHub PAT secret not found at $GITHUB_PAT_FILE" >&2
        exit 1
      fi

      GITHUB_PERSONAL_ACCESS_TOKEN=$(cat "$GITHUB_PAT_FILE")
      export GITHUB_PERSONAL_ACCESS_TOKEN

      # Pre-check: validate token before starting MCP server
      if ! GH_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN" \
        ${pkgs.gh}/bin/gh auth status --active --hostname github.com >/dev/null 2>&1; then
        echo "Error (${name}): GitHub PAT at $GITHUB_PAT_FILE is expired or invalid!" >&2
        echo "" >&2
        echo "  Create a new PAT at: https://github.com/settings/tokens" >&2
        exit 1
      fi

      exec ${pkgs.github-mcp-server}/bin/github-mcp-server "''${@:-stdio}"
    '';

  # New named wrappers
  githubMcpServerPersonal = mkGithubMcpWrapper {
    name = "github-mcp-server-personal";
    secretPath = config.sops.secrets."github/personal_pat".path;
  };

  # macOS work reads github/token from atlassian.yaml (legacy path on macOS)
  githubMcpServerWork = mkGithubMcpWrapper {
    name = "github-mcp-server-work";
    secretPath = config.sops.secrets."github/token".path;
  };

in
{
  home.packages = [
    githubMcpServerPersonal
    githubMcpServerWork
  ];
}
