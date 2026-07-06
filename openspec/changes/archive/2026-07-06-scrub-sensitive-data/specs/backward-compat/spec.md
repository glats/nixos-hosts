# Delta Spec: backward-compat

Domain for backward compatibility during the transition period between old identity names (`glats`/`jcuzmar`) and new identity names (`personal`/`work`). Ensures that deployments and configurations do not break during the rename rollout.

## ADDED Requirements

### Requirement: Old Sops Secret Paths Aliased

The sops-nix configuration MUST provide backward-compatible aliases for all renamed secret paths. For one transition cycle (at minimum), referencing an old path MUST resolve to the same decrypted content as the new path.

| Old Path | Aliased To |
|----------|-----------|
| `github/pat_jcuzmar` | `github/pat_work` |
| `gpg_glats_*` | `gpg_personal_*` |
| `gpg_jcuzmar_*` | `gpg_work_*` |

The alias mechanism SHOULD use `sops.secrets` with `sopsFile` pointing to the same encrypted file, or equivalent Nix-level path mapping.

#### Scenario: Old path resolves to same secret

- GIVEN the repository during the transition period (after Stage 2, before alias removal)
- WHEN a Nix expression references `config.sops.secrets."github/pat_jcuzmar".path`
- THEN the returned path MUST resolve to the same decrypted file as `config.sops.secrets."github/pat_work".path`
- AND both secrets MUST point to the same decrypted content

#### Scenario: New path works independently

- GIVEN the repository during the transition period
- WHEN a Nix expression references `config.sops.secrets."github/pat_work".path`
- THEN the path MUST resolve correctly WITHOUT depending on the old alias existing
- AND the secret MUST decrypt to the same value as before the rename

### Requirement: HM Activation Accepts Both Old and New Paths

Home Manager activation scripts that reference sops secrets MUST accept both old and new secret paths during the transition period. This prevents activation failures if any consumer file has not yet been updated.

#### Scenario: Activation succeeds with mixed references

- GIVEN the repository during the transition period where some files reference old paths and some reference new paths
- WHEN `home-manager switch` is executed
- THEN activation MUST exit with code 0
- AND all secrets, regardless of path, MUST be available to their consumers

### Requirement: No Runtime Breakage During Label Transition

No runtime services or configurations MUST break due to the label rename during the transition period. Specifically:

- GitHub MCP servers MUST continue to authenticate
- `gh` CLI MUST continue to function
- GPG signing MUST continue to work
- Git config MUST resolve correctly

#### Scenario: GitHub MCP server works during transition

- GIVEN the repository during the transition period (Stage 2 applied, old path aliases active)
- WHEN OpenCode invokes the GitHub MCP server
- THEN GitHub API calls MUST succeed with no authentication errors

#### Scenario: GPG signing works during transition

- GIVEN the repository during the transition period
- WHEN `gpg --list-secret-keys` is executed
- THEN the output MUST show the expected GPG keys
- AND the key availability MUST be identical to pre-rename behavior

### Requirement: One-Cycle Alias Lifetime

Backward-compatibility aliases MUST remain active for exactly one transition cycle -- long enough to verify all hosts build and operate correctly with the new paths, but removed afterward to avoid technical debt.

The removal of aliases MUST happen in a separate, deliberate commit after all hosts have been successfully rebuilt with the new paths.

#### Scenario: Alias is documented for removal

- GIVEN the repository after the transition cycle
- WHEN the codebase is searched for `TODO.*alias.*remove\|FIXME.*backward.*compat\|REMOVE.*old.*path` comments near sops alias declarations
- THEN such annotations MUST exist, marking the aliases for removal
- AND the annotations MUST include a condition for when removal is safe (e.g., "remove after all hosts rebuilt with new paths")

#### Scenario: No runtime dependency on aliases

- GIVEN the transition cycle is complete and aliases are removed
- WHEN `home-manager switch` is executed
- THEN activation MUST still succeed
- AND no references to old secret paths MUST remain in active Nix code

### Requirement: Edge Cases: Coexisting Old and New Paths

During the transition period, the following edge cases MUST be handled:

1. A host rebuilt during transition that has both old and new paths in its configuration MUST operate correctly
2. A host rebuilt after alias removal MUST NOT reference any old paths
3. Sops secrets edited during the transition MUST update both old and new key mappings

#### Scenario: Host rebuilt at midpoint of transition

- GIVEN a host with configuration that references a mix of old and new secret paths (some not yet renamed)
- WHEN `home-manager switch` runs
- THEN activation MUST succeed
- AND all secrets MUST resolve to their correct decrypted values

#### Scenario: Host rebuilt after alias removal

- GIVEN the backward-compat aliases have been removed
- WHEN `home-manager switch` runs
- THEN activation MUST succeed
- AND no warnings about deprecated secret paths MUST appear (all consumers use new paths)

### Requirement: No Alias Leak into Permanent Configuration

The alias mechanism MUST be implemented in a way that leaves zero permanent trace after cleanup. There MUST be no dangling sops secrets declarations, unused imports, or dead code after the transition cycle.

#### Scenario: Clean codebase after alias removal

- GIVEN the backward-compat aliases have been removed
- WHEN `grep -rn "pat_jcuzmar\|gpg_glats_\|gpg_jcuzmar_" modules/ home-linux/ home-darwin/ shared/` is executed
- THEN zero matches MUST be returned
- AND `nix flake check --no-build` MUST pass

## MODIFIED Requirements

None. All requirements in this domain are new.

## REMOVED Requirements

None.

## RENAMED Requirements

None.
