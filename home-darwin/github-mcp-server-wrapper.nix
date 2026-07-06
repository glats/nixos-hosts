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

  githubMcpServerGlats = mkGithubMcpWrapper {
    name = "github-mcp-server-glats";
    secretPath = config.sops.secrets."github/pat".path;
  };

  # macOS jcuzmar reads github/token from atlassian.yaml (backward compat)
  githubMcpServerJcuzmar = mkGithubMcpWrapper {
    name = "github-mcp-server-jcuzmar";
    secretPath = config.sops.secrets."github/token".path;
  };
in
{
  home.packages = [
    githubMcpServerGlats
    githubMcpServerJcuzmar
  ];
}
