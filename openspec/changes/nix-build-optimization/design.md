# Design: Nix Build Optimization

## Technical Approach

Additive changes to 3 files: `modules/base/nix.nix` (nix.settings + nix.registry), `darwin/cachix.nix` (cache parity), and `bin/nixos-build` (nh wiring). All changes are backward-compatible — `mkDefault` allows per-host overrides, `--raw` flag preserves `nixos-rebuild` escape hatch.

## Architecture Decisions

### Decision: Parallelism limits placement

| Option | Tradeoff | Decision |
|--------|----------|----------|
| New `modules/base/build-parallelism.nix` | Clean separation but adds import churn across 3 hosts + profile | **Rejected** |
| Extend `modules/base/nix.nix` | Single file for all `nix.settings`; already imported by all hosts via `profiles/base.nix` (rog/thinkcentre) or directly (t14) | **Chosen** |

**Rationale**: `nix.nix` already owns `nix.settings` (substituters, http2, download tuning). Adding `max-jobs`, `cores`, `keep-outputs`, `trusted-substituters` here keeps all nix.conf knobs in one place. No new imports needed.

### Decision: `nix.registry` is NixOS-only

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Home Manager `nix.registry` | MCP confirmed: no HM option exists for `nix.registry` | **Rejected** |
| NixOS `nix.registry.<name>.flake` in `nix.nix` | Verified via MCP: `nix.registry` is a NixOS option (attribute set of submodule). Requires `inputs` in function args. | **Chosen** |

**Rationale**: `nix.registry` is system-wide flake registry. Must be in NixOS module. Add `inputs` to `nix.nix` function signature to access `inputs.nixpkgs`.

### Decision: `nh os` as default with `--raw` fallback

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Replace `nixos-rebuild` entirely | Cleaner but risky if `nh` has edge cases | **Rejected** |
| `nh os` default + `--raw` flag for `nixos-rebuild` | `programs.nh.flake` already sets `NH_FLAKE` env var → `nh os switch` auto-detects hostname. `--raw` keeps escape hatch. | **Chosen** |

**Rationale**: `nh` is already enabled (`modules/base/nh.nix`) with `flake = /home/glats/.nixos`. The `NH_FLAKE` env var is auto-set, so `nh os switch` needs no arguments. `--raw` flag preserves backward compatibility.

### Decision: Darwin cachix sync strategy

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Copy linux `cachix.nix` verbatim | Darwin has `nix.enable = false` (Determinate) — some settings may conflict | **Rejected** |
| Add missing caches + fastly mirrors to darwin `cachix.nix` | Surgical: add aseipp fastly mirrors (mkBefore) + 3 missing cachix entries (nixpkgs-unfree, flox, nixpkgs) with their public keys | **Chosen** |

**Rationale**: Darwin uses Determinate Nix (`nix.enable = false`). The `nix.settings` in `darwin/cachix.nix` is additive (mkAfter). We mirror the same mkAfter list from linux + add mkBefore fastly mirrors.

## Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    modules/base/nix.nix                         │
│                                                                 │
│  nix.settings:                                                  │
│    max-jobs = mkDefault 1     ← prevents OOM                   │
│    cores = 0                  ← all cores per job (default)     │
│    keep-outputs = true        ← survive GC                     │
│    trusted-substituters       ← mirror of all substituters      │
│                                                                 │
│  nix.registry.nixpkgs.flake = inputs.nixpkgs  ← locked tree   │
└─────────────────────────────────────────────────────────────────┘
         │                           │
         │ (imported via             │ (imported via
         │  profiles/base.nix)       │  darwin/default.nix)
         ▼                           ▼
┌─────────────────┐       ┌──────────────────────────┐
│ rog/thinkcentre │       │ darwin/cachix.nix         │
│ (via server.nix)│       │ + fastly mirrors          │
│                 │       │ + nixpkgs-unfree/flox/    │
│ t14 (direct     │       │   nixpkgs caches          │
│  import)        │       └──────────────────────────┘
└─────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────┐
│                    bin/nixos-build                              │
│                                                                 │
│  default:  nh os {switch,boot,test}                             │
│  --raw:    sudo nixos-rebuild {switch,boot,test} --flake ...    │
│  upgrade:  nh os switch --update  (replaces nix flake update +  │
│            nixos-rebuild)                                       │
│  dry:      nh os switch --dry                                   │
└─────────────────────────────────────────────────────────────────┘
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `modules/base/nix.nix` | Modify | Add `inputs` to args; add `max-jobs`, `cores`, `keep-outputs`, `trusted-substituters`, `nix.registry.nixpkgs.flake` |
| `darwin/cachix.nix` | Modify | Add aseipp fastly mirrors (mkBefore) + 3 missing cachix entries with public keys |
| `bin/nixos-build` | Modify | Replace `nixos-rebuild` with `nh os` as default; add `--raw` flag for fallback |

## Exact Configuration Snippets

### 1. `modules/base/nix.nix` — Additions

```nix
{ lib, inputs, ... }:  # ← add inputs to function args

{
  nix.gc = { ... };  # unchanged

  nix.settings = {
    # ... existing settings unchanged ...

    # Build parallelism: prevent OOM on large hosts.
    # mkDefault allows per-host override (e.g. rog can bump to 4).
    max-jobs = lib.mkDefault 1;
    cores = 0;  # all cores per derivation (default, explicit for clarity)

    # Retain build outputs across GC. ~30% more disk but avoids
    # full recompile of already-built packages. GC is manual
    # (automatic=false); use --delete-older-than 30d when cleaning.
    keep-outputs = true;

    # Mirror all substituters as trusted so non-root users get
    # the same binary cache coverage.
    trusted-substituters = [
      "https://aseipp-nix-cache.freetls.fastly.net"
      "https://aseipp-nix-cache.global.ssl.fastly.net"
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
      "https://ghostty.cachix.org"
      "https://nixpkgs-unfree.cachix.org"
      "https://cache.flox.dev"
      "https://nixpkgs.cachix.org"
    ];
  };

  # Lock flake registry so `nix shell nixpkgs#foo` uses the
  # flake-locked nixpkgs instead of fetching latest nixos-unstable.
  nix.registry.nixpkgs.flake = inputs.nixpkgs;
}
```

### 2. `darwin/cachix.nix` — Synced to linux parity

```nix
{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ cachix ];

  nix.settings = {
    # Fastly mirrors (same as linux-side modules/base/nix.nix mkBefore)
    substituters = lib.mkBefore [
      "https://aseipp-nix-cache.freetls.fastly.net"
      "https://aseipp-nix-cache.global.ssl.fastly.net"
    ];

    # Full cachix list (matches linux-side modules/base/cachix.nix)
    substituters = lib.mkAfter [
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
      "https://ghostty.cachix.org"
      "https://nixpkgs-unfree.cachix.org"
      "https://cache.flox.dev"
      "https://nixpkgs.cachix.org"
    ];
    trusted-public-keys = lib.mkAfter [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZvDo1tvuGySTdw="
      "nix-community.cachix.org-1:7Nw0m1eeP3Gg3RhbC8Vy/Z4GqW2ZJYX9F8Nc8eeeCJ8="
      "ghostty.cachix.org-1:QB389yTa6gTyneehvqG58y0WnHjQOqgnA+wBnpWWxns="
      "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nj6rs="
      "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="
      "nixpkgs.cachix.org-1:q91R6hxbwFvDqTSDKwDAV4T5PxqXGxswD8vhONFMeOE="
    ];
  };
}
```

**Note**: Nix allows multiple `substituters` declarations with `mkBefore`/`mkAfter` — they merge by priority. However, if the darwin `nix.settings` in `darwin/default.nix` already sets `substituters` without mkBefore/mkAfter, there could be a conflict. Current `darwin/default.nix` only sets `experimental-features` and `auto-optimise-store` (commented out), so no conflict.

### 3. `bin/nixos-build` — nh wiring

Key changes to the script:
- Add `--raw` flag parsing (alongside existing `--no-nom`)
- Add `USE_NH` variable (default `true` if `nh` is found in PATH)
- Replace `nixos-rebuild` calls with `nh os` equivalents:

| Current command | nh equivalent |
|-----------------|---------------|
| `sudo nixos-rebuild switch --flake $FLAKE_PATH#$HOSTNAME` | `nh os switch` (NH_FLAKE auto-set by programs.nh.flake) |
| `sudo nixos-rebuild boot --flake $FLAKE_PATH#$HOSTNAME` | `nh os boot` |
| `sudo nixos-rebuild test --flake $FLAKE_PATH#$HOSTNAME` | `nh os test` |
| `sudo nixos-rebuild dry-activate --flake $FLAKE_PATH#$HOSTNAME` | `nh os switch --dry` |
| `nix flake update && sudo nixos-rebuild switch --flake ...` | `nh os switch --update` |

**Fallback**: When `--raw` is passed, use original `nixos-rebuild` commands unchanged.

**`nh` detection**: `nh` is installed via `programs.nh.enable = true` in `modules/base/nh.nix`. It's available system-wide. The script should check `command -v nh` and fall back to `nixos-rebuild` if not found (defensive).

**nom integration**: `nh` has built-in `nom` integration (`--no-nom` flag). When using `nh`, skip the `run_with_nom` wrapper — `nh` handles it natively.

## Integration Notes

### Per-host overrides
- `max-jobs = lib.mkDefault 1` — any host can override with `nix.settings.max-jobs = 4;` in their `default.nix` without `lib.mkForce`.
- Rog (16 cores + NVIDIA) might benefit from `max-jobs = 2` in `hosts/rog/default.nix` as a future tuning.

### No conflicts detected
- No existing `nix.settings.max-jobs`, `cores`, `keep-outputs`, or `trusted-substituters` in any host or module.
- `nix.registry` not set anywhere in the codebase (grep confirmed 0 matches).
- `darwin/cachix.nix` additions are additive (mkAfter) — no override conflicts.

### GC awareness
- `keep-outputs = true` + `keep-derivations = true` (default) → ~30% more `/nix/store` disk.
- `nix.gc.automatic = false` (already set) → GC only runs manually.
- Recommend: `sudo nix-collect-garbage --delete-older-than 30d` for manual cleanup.

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Validation | `nix flake check --no-build` passes | Run before commit |
| Build | `nixos-build switch` completes without OOM | Manual on t14 (most constrained) |
| Parallelism | `ps aux | grep nix` shows ≤1 build job during build | Manual observation |
| Cache | `nix shell nixpkgs#hello` uses locked nixpkgs (no download) | Check with `--verbose` |
| nh | `nixos-build switch` shows nh diff preview | Manual verification |
| Darwin | `darwin-rebuild switch` on mact2 uses new caches | Check build log for cache hits |

## Migration / Rollout

No migration required. All changes are additive `nix.settings` values and a shell script swap. Single commit, single `nixos-build switch` activates everything.

## Open Questions

- [ ] Should rog get a higher `max-jobs` (e.g. 2-4) given its 16-core + 64GB RAM? Default of 1 is conservative for the laptop (t14) but underutilizes rog.
- [ ] Darwin `substituters` with both `mkBefore` and `mkAfter` in the same attribute set — verify Nix merges these correctly (standard behavior but worth testing on mact2 first).
