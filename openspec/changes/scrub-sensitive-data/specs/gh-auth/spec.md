# Delta Spec: gh-auth (MODIFIED)

Domain modifications to the existing `gh-auth` spec to remove PII and update identity references after the `scrub-sensitive-data` change.

## MODIFIED Requirements

### Requirement: Git Identity on Linux Hosts

The system MUST set `user.name` and `user.email` in git configuration for user `glats` on all Linux hosts via Home Manager.

These values MUST resolve from the sops-encrypted `secrets/user/identities.yaml` file, NOT from plaintext Nix string literals. The identity values are decrypted at HM activation time and applied via git's `include.path` mechanism.

These values MUST NOT be set on Darwin hosts (mact2) -- Darwin identity is handled separately.

| Attribute | Source |
|-----------|--------|
| `user.name` | `personal.name` from `secrets/user/identities.yaml` |
| `user.email` | `personal.email` from `secrets/user/identities.yaml` |

#### Scenario: Git identity is set on Linux host

- GIVEN a Linux host (rog, thinkcentre, or t14) with the configuration applied
- WHEN `git config user.name` is executed
- THEN the output MUST match the `personal.name` value from the sops decrypted identities file
- AND `git config user.email` MUST match the `personal.email` value from the sops decrypted identities file

#### Scenario: Git identity values are NOT in Nix string literals

- GIVEN the repository after Stage 1
- WHEN `shared/git-identity.nix` is examined
- THEN the file MUST NOT contain any plaintext `name` or `email` string values
- AND the file MUST reference sops secret paths instead of literal strings

#### Scenario: Git identity is NOT set on Darwin host

- GIVEN the Darwin host mact2
- WHEN `git config --global user.name` is executed
- THEN the output MUST be empty (no global user.name configured by HM)
- OR the output MUST NOT originate from the Linux git-identity Nix module

### Requirement: Identity labels are personal/work, not glats/jcuzmar

All identity-related configuration throughout the repository MUST use `personal` and `work` labels instead of `glats` and `jcuzmar`. This applies to:

- Identity attrset keys in `shared/git-identity.nix`
- Sops secret paths (`github/pat_work`, `gpg_personal_*`, `gpg_work_*`)
- MCP wrapper binary names (`github-mcp-server-personal`, `github-mcp-server-work`)
- MCP config names (`github-personal`, `github-work`)
- Token check labels

#### Scenario: No glats/jcuzmar identity labels in Nix code

- GIVEN the repository after Stage 2
- WHEN `grep -rn "identities\.glats\|identities\.jcuzmar" home-linux/ home-darwin/ shared/` is executed
- THEN zero matches MUST be returned

#### Scenario: No glats/jcuzmar in sops secret paths

- GIVEN the repository after Stage 2
- WHEN `grep -rn "pat_jcuzmar\|gpg_glats_\|gpg_jcuzmar_" modules/ home-linux/ home-darwin/ shared/` is executed
- THEN zero matches MUST be returned (backward-compat aliases are excluded from this check)

#### Scenario: Personal/work labels used throughout

- GIVEN the repository after Stage 2
- WHEN `grep -rn "personal\|work" home-linux/git.nix home-darwin/git.nix shared/git-identity.nix` is executed
- THEN matches MUST exist showing the identity labels are in active use

### Requirement: GitHub MCP Server Authenticated (No Regression)

The system MUST NOT introduce any regression in GitHub MCP server authentication. The MCP server reads secrets from sops at exec time via wrapper scripts -- the secret paths used by the wrappers MUST be renamed to `personal`/`work` labels, but the decrypted values MUST remain the same.

The MCP config names in OpenCode MUST auto-discover the new `github-personal` and `github-work` names without manual reconfiguration.

#### Scenario: MCP server continues to work after rename

- GIVEN a Linux host with the Stage 2 configuration applied
- WHEN `opencode` invokes the GitHub MCP server (using the `github-personal` config)
- THEN GitHub API calls MUST succeed (no authentication errors)

#### Scenario: MCP server continues to work on Darwin

- GIVEN the Darwin host mact2 with the Stage 2 configuration applied
- WHEN `opencode` invokes the GitHub MCP server (using the `github-work` config)
- THEN GitHub API calls MUST succeed (no authentication errors)

## ADDED Requirements

### Requirement: System Usernames Preserved (No Regression)

The system MUST preserve all system-level username references after the label rename. The following MUST NOT change:

- `users.users.glats` on Linux hosts
- `home.username = "glats"` on Linux hosts
- `home.username = primaryUser` resolving to `"jcuzmar"` on macOS
- `/home/glats/` paths
- `/Users/jcuzmar/` paths
- SSH `User` directives in `home-linux/ssh.nix` and `home-darwin/ssh.nix`

#### Scenario: Linux system user unchanged after rename

- GIVEN a Linux host after Stage 2 configuration applied
- WHEN `id glats` is executed
- THEN the user MUST exist with the same UID and home directory as before the rename

#### Scenario: macOS system user unchanged after rename

- GIVEN the Darwin host mact2 after Stage 2 configuration applied
- WHEN `id jcuzmar` is executed on macOS
- THEN the user MUST exist with the same home directory as before the rename

#### Scenario: SSH configs unchanged

- GIVEN the repository after Stage 2
- WHEN `grep "User =" home-linux/ssh.nix home-darwin/ssh.nix` is executed
- THEN the user values MUST be unchanged (`glats` and `jcuzmar` as remote OS usernames, NOT `personal`/`work`)

## Host Applicability Summary

| Requirement | rog | thinkcentre | t14 | mact2 |
|-------------|-----|-------------|-----|-------|
| Git identity (from sops) | ✅ | ✅ | ✅ | ❌ (separate work identity) |
| Label rename | ✅ | ✅ | ✅ | ✅ |
| MCP no regression | ✅ | ✅ | ✅ | ✅ |
| System username preserved | ✅ | ✅ | ✅ | ✅ |

## REMOVED Requirements

None.

## RENAMED Requirements

None.
