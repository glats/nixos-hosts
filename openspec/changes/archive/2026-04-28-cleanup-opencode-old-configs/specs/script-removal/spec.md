# Delta for Script Removal

## Purpose

Define which `bin/` scripts MUST be removed and ensure no references to them remain in the codebase.

## REMOVED Requirements

### Requirement: Obsolete Script Removal

(Reason: All four scripts are broken or bypass established conventions — they serve no functional purpose.)

The following scripts MUST be deleted from the `bin/` directory:

| Script | Reason |
|--------|--------|
| `bin/sync-opencode-remote` | References missing `opencode.json.base`, non-functional |
| `bin/sync-opencode-mac.sh` | Uses outdated API model mappings (deepinfra → github-copilot) |
| `bin/setup-opencode-keychain-mac.sh` | All providers removed from config, no longer useful |
| `bin/gentle-ai-tui` | Downloads latest release directly, bypasses Nix versioning |

#### Scenario: All four scripts are deleted

- GIVEN the `bin/` directory contains the four obsolete scripts
- WHEN the change is applied
- THEN `bin/sync-opencode-remote` no longer exists
- AND `bin/sync-opencode-mac.sh` no longer exists
- AND `bin/setup-opencode-keychain-mac.sh` no longer exists
- AND `bin/gentle-ai-tui` no longer exists

#### Scenario: No references to deleted scripts remain

- GIVEN the four scripts have been deleted
- WHEN searching the codebase for references to their filenames
- THEN no `.nix`, `.sh`, or markdown files reference them
- AND no host configuration imports or calls them

#### Scenario: Active scripts are preserved

- GIVEN the cleanup is applied
- WHEN listing the `bin/` directory
- THEN `bin/opencode-worktree` still exists
- AND `bin/oc-wt` still exists
- AND all other non-targeted scripts remain untouched
