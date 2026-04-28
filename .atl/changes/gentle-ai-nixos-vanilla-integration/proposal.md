# Proposal: Gentle AI NixOS Vanilla Integration

## Intent

Formalize the gentle-ai NixOS integration to ensure version synchronization between the binary and upstream assets, leverage vanilla configuration without drift, and establish a clear update workflow.

**Key Insight from Exploration**: The current NixOS setup already correctly implements vanilla + TDD strict (skills are byte-identical). The main gap is version pinning between the binary and gentle-ai-src input.

## Scope

### In Scope
- Pin `gentle-ai-src` flake input to match binary version
- Create `gentle-ai-vanilla.nix` derivation (upstream-only assets)
- Document why TDD strict is already included (no extra config needed)
- Create update workflow for synchronized version bumps
- Document NixOS-specific additions vs vanilla

### Out of Scope
- Custom skills (caveman, etc.) — separate concern
- Custom plugins (engram, background-agents) — already in plugins/ overlay
- Custom persona rules — handled by current derivation
- Docker vanilla file structure exploration — completed

## Capabilities

### New Capabilities
- `gentle-ai-version-sync`: Pin gentle-ai-src to match binary version in flake.nix
- `gentle-ai-vanilla-derivation`: Create upstream-only assets derivation (vanilla.nix)
- `gentle-ai-update-workflow`: Document synchronized update process for binary + assets

### Modified Capabilities
- None (current setup already matches vanilla)

## Approach

1. **Version Pinning**: Update flake.nix to use specific gentle-ai-src revision matching binary version (1.21.0)
2. **Vanilla Derivation**: Create `gentle-ai-vanilla.nix` that copies upstream assets without modifications (for reference/comparison)
3. **Update Workflow**: Document process for bumping both binary and src together
4. **Documentation**: Update AGENTS.md or add docs/ to explain NixOS vs vanilla differences

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `flake.nix` | Modified | Pin gentle-ai-src to specific revision matching binary |
| `pkgs/gentle-ai-assets/` | New file | Add `vanilla.nix` (upstream-only derivation) |
| `docs/` or `AGENTS.md` | New/Modified | Document NixOS-specific additions vs vanilla |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Version drift between binary and assets | Low | Pin exact revision in flake.nix |
| Breaking changes in upstream assets | Low | Test in `lab` runtime before `stable` |
| Confusion about what's vanilla vs NixOS | Medium | Clear documentation in AGENTS.md |
| Accidental `gentle-ai sync` execution | Medium | Document "NEVER run sync" rule |

## Rollback Plan

1. Revert flake.nix to previous gentle-ai-src revision
2. Rebuild: `nixos-build switch`
3. If needed, restore old asset derivation

## Dependencies

- Gentle AI binary version 1.21.0 (already installed)
- Gentle AI upstream assets (gentleman-programming/gentle-ai repo)

## Success Criteria

- [ ] gentle-ai-src flake input is pinned to binary-matching version
- [ ] gentle-ai-vanilla.nix derivation exists and builds successfully
- [ ] `nix flake check` passes
- [ ] Documentation exists explaining NixOS additions vs vanilla
- [ ] Update workflow documented (how to bump binary + src together)
