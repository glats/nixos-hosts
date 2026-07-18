# Gentle AI Update Workflow

This document describes how to update Gentle AI assets in this NixOS configuration.

## Overview

The AI assets are split into independent, per-source derivations:

| Derivation | Source | Output path |
|------------|--------|-------------|
| `gentle-ai-assets` | `gentle-ai-src` | `$out/share/gentle-ai/` |
| `caveman-assets` | `caveman-src` | `$out/share/caveman/` |
| `ponytail-assets` | `ponytail-src` | `$out/share/ponytail/` |
| `local-ai-assets` | local repo | `$out/share/local-ai/` |

Tool-specific activation scripts (OpenCode, Claude Code) merge skills, commands,
and AGENTS.md/CLAUDE.md fragments from all configured sources at activation time.

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
# Build each asset derivation
nix build .#gentle-ai-assets
nix build .#caveman-assets
nix build .#ponytail-assets

# Verify flake syntax
nix flake check

# Format all .nix files
format-nix
```

## Verification Checklist

- [ ] `nix build .#gentle-ai-assets` succeeds
- [ ] `nix build .#caveman-assets` succeeds
- [ ] `nix build .#ponytail-assets` succeeds
- [ ] All upstream skills deploy to `~/.config/opencode/skills/`
- [ ] All caveman skills deploy to `~/.config/opencode/skills/`
- [ ] All ponytail skills deploy to `~/.config/opencode/skills/`
- [ ] Local skills override upstream (`skills/audit-providers-models/SKILL.md` is local)
- [ ] `~/.config/opencode/AGENTS.md` contains content from all `agentsMdSources`
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
# Revert package and shared changes
git checkout HEAD -- pkgs/gentle-ai-assets/default.nix
git checkout HEAD -- pkgs/caveman-assets/default.nix
git checkout HEAD -- pkgs/ponytail-assets/default.nix
git checkout HEAD -- lib/packages.nix
git checkout HEAD -- overlays/linux.nix overlays/darwin.nix

# Rebuild
nix build .#gentle-ai-assets && nix flake check
```

## Principles

1. **Always use upstream plugins** — If there's a bug, PR to upstream
2. **Per-source derivations are independent** — No monolithic vanilla/layered chain
3. **Local skills live in `local-ai-assets`** — Never modify upstream source pins directly
4. **engram.ts is the only local plugin** — Doesn't exist upstream
