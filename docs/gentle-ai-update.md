# Gentle AI Update Workflow

This document describes how to update Gentle AI assets in this NixOS configuration.

## Overview

The configuration uses a layered approach:
- **vanilla**: Pure upstream copy (no local modifications)
- **gentle-ai-assets**: Vanilla base + local skill overrides + local persona rules
- **engram.ts**: Local-only plugin (does not exist upstream)

## Update Steps

### Step 1: Check Latest Release

```bash
gh release list --repo Gentleman-Programming/gentle-ai
```

Note the latest version tag (e.g., `v1.22.0`).

### Step 2: Verify Current Binary Version

Check `pkgs/gentle-ai/default.nix`:
```nix
version = "1.21.0";
```

The assets should match this version. If updating assets, also update binary.

### Step 3: Update Source Pin

In `flake.nix`, update the tag:

```nix
gentle-ai-src = {
  url = "github:Gentleman-Programming/gentle-ai/v1.22.0";
  flake = false;
};
```

In `pkgs/gentle-ai/default.nix`, update version if updating binary.

### Step 4: Re-lock and Sync Marker

```bash
# Update flake.lock
nix flake lock --update-input gentle-ai-src

# Update sync marker
echo "Synced from gentle-ai v1.22.0 on $(date -Iseconds)" > modules/home/opencode/.last-sync
```

### Step 5: Build and Verify

```bash
# Build vanilla (pure upstream)
nix build .#gentle-ai-assets-vanilla

# Build layered assets (vanilla + local overrides)
nix build .#gentle-ai-assets

# Verify flake syntax
nix flake check

# Format all .nix files
format-nix
```

## Verification Checklist

- [ ] `nix build .#gentle-ai-assets-vanilla` succeeds
- [ ] `nix build .#gentle-ai-assets` succeeds
- [ ] All upstream plugins present in output (`opencode/plugins/`)
- [ ] Local skills override upstream (`skills/caveman/SKILL.md` is local)
- [ ] `nix flake check` exits 0
- [ ] `format-nix` passes

## Version Synchronization

| Component | Version | Notes |
|-----------|---------|-------|
| Binary (`pkgs/gentle-ai`) | v1.21.0 | Manually updated |
| Source (`flake.nix`) | v1.21.0 | Must match binary |
| Sync marker (`.last-sync`) | v1.21.0 | Updated manually |

## Rollback

If something goes wrong:

```bash
# Restore original files
git checkout HEAD -- pkgs/gentle-ai-assets/default.nix
git checkout HEAD -- pkgs/gentle-ai-assets/vanilla.nix
git checkout HEAD -- flake.nix
git checkout HEAD -- modules/base/overlays.nix

# Remove vanilla.nix if it was created
rm -f pkgs/gentle-ai-assets/vanilla.nix

# Rebuild
nix build .#gentle-ai-assets && nix flake check
```

## Principles

1. **Always use upstream plugins** — If there's a bug, PR to upstream
2. **Vanilla = pure upstream** — No local modifications
3. **Layered = vanilla + local skills/PERSONA only** — No plugin layering
4. **engram.ts is the only local plugin** — Doesn't exist upstream