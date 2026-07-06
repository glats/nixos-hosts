# Delta Spec: identity-label-rename

Domain for renaming the `glats` identity label to `personal` and `jcuzmar` identity label to `work` across all Nix attrset keys, sops secret paths, MCP wrapper binaries, and MCP config names. System usernames and SSH host configs are explicitly excluded.

## ADDED Requirements

### Requirement: Identity Attrset Keys Renamed

The `shared/git-identity.nix` file MUST rename the identity attrset root keys:

- `glats` MUST become `personal`
- `jcuzmar` MUST become `work`

All Nix files that reference `identities.glats.*` or `identities.jcuzmar.*` MUST be updated to reference `identities.personal.*` and `identities.work.*` respectively.

#### Scenario: git-identity.nix uses new key names

- GIVEN the repository after Stage 2
- WHEN `shared/git-identity.nix` is inspected
- THEN the file MUST contain a `personal` attrset key (NOT `glats`)
- AND the file MUST contain a `work` attrset key (NOT `jcuzmar`)
- AND the file MUST NOT contain `glats` or `jcuzmar` as top-level attrset keys

#### Scenario: Consumer files use new references

- GIVEN the repository after Stage 2
- WHEN `grep -r "identities\.glats" home-linux/ home-darwin/` is executed
- THEN zero matches MUST be returned
- AND `grep -r "identities\.jcuzmar" home-linux/ home-darwin/` MUST return zero matches

### Requirement: Sops Secret Paths Renamed

All sops secret paths containing identity labels MUST be renamed:

| Old Path | New Path |
|----------|----------|
| `github/pat_jcuzmar` | `github/pat_work` |
| `gpg_glats_*` | `gpg_personal_*` |
| `gpg_jcuzmar_*` | `gpg_work_*` |

The `.sops.yaml` rules file MUST be updated to include the new paths if it contains path-specific rules.

The encrypted secrets files MUST be edited via `sops edit` (NOT direct file edit) to rename keys.

#### Scenario: Nix sops declarations use new paths

- GIVEN the repository after Stage 2
- WHEN `grep -r "pat_jcuzmar\|gpg_glats_\|gpg_jcuzmar_" modules/base/sops.nix shared/sops.nix home-linux/gpg.nix home-darwin/gpg.nix home-darwin/github-mcp-server-wrapper.nix` is executed
- THEN zero matches MUST be returned
- AND the same files MUST reference `pat_work`, `gpg_personal_*`, or `gpg_work_*` as appropriate

#### Scenario: Sops encrypted files have renamed keys

- GIVEN the repository after Stage 2
- WHEN `secrets/shared/passwords.yaml` is examined (its encrypted structure, not decrypted values)
- THEN the key structure in the YAML mapping MUST NOT contain `pat_jcuzmar`
- AND keys for work GPG MUST use `gpg_work_` prefix

### Requirement: MCP Wrapper Binaries Renamed

The Nix derivations producing MCP wrapper binaries MUST rename:

- `github-mcp-server-glats` to `github-mcp-server-personal`
- `github-mcp-server-jcuzmar` to `github-mcp-server-work`

This applies to both Linux (`modules/features/services/github-mcp-server.nix`) and Darwin (`home-darwin/github-mcp-server-wrapper.nix`).

The wrapper binary names MUST be updated in flake-level package references if any exist.

#### Scenario: Linux MCP wrapper uses new binary name

- GIVEN the repository after Stage 2
- WHEN the `modules/features/services/github-mcp-server.nix` module is examined
- THEN the wrapper script name MUST be `github-mcp-server-personal` (NOT `github-mcp-server-glats`)
- AND the wrapper script name MUST be `github-mcp-server-work` (NOT `github-mcp-server-jcuzmar`)

#### Scenario: Darwin MCP wrapper uses new binary name

- GIVEN the repository after Stage 2
- WHEN `home-darwin/github-mcp-server-wrapper.nix` is examined
- THEN the wrapper script name MUST use `personal` or `work` (NOT `glats` or `jcuzmar`)

### Requirement: MCP Config Names Renamed

The OpenCode MCP server configuration in `shared/opencode/mcps-base.nix` MUST rename:

- `github-glats` to `github-personal`
- `github-jcuzmar` to `github-work`

OpenCode MUST auto-discover the renamed MCP configs and function correctly without manual configuration.

#### Scenario: MCP config keys use new names

- GIVEN the repository after Stage 2
- WHEN `shared/opencode/mcps-base.nix` is examined
- THEN the MCP server entries MUST use `github-personal` and `github-work` as config keys
- AND the config MUST NOT contain `github-glats` or `github-jcuzmar` as keys

### Requirement: Token Check Labels Renamed

The GitHub token check service (`modules/features/services/github-token-check.nix`) MUST rename its check token labels from `glats`/`jcuzmar` to `personal`/`work`.

#### Scenario: Token check labels use new names

- GIVEN the repository after Stage 2
- WHEN `modules/features/services/github-token-check.nix` is examined
- THEN check token label strings MUST NOT contain `glats` or `jcuzmar`
- AND labels MUST use `personal` or `work` instead

### Requirement: No Renames of System Usernames

The following MUST NOT be renamed:

- `users.users.glats` (Linux system user)
- `home.username = "glats"` (Linux Home Manager username)
- `home.username = primaryUser` resolving to `"jcuzmar"` (macOS Home Manager username)
- `/home/glats/` paths on Linux
- `/Users/jcuzmar/` paths on macOS
- Default username in `lib/mkHost.nix` (`username ? "glats"`)
- Default username in `lib/mkDarwinHost.nix` (`username ? "jcuzmar"`)

#### Scenario: System usernames unchanged on Linux

- GIVEN a Linux host (rog, thinkcentre, or t14) after Stage 2
- WHEN `users.users` is inspected in the NixOS configuration
- THEN `users.users.glats` MUST still exist
- AND `users.users.personal` or `users.users.work` MUST NOT exist

#### Scenario: Home directory paths unchanged

- GIVEN the repository after Stage 2
- WHEN `grep -rn "/home/glats" home-linux/ modules/` is executed
- THEN the output MUST contain the same paths as before (home directory references unchanged)
- AND no paths like `/home/personal` or `/home/work` MUST appear

### Requirement: SSH Remote Users Unchanged

SSH `User` directives in `home-linux/ssh.nix` and `home-darwin/ssh.nix` MUST NOT be renamed. These values (`glats` on Linux hosts, `jcuzmar` on mact2.local) are operating system usernames on remote machines, not identity labels.

#### Scenario: SSH User directives unchanged

- GIVEN the repository after Stage 2
- WHEN `home-linux/ssh.nix` and `home-darwin/ssh.nix` are examined
- THEN `User = "glats"` entries MUST remain as-is (remote OS username)
- AND `User = "jcuzmar"` entries MUST remain as-is (remote macOS username)
- AND SSH host aliases (`github-personal`, `github-enterprise`) MUST remain unchanged

### Requirement: Omarchy Theme Slug Preservation

The color theme slug `"glats"` in palette/theme configuration MUST NOT be renamed as part of this change. It is a cosmetic identifier with no PII implications.

#### Scenario: Theme slug unchanged

- GIVEN the repository after Stage 2
- WHEN Omarchy/hyprland theme configuration is inspected
- THEN the theme slug `"glats"` MUST remain as-is
- AND no build errors related to a missing theme slug MUST occur

## MODIFIED Requirements

None. All requirements in this domain are new.

## REMOVED Requirements

None.

## RENAMED Requirements

None.
