# Delta Spec: Secrets Management

## Overview

Add new sops-nix secret entries for jcuzmar's GitHub PAT and GPG key fingerprint. Move the GPG signing key from plaintext hardcoded value in `home-darwin/git.nix` to a sops-referenced path. Remove unused `git-credentials.yaml`.

---

## ADDED Requirements

### SEC-REQ-1: jcuzmar GitHub PAT Secret

A new sops secret `github/pat_jcuzmar` MUST be added to `secrets/shared/passwords.yaml`, encrypted for all four hosts (rog, thinkcentre, t14, mact2).

- **sops file**: `secrets/shared/passwords.yaml`
- **secret path**: `github.pat_jcuzmar`
- **encrypted for**: all four host age keys
- **declared in**: `shared/sops.nix` (shared module, imported by both Linux and Darwin)
- **mode**: `0400`

**Scenarios**:

```
SCENARIO: jcuzmar PAT is readable on any host
GIVEN  any host (rog, thinkcentre, t14, or mact2)
  AND  sops-nix is properly configured
WHEN  the secret is deployed
THEN  the file at config.sops.secrets."github/pat_jcuzmar".path MUST exist
  AND  be readable by the user
  AND  contain the correct jcuzmar PAT value
```

### SEC-REQ-2: GPG Key Fingerprint Secret

A new sops secret `github/gpg_key_fingerprint` MUST be added to `secrets/shared/passwords.yaml`, encrypted for all macOS-affected hosts (mact2).

- **sops file**: `secrets/shared/passwords.yaml`
- **secret path**: `github.gpg_key_fingerprint`
- **encrypted for**: mact2 (and optionally Linux hosts for future use)
- **declared in**: `home-darwin/sops.nix` (macOS-specific)
- **mode**: `0400`

**Scenarios**:

```
SCENARIO: GPG key fingerprint is available via sops path on macOS
GIVEN  the macOS host (mact2)
  AND  sops-nix has deployed the secret
WHEN  the git config references config.sops.secrets."github/gpg_key_fingerprint".path
THEN  the file MUST exist
  AND  contain the full GPG key fingerprint string
```

---

## MODIFIED Requirements

### SEC-REQ-3: GPG Signing Key Reference (MODIFIED)

Current: GPG fingerprint is hardcoded in plaintext in `home-darwin/git.nix`:
```nix
signing.key = "B658D64F6FDBCFD1EBA53509A1D4ECB0118566C8";
```

After: The signing key MUST reference the sops secret path:
```nix
signing.key = builtins.readFile config.sops.secrets."github/gpg_key_fingerprint".path;
```

OR use `settings.user.signingkey` within the includeIf contents, referencing the sops path.

- **File**: `home-darwin/git.nix`

The existing `home.file.".git-falabella"` block (which also contains the signing key inline) is being removed per GC-REQ-5, so the signing key MUST move to HM's `programs.git.includes.contents` or `programs.git.signing.key`.

### SEC-REQ-4: Shared Sops Module Declarations (MODIFIED)

Current `shared/sops.nix` declares `github/pat` only.

After: MUST also declare:
- `github/pat_jcuzmar` — new secret, same sopsFile (`secrets/shared/passwords.yaml`)
- `github/gpg_key_fingerprint` — new secret (or in darwin-specific sops.nix)

- **File**: `shared/sops.nix` (and/or `home-darwin/sops.nix`)

**Scenarios**:

```
SCENARIO: Linux hosts have both PATs available
GIVEN  a Linux host (rog, thinkcentre, t14)
WHEN  the system builds
THEN  config.sops.secrets."github/pat".path MUST resolve
  AND  config.sops.secrets."github/pat_jcuzmar".path MUST resolve

SCENARIO: macOS has all three github secrets
GIVEN  the macOS host (mact2)
WHEN  the system builds
THEN  config.sops.secrets."github/pat".path MUST resolve
  AND  config.sops.secrets."github/pat_jcuzmar".path MUST resolve
  AND  config.sops.secrets."github/token".path MUST resolve (existing, from atlassian.yaml)
  AND  config.sops.secrets."github/gpg_key_fingerprint".path MUST resolve
```

---

## REMOVED Requirements

### SEC-REQ-5: git-credentials.yaml (REMOVED)

The file `secrets/shared/git-credentials.yaml` MUST be removed after confirming it is not consumed by any Nix module.

(Reason: Unused opaque credential blob. No Nix module references `git-credentials.yaml` in any sops declaration. It exists only as an encrypted file with no consumers.)

(Migration: None — no consumers. If future need arises, can re-add with proper sops declarations.)

**Scenarios**:

```
SCENARIO: git-credentials.yaml is not referenced by any module
GIVEN  the entire nix config tree
WHEN  searching for references to "git-credentials.yaml"
THEN  no module SHOULD reference this file
```

---

## EDGE CASES

| E-1 | GPG key fingerprint file content | `builtins.readFile` includes trailing newline. The fingerprint value in sops MUST NOT have a trailing newline, OR the signing key reference MUST strip it. Verify that the fingerprint from sops with or without newline works as a git `signingkey` value. |
| E-2 | Secret decryption on rebuild | If a new secret is added to `passwords.yaml` but not re-encrypted for a specific host's age key, that host's build will fail. All new secrets MUST be encrypted for all target hosts before deployment. |
| E-3 | macOS keeps existing github/token | The existing `github/token` secret (from `atlassian.yaml`, used by the macOS MCP wrapper) MUST be preserved. It is a different token (jcuzmar's GitHub token, used by macOS-specific tools) from `github/pat_jcuzmar`. |
