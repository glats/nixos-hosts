# Delta Spec: sops-key-management — Unified Key Management Tool

## ADDED Requirements

### REQ-SOPS-1: sops-rotate-keys MUST support an add-host subcommand

`sops-rotate-keys` MUST accept `add-host <name>` as a valid subcommand. The subcommand MUST perform the following operations in sequence:

1. `git pull` (update from remote)
2. `sops updatekeys secrets/user/opencode.yaml` (re-encrypt for all current hosts)
3. `git add secrets/user/opencode.yaml`
4. `git commit -m "Add host_<name> to user secrets"`
5. `git push`

**Scenario: sops-rotate-keys add-host t14 succeeds**

- **Given** the user is on a host with write access to the nixos repo
- **And** `sops` is configured and functional
- **When** the user runs `sops-rotate-keys add-host t14`
- **Then** `git pull` executes successfully
- **And** `sops updatekeys secrets/user/opencode.yaml` executes without error
- **And** `git add secrets/user/opencode.yaml` stages the file
- **And** a commit is created with message "Add host_t14 to user secrets"
- **And** `git push` pushes the commit to the remote
- **And** the script exits with code 0

**Scenario: sops-rotate-keys add-host with different hostname**

- **Given** the user runs `sops-rotate-keys add-host t14-new`
- **When** the subcommand executes
- **Then** the commit message is "Add host_t14-new to user secrets"
- **And** the commit message uses the provided `<name>` parameter, not a hardcoded value

**Scenario: add-host fails gracefully on git pull failure**

- **Given** the remote is unreachable
- **When** the user runs `sops-rotate-keys add-host somehost`
- **Then** `git pull` fails
- **And** the script exits with a non-zero exit code
- **And** no git add, commit, or push is attempted

### REQ-SOPS-2: add-host subcommand MUST appear in help and usage

The `add-host <name>` subcommand MUST be listed in `sops-rotate-keys` help output (both `help` subcommand and `--help`/`-h` flags).

**Scenario: help shows add-host**

- **Given** the script `sops-rotate-keys` has been updated
- **When** the user runs `sops-rotate-keys help`
- **Then** the output includes a line showing `add-host <name>` as an available command
- **And** the description explains its purpose (add a host key and re-encrypt)

**Scenario: --help shows add-host**

- **When** the user runs `sops-rotate-keys --help`
- **Then** the output includes `add-host <name>` in the command list

**Scenario: invalid subcommand still shows help with add-host listed**

- **Given** the user types an unknown subcommand like `sops-rotate-keys foobar`
- **When** the script exits with error
- **Then** the help output listing all commands includes `add-host <name>`

### REQ-SOPS-3: recovery guide MUST document add-host

The `recover` subcommand output (recovery guide) MUST be updated to reference `add-host <name>` instead of separate instructions for adding a host.

**Scenario: recovery guide references add-host subcommand**

- **When** the user runs `sops-rotate-keys recover`
- **Then** SCENARIO 3 ("Adding a new host to the configuration") references `sops-rotate-keys add-host <name>` as the procedure
- **And** any references to `sops-add-t14` are removed

## REMOVED Requirements

### REQ-SOPS-REMOVED-1: sops-add-t14 script MUST be deleted

The file `bin/sops-add-t14` MUST be removed from the repository. *(Reason: functionality merged into `sops-rotate-keys add-host <name>`. Migration: use `sops-rotate-keys add-host <name>` instead.)*

**Scenario: sops-add-t14 does not exist**

- **Given** the change has been applied
- **When** checking the `bin/` directory
- **Then** `sops-add-t14` is not present

### REQ-SOPS-REMOVED-2: sops-add-t14 MUST NOT be packaged

The `pkgs/nixos-scripts/default.nix` derivation MUST NOT include `sops-add-t14` in its `installPhase`. *(Reason: script deleted. Migration: nixos-scripts now includes `sops-rotate-keys` which provides `add-host`.)*

**Scenario: derivation excludes deleted script**

- **Given** `pkgs/nixos-scripts/default.nix` has been updated
- **When** the derivation is built
- **Then** `sops-add-t14` is NOT present in `$out/bin`
- **And** `sops-rotate-keys` IS present in `$out/bin`

## MODIFIED Requirements

### REQ-SOPS-MODIFIED-1: Existing subcommands MUST be preserved without change

The following existing subcommands in `sops-rotate-keys` MUST continue to function identically to pre-change behavior:

- `admin` — regenerate admin age key
- `host` — update host SSH-to-age key
- `all` — rotate both admin and host keys
- `recover` — show recovery instructions (updated per REQ-SOPS-3)
- `help` / `--help` / `-h` — show help (updated per REQ-SOPS-2)

**Scenario: admin subcommand unchanged**

- **When** the user runs `sops-rotate-keys admin`
- **Then** the admin key is regenerated
- **And** the output is identical to pre-change behavior
- **And** the script exits with code 0

**Scenario: host subcommand unchanged**

- **When** the user runs `sops-rotate-keys host`
- **Then** the host SSH key is read and converted to age
- **And** output matches pre-change behavior

**Scenario: all subcommand unchanged**

- **When** the user runs `sops-rotate-keys all`
- **Then** both admin and host keys are processed
- **And** output matches pre-change behavior

**Scenario: recover subcommand shows updated guide**

- **When** the user runs `sops-rotate-keys recover`
- **Then** the recovery guide is displayed
- **And** SCENARIO 3 mentions `sops-rotate-keys add-host <name>`
- **And** all other scenarios (lost admin key, SSH host key regenerated) remain unchanged
