# atlassian-rovo-mcp Specification

## Purpose

Define the official Atlassian Rovo MCP registration for mact2, the removal contract for the
superseded sooperset stack, the retention contract for the legacy encrypted secrets, and the
operational runbook obligations.

## Requirements

### Requirement: Official remote registration

The darwin extra-MCP inventory MUST contain an enabled `atlassian` entry with
`type = "remote"` and `url = "https://mcp.atlassian.com/v2/mcp"`. The entry MUST use only
`type`, `url`, and `enabled` keys (no `command`, `environment`, `timeout`, `headers`, or `oauth`
block).

#### Scenario: Evaluated mact2 entry has the official shape [hosts: mact2]

- GIVEN the evaluated `homeConfigurations.mact2` MCP inventory
- WHEN the `atlassian` entry is inspected
- THEN its type is `remote`, its url is `https://mcp.atlassian.com/v2/mcp`, and enabled is true
- AND it contains no other keys

#### Scenario: No local command remains [hosts: mact2]

- GIVEN the evaluated mact2 MCP inventory
- WHEN the `atlassian` entry is inspected
- THEN it has no `command` attribute and no `environment` proxy-scrub merge

### Requirement: Sooperset stack removal

The darwin configuration MUST NOT reference the community `mcp-atlassian` stack: no
`atlassian-mcp-server` wrapper derivation, no import of a wrapper module, and no sops secret
declarations for `opencode/atlassian_jira_url`, `opencode/atlassian_username`,
`opencode/atlassian_api_token`, `opencode/confluence_url`, or `opencode/confluence_pat`.

#### Scenario: Wrapper and import are gone [hosts: mact2]

- GIVEN the darwin config tree after the change
- WHEN `darwin/home/atlassian-mcp-wrapper.nix` and import references are searched
- THEN the wrapper file does not exist and no module imports it

#### Scenario: Secret declarations are pruned [hosts: mact2]

- GIVEN the evaluated `homeConfigurations.mact2` sops secrets
- WHEN the five removed keys are looked up
- THEN none is present, and unrelated secrets remain unchanged

### Requirement: Legacy secrets retention

`secrets/user/atlassian.yaml` and the `secrets/user/atlassian.yaml` creation rule in
`.sops.yaml` MUST remain byte-identical to their pre-change state, retained as inert ciphertext
for a potential future API-token (JSM) setup.

#### Scenario: Encrypted artifacts untouched [hosts: mact2]

- GIVEN the change diff
- WHEN `secrets/user/atlassian.yaml` and `.sops.yaml` are inspected
- THEN no modification exists for either file

### Requirement: Operational runbook

`docs/atlassian-rovo-mcp.md` MUST document: the first-time OAuth 2.1 login on mact2 with the
Falabella Atlassian account; verification via `opencode mcp list`; removal of the out-of-Nix
sooperset artifacts (`uv tool uninstall mcp-atlassian`, deleting
`~/.local/bin/mcp-atlassian-wrapper.py`); the human-only confirmation step
(`sops -d secrets/user/atlassian.yaml` — agents must never decrypt); the JSM tools
API-token-only limitation; and Netskope/rollback troubleshooting.

#### Scenario: A user can complete migration [hosts: mact2]

- GIVEN the runbook
- WHEN the user follows it on mact2 after rebuild
- THEN OAuth login, verification, and uninstall steps are all present and ordered

### Requirement: Cross-tool propagation

The official remote entry MUST reach both OpenCode and Claude Code on mact2 through the existing
shared consumers, with Claude Code receiving `{ type = "http"; url = "https://mcp.atlassian.com/v2/mcp" }`.

#### Scenario: Consumers require no edits [hosts: mact2]

- GIVEN `shared/opencode/runtime-config.nix` and `shared/claude-code.nix`
- WHEN the change diff is inspected
- THEN neither file is modified

### Requirement: Scope boundary

The change MUST NOT add the official server to Linux hosts, enable API-token auth, pin
`cloudId`/project/space, or delete encrypted secret artifacts.

#### Scenario: Scope stays darwin-only and additive-minimal [hosts: mact2]

- GIVEN the change diff
- WHEN Linux host configs and secret files are inspected
- THEN no Linux MCP entry, no token header, no cloudId pin, and no secret deletion exists

