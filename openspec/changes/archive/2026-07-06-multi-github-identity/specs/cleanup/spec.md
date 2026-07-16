# Delta Spec: Cleanup

## Overview

Remove legacy artifacts left behind by the previous ad-hoc identity management approach. Two items are removed: the external git config file (`~/.git-[redacted]`) managed via `home.file`, and the unused `git-credentials.yaml` sops file.

---

## REMOVED Requirements

### CLN-REQ-1: Legacy home.file Entry (REMOVED)

The `home.file.".git-[redacted]"` entry in `home-darwin/git.nix` MUST be removed.

(Reason: Already specified in GC-REQ-5. Listed here for tracking completeness in the cleanup phase.)

**File**: `home-darwin/git.nix`

**Scenarios**:

```
SCENARIO: ~/.git-[redacted] no longer exists after rebuild
GIVEN  the macOS host (mact2)
  AND  the home-manager generation has been rebuilt with the changes
WHEN  checking for the existence of ~/.git-[redacted]
THEN  the file MUST NOT exist
```

### CLN-REQ-2: git-credentials.yaml Removal (REMOVED)

The file `secrets/shared/git-credentials.yaml` MUST be deleted from the repository.

(Reason: Already specified in SEC-REQ-5. Listed here for tracking completeness.)

**File**: `secrets/shared/git-credentials.yaml`

**Scenarios**:

```
SCENARIO: git-credentials.yaml is removed from repository
GIVEN  the repository root
WHEN  listing secrets/shared/ directory contents
THEN  git-credentials.yaml MUST NOT appear
```

---

## NON-FUNCTIONAL REQUIREMENTS (Cross-Domain)

### NFR-1: Build Integrity

`nix flake check --no-build` MUST pass for all four hosts (rog, thinkcentre, t14, mact2) after ALL phases are complete.

### NFR-2: Rollback Completeness

Every phase (Secrets+Git, MCP, Cleanup) MUST be independently revertible. A `git revert` of the feature commit MUST restore all hosts to working state.

### NFR-3: No Secret Exposure

No plaintext tokens, PATs, API keys, or GPG fingerprints MUST appear in any Nix file or git-tracked config. All secrets MUST only exist in encrypted sops files.

### NFR-4: Cross-Platform Consistency

The behavior on macOS (default jcuzmar, override glats) MUST be the logical inverse of the behavior on Linux (default glats, override jcuzmar). Every Linux scenario MUST have a corresponding macOS scenario with identities swapped.

---

## OVERALL ACCEPTANCE CRITERIA

| ID | Criterion | Phase | Verification Method |
|----|-----------|-------|-------------------|
| AC-1 | `git config user.name` shows glats identity in `~/dev/*` on Linux | 1 | Manual: `cd ~/dev/* && git config user.name` |
| AC-2 | `git config user.name` shows jcuzmar identity in `~/Work/*` on Linux | 1 | Manual: `cd ~/Work/* && git config user.name` |
| AC-3 | `git config user.name` shows jcuzmar identity in `~/dev/*` on macOS | 1 | Manual: `cd ~/dev/* && git config user.name` |
| AC-4 | `git config user.name` shows glats identity in `~/Personal/*` on macOS | 1 | Manual: `cd ~/Personal/* && git config user.name` |
| AC-5 | MCP entry `github-glats` connects and uses glats PAT | 2 | Manual: MCP connection test |
| AC-6 | MCP entry `github-jcuzmar` connects and uses jcuzmar PAT | 2 | Manual: MCP connection test |
| AC-7 | `nix flake check --no-build` passes for all four hosts | 3 | Automated: `nix flake check --no-build` |
| AC-8 | `~/.git-[redacted]` no longer exists on mact2 | 3 | Manual: `ls -la ~/.git-[redacted]` (should fail) |
| AC-9 | `git-credentials.yaml` removed from repo | 3 | Manual: check git status |
| AC-10 | GPG signing still works on mact2 (commits are signed) | 1 | Manual: `git log --show-signature -1` |
