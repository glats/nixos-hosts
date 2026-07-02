# gh-auth Specification

## Purpose

Authenticate `gh` CLI, `git` operations, and GitHub MCP server on all Linux hosts (rog, thinkcentre, t14) using sops-nix secrets. Darwin (mact2) is explicitly excluded.

## Requirements

### Requirement: Git Identity on Linux Hosts

The system MUST set `user.name` and `user.email` in git configuration for user `glats` on all Linux hosts via Home Manager.

These values MUST NOT be set on Darwin hosts (mact2).

| Attribute | Value |
|-----------|-------|
| `user.name` | `Redacted Name` |
| `user.email` | `personal@example.com` |

#### Scenario: Git identity is set on Linux host

- GIVEN a Linux host (rog, thinkcentre, or t14) with the configuration applied
- WHEN `git config user.name` is executed
- THEN the output MUST be `Redacted Name`
- AND `git config user.email` MUST output `personal@example.com`

#### Scenario: Git identity is NOT set on Darwin host

- GIVEN the Darwin host mact2
- WHEN `git config --global user.name` is executed
- THEN the output MUST be empty (no global user.name configured by HM)

### Requirement: GH_TOKEN Environment Variable

The system MUST export `GH_TOKEN` in the zsh shell environment on all Linux hosts. The value MUST be read from the sops secret `github/pat` (mounted at `/run/secrets/github/pat`) at shell initialization time.

The system MUST NOT export `GH_TOKEN` on Darwin hosts.

#### Scenario: GH_TOKEN is available in zsh on Linux

- GIVEN a Linux host with the configuration applied
- WHEN a new zsh session is started and `echo $GH_TOKEN` is executed
- THEN the output MUST be a non-empty string starting with `gho_`

#### Scenario: GH_TOKEN is not set on Darwin

- GIVEN the Darwin host mact2
- WHEN a new shell session is started and `echo $GH_TOKEN` is executed
- THEN the output MUST be empty

#### Scenario: GH_TOKEN gracefully handles missing secret

- GIVEN the sops secret file `/run/secrets/github/pat` does not exist (e.g., sops not yet initialized)
- WHEN zsh initializes
- THEN the shell MUST start without error
- AND `GH_TOKEN` MUST be unset

### Requirement: gh CLI Authenticated

The system MUST ensure `gh` CLI operations are authenticated on all Linux hosts. Authentication MUST work via `GH_TOKEN` environment variable combined with `programs.gh.gitCredentialHelper` (enabled by default), which sets `credential.helper` to `gh auth git-credential`.

The system MUST NOT materialize a `~/.git-credentials` file.

#### Scenario: gh auth status succeeds

- GIVEN a Linux host with the configuration applied and `GH_TOKEN` set
- WHEN `gh auth status` is executed
- THEN the command MUST exit with code 0
- AND the output MUST indicate authenticated status

#### Scenario: Git HTTPS operations are authenticated

- GIVEN a Linux host with the configuration applied
- WHEN `git clone https://github.com/glats/.nixos.git /tmp/test-clone` is executed
- THEN the clone MUST succeed without credential prompts
- AND the operation MUST be authenticated via `gh auth git-credential`

#### Scenario: No git-credentials file materialized

- GIVEN a Linux host with the configuration applied
- WHEN the home directory is inspected
- THEN `~/.git-credentials` MUST NOT exist (unless pre-existing from manual setup)

### Requirement: GitHub MCP Server Authenticated (No Regression)

The system MUST NOT introduce any regression in GitHub MCP server authentication. The MCP server reads `github/pat` from sops at exec time via a wrapper script — this path MUST remain unchanged.

#### Scenario: MCP server continues to work

- GIVEN a Linux host with the configuration applied
- WHEN `opencode` invokes the GitHub MCP server
- THEN GitHub API calls MUST succeed (no authentication errors)

### Requirement: Clean Up Unused Secret

The system MUST remove the unused `sops.secrets."git-credentials"` declaration from `hosts/rog/secrets.nix`. This secret is no longer needed because authentication uses `GH_TOKEN` + `gitCredentialHelper` instead.

#### Scenario: Flake check passes after removal

- GIVEN the `git-credentials` secret has been removed from `hosts/rog/secrets.nix`
- WHEN `nix flake check --no-build` is executed
- THEN the check MUST pass without errors

#### Scenario: No dangling references

- GIVEN the `git-credentials` secret has been removed
- WHEN the codebase is searched for references to `git-credentials`
- THEN no Nix files MUST reference `sops.secrets."git-credentials"`

## Host Applicability Summary

| Requirement | rog | thinkcentre | t14 | mact2 |
|-------------|-----|-------------|-----|-------|
| Git identity | ✅ | ✅ | ✅ | ❌ |
| GH_TOKEN | ✅ | ✅ | ✅ | ❌ |
| gh authenticated | ✅ | ✅ | ✅ | ❌ |
| MCP no regression | ✅ | ✅ | ✅ | ✅ |
| Cleanup secret | ✅ | N/A | N/A | N/A |
