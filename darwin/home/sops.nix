{ config
, lib
, pkgs
, inputs
, ...
}:

{
  imports = [
    inputs.sops-nix.homeManagerModules.sops
    ../../shared/sops.nix
  ];

  # Legacy Atlassian/Confluence API-token secrets (secrets/user/atlassian.yaml)
  # are retained in the repo as inert ciphertext but are no longer declared
  # here: the local sooperset mcp-atlassian stack was replaced by the official
  # remote Atlassian Rovo MCP (OAuth 2.1), which consumes no secrets.
  # See openspec/changes/archive/2026-09-08-atlassian-rovo-mcp-mact2 and docs/atlassian-rovo-mcp.md.
  # GitHub tokens are now managed by `gh auth token` on darwin.
  # Linux hosts migrated to the same pattern (change: unify-github-auth).
}
