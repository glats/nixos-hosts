# github-cli-account-priority Specification

## Purpose

Define the host policy for the active GitHub CLI account while preserving user-managed multi-account authentication and explicit MCP account selection.

## Requirements

### Requirement: Host-specific GitHub CLI active account

After Home Manager activation, the system MUST select the configured existing `github.com` account as the active GitHub CLI account. The configured account SHALL be `glats` on `rog`, `t14`, and `thinkcentre`, and `jcuzmar-Falabella_FTC` on `mact2`.

#### Scenario: Linux host selects personal account — hosts: rog, t14, thinkcentre

- GIVEN `glats` is authenticated for `github.com`
- WHEN Home Manager activation completes on a Linux host
- THEN `gh auth status --active --hostname github.com` reports `glats` as active

#### Scenario: Darwin host selects work account — hosts: mact2

- GIVEN `jcuzmar-Falabella_FTC` is authenticated for `github.com`
- WHEN Home Manager activation completes on mact2
- THEN `gh auth status --active --hostname github.com` reports `jcuzmar-Falabella_FTC` as active

### Requirement: Existing GitHub CLI accounts are preserved

The system MUST preserve all existing accounts and their user-managed credentials under the single `github.com` host. Selecting an active account MUST change only the active-account selection and MUST NOT remove, replace, or reauthenticate an account.

#### Scenario: Both accounts remain available — hosts: rog, t14, thinkcentre, mact2

- GIVEN `glats` and `jcuzmar-Falabella_FTC` are authenticated for `github.com`
- WHEN the host-specific account selection runs
- THEN both accounts remain listed by `gh auth status`
- AND only the active indication reflects the host policy

### Requirement: Absent authentication is a non-interactive no-op

The system MUST make no account-selection attempt requiring authentication when the configured account is absent. Activation MUST succeed without prompting, starting a login flow, or changing the available account state.

#### Scenario: Target account has not been authenticated — hosts: rog, t14, thinkcentre, mact2

- GIVEN the configured active account is absent from local GitHub CLI authentication
- WHEN Home Manager activation completes
- THEN activation succeeds without interactive GitHub authentication
- AND existing GitHub CLI accounts remain unchanged

### Requirement: Explicit MCP account selection remains independent

The `github-personal` and `github-work` MCP integrations MUST retain their explicit account selection and MUST NOT depend on the active GitHub CLI account. Their wrapper and registration contracts SHALL remain unchanged.

#### Scenario: Active account differs from MCP target — hosts: rog, t14, thinkcentre, mact2

- GIVEN the host policy selects either GitHub CLI account as active
- WHEN either GitHub MCP integration resolves its token
- THEN it resolves the account explicitly assigned to that integration
- AND changing the active account does not alter that assignment

### Requirement: GitHub CLI authentication state remains user-managed

The system MUST NOT introduce fake GitHub hostnames, declarative ownership of `hosts.yml`, token/PAT management, or account-specific configuration directories. Both accounts MUST remain associated with `github.com`.

#### Scenario: Managed configuration is evaluated — hosts: rog, t14, thinkcentre, mact2

- GIVEN the host configuration is evaluated
- WHEN the GitHub CLI account-priority configuration is inspected
- THEN no fake host or declarative `hosts.yml` configuration is present
- AND no token or PAT is introduced by this capability

### Requirement: Cross-platform configuration evaluation

The account-priority capability MUST evaluate successfully for every supported host without platform-specific account-policy drift.

#### Scenario: Flake evaluation covers all hosts — hosts: rog, t14, thinkcentre, mact2

- GIVEN the change is present in the flake
- WHEN `nix flake check --no-build` runs
- THEN evaluation succeeds for rog, t14, thinkcentre, and mact2
