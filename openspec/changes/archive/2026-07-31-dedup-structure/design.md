# Design: dedup-structure

## Technical Approach
Extract duplicated fragments into shared modules; keep host-specific imports flat.

## Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Nix resilience | `shared/nix-resilience.nix` | Safe to import from NixOS and nix-darwin |
| Cachix | `shared/cachix.nix` | Keeps priority markers in platform files |
| Standalone HM | `baseHomeConfig` wrapper | Single shape, per-host extras |
| GitHub tokens | `shared/github-tokens.nix` | One declaration, two mounting scopes |
| Packages | `commonPackages` function | Eliminates repeated `callPackage` lists |
| Remote desktop | Keep separate | Different renderers, metadata, and IPs |

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `shared/nix-resilience.nix` | Create | Shared `http2`, timeouts, `fallback` |
| `shared/cachix.nix` | Create | Shared substituters and trusted-public-keys |
| `shared/github-tokens.nix` | Create | Shared PAT sops declarations |
| `linux/system/base/nix.nix` | Modify | Import resilience, remove inlined settings |
| `darwin/system/nix.nix` | Modify | Import resilience, remove overlap |
| `linux/system/base/cachix.nix` | Modify | Import shared cachix |
| `darwin/system/cachix.nix` | Modify | Import shared cachix |
| `shared/sops.nix` | Modify | Import shared github-tokens |
| `linux/system/base/sops.nix` | Modify | Import shared github-tokens |
| `flake.nix` | Modify | Use `baseHomeConfig` for rog/thinkcentre/t14 |
| `lib/packages.nix` | Modify | Common set |
| `linux/home/remote-desktop.nix` | Modify | Audit comment |
| `darwin/home/remote-desktop.nix` | Modify | Audit comment |

## Migration / Rollout
No migration required.

## Open Questions
None.
