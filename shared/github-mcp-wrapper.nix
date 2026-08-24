{ pkgs, ... }:

let
  # Helper: create a GitHub MCP wrapper that uses `gh auth token`
  # instead of a static sops-nix file. Tokens are managed by gh CLI
  # (auto-renewal via OAuth) — no more expired PATs or lost SSO.
  #
  # Uses gh native multi-account support (gh >= 2.40): both accounts live
  # under github.com and each wrapper targets a specific --user. Do NOT use
  # fake hostnames (e.g. personal.github.com) — gh config migrations can
  # wipe hand-crafted hosts.yml entries.
  mkGithubMcpWrapper =
    { name, user }:
    pkgs.writeShellScriptBin name ''
      #!${pkgs.runtimeShell}
      set -euo pipefail

      GH="${pkgs.gh}/bin/gh"

      # Pre-check + fetch: requires this exact account logged in on github.com
      if ! TOKEN=$($GH auth token --hostname github.com --user "${user}" 2>/dev/null); then
        echo "Error (${name}): gh has no account '${user}' on github.com" >&2
        echo "  Run: gh auth login --hostname github.com  (and choose account ${user})" >&2
        exit 1
      fi

      GITHUB_PERSONAL_ACCESS_TOKEN="$TOKEN"
      export GITHUB_PERSONAL_ACCESS_TOKEN

      exec ${pkgs.github-mcp-server}/bin/github-mcp-server "''${@:-stdio}"
    '';

  githubMcpServerPersonal = mkGithubMcpWrapper {
    name = "github-mcp-server-personal";
    user = "glats";
  };

  githubMcpServerWork = mkGithubMcpWrapper {
    name = "github-mcp-server-work";
    user = "jcuzmar-Falabella_FTC";
  };

in
{
  home.packages = [
    githubMcpServerWork
    githubMcpServerPersonal
  ];
}
