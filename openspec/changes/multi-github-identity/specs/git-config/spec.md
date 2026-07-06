# Delta Spec: Git Conditional Identity Config

## Overview

Refactor git identity configuration across all four hosts to support automatic identity switching via `programs.git.includes` with inline `contents`. Linux hosts default to glats (Redacted Name / personal@example.com) and switch to jcuzmar for work repos. macOS defaults to jcuzmar (work@example.com) and switches to glats for personal repos.

---

## ADDED Requirements

### GC-REQ-1: Linux Git Conditional Include for Work Repos

Linux hosts (rog, thinkcentre, t14) MUST include a conditional git config block for repos under `~/Work/**` that sets jcuzmar's work identity.

- **user.name**: MUST be "jcuzmar"
- **user.email**: MUST be "work@example.com"
- **condition**: MUST match `gitdir:~/Work/**`
- **implementation**: MUST use `programs.git.includes` with inline `contents` (NOT external file path)
- **File**: `home-linux/git.nix`

**Scenarios**:

```
SCENARIO: Linux user in work repo shows work identity
GIVEN  a Linux host (rog, thinkcentre, or t14)
  AND  the user has checked out a repo under ~/Work/
WHEN  they run `git config user.name`
THEN  the output MUST be "jcuzmar"

SCENARIO: Linux user in work repo shows work email
WHEN  they run `git config user.email`
THEN  the output MUST be "work@example.com"

SCENARIO: Linux user in personal repo shows default identity
GIVEN  a Linux host
  AND  the user has a repo under ~/dev/ (not under ~/Work/)
WHEN  they run `git config user.name`
THEN  the output MUST be "Redacted Name"
```

### GC-REQ-2: macOS Git Conditional Include for Personal Repos

macOS (mact2) MUST include a conditional git config block for repos under `~/Personal/**` that sets glats' personal identity.

- **user.name**: MUST be "Redacted Name"
- **user.email**: MUST be "personal@example.com"
- **condition**: MUST match `gitdir:~/Personal/**`
- **implementation**: MUST use `programs.git.includes` with inline `contents`
- **File**: `home-darwin/git.nix`

**Scenarios**:

```
SCENARIO: macOS user in personal repo shows personal identity
GIVEN  the macOS host (mact2)
  AND  the user has checked out a repo under ~/Personal/
WHEN  they run `git config user.name`
THEN  the output MUST be "Redacted Name"

SCENARIO: macOS user in personal repo shows personal email
WHEN  they run `git config user.email`
THEN  the output MUST be "personal@example.com"

SCENARIO: macOS user in work repo shows default work identity
GIVEN  the macOS host (mact2)
  AND  the user has a repo under ~/Work/ (or ~/dev/ not under ~/Personal/)
WHEN  they run `git config user.name`
THEN  the output MUST be "jcuzmar"
```

---

## MODIFIED Requirements

### GC-REQ-3: Linux Default Git Identity (MODIFIED)

Rename from implicit single-identity to explicit default-identity-with-override. The default `user.name` and `user.email` remain unchanged but MUST be explicitly recognized as the "glats" (personal) default.

Current `home-linux/git.nix`:
```nix
user.name = lib.mkForce "Redacted Name";
user.email = lib.mkForce "personal@example.com";
```

After: same defaults, plus the added includeIf block from GC-REQ-1. The `mkForce` MUST remain to prevent omarchy-nix's `omarchy.email_address` from overriding on t14.

- **File**: `home-linux/git.nix`

### GC-REQ-4: macOS Git Default Identity (MODIFIED)

Current `home-darwin/git.nix` has:
- Default identity: jcuzmar (work@example.com)
- External includeIf via `home.file.".git-falabella"` pointing to `~/.git-falabella`

After:
- Default identity MUST remain jcuzmar with email work@example.com
- The existing `includeIf."gitdir:~/Work/**".path = "~/.git-falabella"` MUST be replaced with `programs.git.includes` with inline `contents`
- The new includeIf for `~/Work/**` MUST set `user.name = "jcuzmar"` (same as default, so effectively a no-op — preserves the existing behavior structure)
- The existing GPG signing key in the includeIf block MUST remain but reference a sops secret path instead of hardcoded value

- **File**: `home-darwin/git.nix`

---

## REMOVED Requirements

### GC-REQ-5: Legacy External Git Config File (REMOVED)

The `home.file.".git-falabella"` entry in `home-darwin/git.nix` MUST be removed.

(Reason: Replaced by `programs.git.includes` with inline `contents`, which is the canonical HM approach. The external file approach predated HM's support for inline contents in `includes`.)

(Migration: Content moves inline into `programs.git.includes.contents`. No user-facing behavior change.)

**File**: `home-darwin/git.nix`

---

## EDGE CASES

| E-1 | includeIf path ordering | Git processes `includeIf` in declaration order. The default `user` block MUST appear first, then conditional includes. If omarchy-nix writes user config AFTER the includeIf blocks via `lib.mkForce`, the default may override the conditional. |
| E-2 | omarchy-nix interference (t14) | `lib.mkForce` on `user.name` and `user.email` is REQUIRED on t14. If omarchy-nix sets `user.email` after HM processes includes, the includeIf may not take effect. The `mkForce` on defaults must NOT propagate into includeIf blocks. |
| E-3 | New repo outside known trees | A repo cloned outside `~/Work/` or `~/Personal/` MUST use the host's default identity. This is the baseline behavior. |
| E-4 | Nested repo trees | If a repo under `~/Work/` also has a local `.git/config` override, local config MUST take precedence over the includeIf (standard git behavior). |
| E-5 | Git LFS on macOS | The existing `lfs.enable = true` in `home-darwin/git.nix` MUST be preserved. |
