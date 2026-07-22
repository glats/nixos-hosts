{ config
, pkgs
, lib
, ...
}:

let
  # Helper: create a named GitHub MCP wrapper that reads PAT from a sops secret path
  mkGithubMcpWrapper =
    { name, secretPath }:
    pkgs.writeShellScriptBin name ''
      #!${pkgs.runtimeShell}
      set -euo pipefail

      GITHUB_PAT_FILE="${secretPath}"

      if [ ! -f "$GITHUB_PAT_FILE" ]; then
        echo "Error (${name}): GitHub PAT secret not found at $GITHUB_PAT_FILE" >&2
        exit 1
      fi

      GITHUB_PERSONAL_ACCESS_TOKEN=$(cat "$GITHUB_PAT_FILE")
      export GITHUB_PERSONAL_ACCESS_TOKEN

      # Pre-check: validate token before starting MCP server
      # Uses GH_TOKEN env var to check without writing to gh credential store.
      if ! GH_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN" \
        ${pkgs.gh}/bin/gh auth status --active --hostname github.com >/dev/null 2>&1; then
        echo "Error (${name}): GitHub PAT at $GITHUB_PAT_FILE is expired or invalid!" >&2
        echo "" >&2
        echo "  Create a new PAT at: https://github.com/settings/tokens" >&2
        echo "  Then run: sops edit secrets/shared/passwords.yaml" >&2
        echo "  Then run: nixos-build switch" >&2
        exit 1
      fi

      exec ${pkgs.github-mcp-server}/bin/github-mcp-server "''${@:-stdio}"
    '';

  # New named wrappers
  githubMcpServerPersonal = mkGithubMcpWrapper {
    name = "github-mcp-server-personal";
    secretPath = config.sops.secrets."github/personal_pat".path;
  };

  githubMcpServerWork = mkGithubMcpWrapper {
    name = "github-mcp-server-work";
    secretPath = config.sops.secrets."github/work_pat".path;
  };

in
{
  # GitHub MCP Server - Model Context Protocol server for GitHub
  # Provides AI tools with access to GitHub's platform via MCP protocol
  # Uses GitHub Personal Access Token from sops secrets (declared in modules/base/sops.nix)
  # Two wrappers: github-mcp-server-personal and github-mcp-server-work
  # Backward compat: github-mcp-server-glats and github-mcp-server-jcuzmar also available

  options.services.github-mcp-server-custom = {
    enable = lib.mkEnableOption "GitHub MCP Server" // {
      default = true;
    };
  };

  config = lib.mkIf config.services.github-mcp-server-custom.enable {
    environment.systemPackages = [
      githubMcpServerPersonal
      githubMcpServerWork
      pkgs.github-mcp-server
    ];
  };
}
