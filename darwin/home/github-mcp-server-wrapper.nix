{ pkgs, ... }:

let
  # Helper: create a GitHub MCP wrapper that uses `gh auth token`
  # instead of a static sops-nix file. Tokens are managed by gh CLI
  # (auto-renewal via OAuth) — no more expired PATs or lost SSO.
  mkGithubMcpWrapper =
    { name, hostname }:
    pkgs.writeShellScriptBin name ''
      #!${pkgs.runtimeShell}
      set -euo pipefail

      GH="${pkgs.gh}/bin/gh"
      HOSTNAME="${hostname}"

      # Pre-check: validate gh is authenticated for this hostname
      if ! $GH auth status --hostname "$HOSTNAME" >/dev/null 2>&1; then
        echo "Error (${name}): gh not authenticated for $HOSTNAME" >&2
        echo "  Run: gh auth login --hostname $HOSTNAME" >&2
        exit 1
      fi

      GITHUB_PERSONAL_ACCESS_TOKEN=$($GH auth token --hostname "$HOSTNAME")
      export GITHUB_PERSONAL_ACCESS_TOKEN

      exec ${pkgs.github-mcp-server}/bin/github-mcp-server "''${@:-stdio}"
    '';

  githubMcpServerWork = mkGithubMcpWrapper {
    name = "github-mcp-server-work";
    hostname = "github.com";
  };

  githubMcpServerPersonal = mkGithubMcpWrapper {
    name = "github-mcp-server-personal";
    hostname = "personal.github.com";
  };

in
{
  home.packages = [
    githubMcpServerWork
    githubMcpServerPersonal
  ];
}
