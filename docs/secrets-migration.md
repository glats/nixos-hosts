# Secrets Migration Guide

## Overview

This document describes how to merge macOS-specific secrets into the unified NixOS secrets layout.

## Current State

- **NixOS secrets**: `secrets/user/api_keys.yaml` (encrypted with sops)
- **macOS secrets**: `/home/glats/Work/nix-macos/.secrets/user.yaml` (encrypted with sops)

## macOS-Specific Secrets to Add

The following secrets exist in the macOS repo but are NOT in the NixOS `secrets/user/api_keys.yaml`:

```
opencode/atlassian_jira_url
opencode/atlassian_username
opencode/atlassian_api_token
opencode/confluence_url
opencode/confluence_pat
github/token
```

## Migration Steps

### Option 1: Manual Merge (Recommended)

1. Decrypt the macOS secrets file:
   ```bash
   cd /home/glats/Work/nix-macos
   sops -d .secrets/user.yaml
   ```

2. Decrypt the NixOS secrets file:
   ```bash
   cd /home/glats/.nixos
   sops -d secrets/user/api_keys.yaml
   ```

3. Copy the macOS-specific keys into the NixOS file structure.

4. Re-encrypt with the unified `.sops.yaml`:
   ```bash
   sops secrets/user/api_keys.yaml
   ```

### Option 2: Using sops merge

If both files use the same encryption key (admin_glats), you can use sops merge:

```bash
cd /home/glats/.nixos
sops --merge secrets/user/api_keys.yaml /home/glats/Work/nix-macos/.secrets/user.yaml
```

## SOPS Configuration

The unified `.sops.yaml` now includes the mact2 host key:

```yaml
keys:
  - &admin_glats age1j4mxejwmktekgf24sju92ryayh5jlmv4ldxj62e2srwghpkpuujscct9lt
  - &host_rog age1q46qlf4kt0pc255nrl4r24m5hnvqwqf9wd8n6206f0zg95v6993qvd9cr8
  - &host_thinkcentre age1uhv0z8e04q2385wlrn0vgd237ts2exea375yr4yeqwx5v9zgw9esdg3rsn
  - &host_mact2 age1ngeetv5mnt8ax30tmm6799qs2779905v0jafpywuydrvw2sz7yds7rlp5z
```

## Verification

After merging, verify the secrets are accessible:

```bash
# On Linux (rog/thinkcentre)
sops -d secrets/user/api_keys.yaml | grep atlassian

# On macOS (mact2)
sops -d secrets/user/api_keys.yaml | grep atlassian
```
