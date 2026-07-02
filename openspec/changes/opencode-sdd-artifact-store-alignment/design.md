# Design: Align SDD Artifact Store Dispatching

## Technical Approach

Bump the `gentle-ai` upstream pin from `v1.40.2` to `v1.42.0` (PR #761). The upstream release already contains the artifact-store-aware dispatcher gate and canonical `hybrid` terminology. This is a version-alignment change — no local patches to runtime assets.

## Architecture Decisions

| Decision | Chosen | Rejected | Rationale |
|----------|--------|----------|-----------|
| Bump upstream vs patch locally | Bump to v1.42.0 | Patch `~/.config/opencode/` assets in-repo | Upstream fix is validated; local patching violates "always use upstream plugins" principle and creates maintenance debt |
| Update binary + src together | Both | Bump only one | Spec R2 requires flake pin and binary version match; assets derive from `gentle-ai-src` automatically |
| No asset derivation changes | Keep vanilla + layered derivations | Modify `pkgs/gentle-ai-assets/` | Upstream asset content is unchanged in structure; only version tag changes |

## Data Flow

```
flake.nix ──► gentle-ai-src pin v1.42.0
     │
     ├──────► pkgs/gentle-ai-assets/vanilla.nix ──► upstream assets (orchestrator, commands, skills)
     │
     └──────► pkgs/gentle-ai/default.nix ──► binary tarball fetch (linux/darwin)
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `flake.nix` | Modify | Update `gentle-ai-src.url` tag `v1.40.2` → `v1.42.0` |
| `pkgs/gentle-ai/default.nix` | Modify | Update `version` `1.40.2` → `1.42.0`; update `sha256` for linux and darwin tarballs |

## Interfaces / Contracts

No new interfaces. Existing contracts affected:
- `sdd-orchestrator.md` — upstream v1.42.0 adds artifact-store gate before native dispatcher invocation
- `sdd-status-contract.md` — upstream v1.42.0 scopes native dispatcher authority to `openspec` store only
- Preflight/skills terminology — upstream v1.42.0 uses `hybrid` exclusively, removing `both`

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Build | Flake evaluates cleanly | `nix flake check --no-build` |
| Package | Binary and assets build | `nix build .#gentle-ai`, `nix build .#gentle-ai-assets-vanilla`, `nix build .#gentle-ai-assets` |
| Integration | Deployed runtime contains store-aware gate | After switch, inspect `~/.config/opencode/sdd-orchestrator.md` for artifact-store conditional |
| E2E | Engram-only change not blocked | Create test Engram change, run `sdd-status`, verify no "Active OpenSpec change not found" |

## Migration / Rollout

1. Update `flake.nix` tag and `pkgs/gentle-ai/default.nix` version + hashes.
2. Run `nix flake lock --update-input gentle-ai-src`.
3. Run `nix flake check --no-build`.
4. Build assets: `nix build .#gentle-ai-assets-vanilla && nix build .#gentle-ai-assets`.
5. Switch host config (e.g., `nixos-build switch` or `home-manager switch`).
6. Verify `~/.config/opencode/` deployed files reflect v1.42.0 content.

## Rollback Plan

```bash
git checkout HEAD -- flake.nix pkgs/gentle-ai/default.nix
nix flake lock --update-input gentle-ai-src
nix flake check --no-build
# Rebuild/switch as needed
```

## Open Questions

- None
