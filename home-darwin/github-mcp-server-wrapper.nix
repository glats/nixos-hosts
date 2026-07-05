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
