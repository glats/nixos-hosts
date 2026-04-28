# Proposal: Gentle AI Freshly Into NixOS for OpenCode

## Intent

Complete the unfinished "gentle-ai-nixos-vanilla-integration" change to make Gentle AI updates trivial. Currently, updating Gentle AI requires manual coordination between the binary version and assets, with no clear separation between upstream and local modifications. This creates friction and risk of version mismatches.

**Why this matters:**
- The `.last-sync` marker shows v1.23.0 but binary is v1.21.0 — drift is already happening
- 21 local skill overrides exist but are mixed with upstream in a single derivation
- No clear update workflow means updates are avoided or error-prone
- Clean separation enables confident, automated updates

## Scope

### In Scope
- Create `vanilla.nix` — pure upstream assets, zero local modifications
- Refactor `default.nix` to layer local modifications on top of vanilla
- Version-pin `gentle-ai-src` in `flake.nix` to match binary version
- Document the complete update workflow
- Verify `nix flake check` passes and builds succeed

### Out of Scope
- Updating the Gentle AI binary version itself (stays at v1.21.0 for this change)
- Adding new local skills or modifications
- CI/automation for updates (future enhancement)
- Changes to modules consuming gentle-ai-assets

## Capabilities

### New Capabilities
- `vanilla-derivation`: Pure upstream asset copy with no local modifications
- `version-synchronization`: Explicit version pinning with documented update workflow
- `layered-assets`: Local modifications applied as overlay on vanilla base

### Modified Capabilities
- `gentle-ai-assets-build`: Build process uses layered approach (vanilla + local)
- `gentle-ai-update`: Update workflow documented and streamlined

## Approach

**Technical Strategy: Vanilla + Layered Overrides**

1. **Vanilla Base**: Create `pkgs/gentle-ai-assets/vanilla.nix` that copies upstream assets exactly as-is. This becomes the reproducible upstream baseline.

2. **Layered Integration**: Refactor `default.nix` to:
   - Import vanilla derivation as base
   - Apply local skill overrides from `modules/home/opencode/skills/` (21 existing)
   - Merge local persona rules into upstream AGENTS.md
   - Use `symlinkJoin` or `runCommand` for clean composition

3. **Version Pinning**: Update `flake.nix`:
   ```nix
   gentle-ai-src.url = "github:opencode-ai/gentle-ai/v1.21.0";  # Matches pkgs/gentle-ai
   ```
   Add comment documenting the version relationship.

4. **Update Workflow Documentation**: Create `docs/gentle-ai-update.md` with:
   - Check latest release: `gh release list --repo opencode-ai/gentle-ai`
   - Update binary version in `pkgs/gentle-ai/default.nix`
   - Update `gentle-ai-src` tag in `flake.nix`
   - Run `nix flake lock --update-input gentle-ai-src`
   - Build and verify: `nix build .#gentle-ai-assets && nix flake check`

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `pkgs/gentle-ai-assets/vanilla.nix` | New | Pure upstream asset derivation |
| `pkgs/gentle-ai-assets/default.nix` | Modified | Layer local mods on vanilla base |
| `flake.nix` | Modified | Version-pin gentle-ai-src input |
| `docs/gentle-ai-update.md` | New | Update workflow documentation |
| `.last-sync` | Modified | Update to v1.21.0 (match current) |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Local skills break with upstream changes | Low | 21 overrides are additive; test build catches conflicts |
| Version pinning forgets to update | Medium | Document workflow includes version check; consider CI in future |
| Flake input drift reoccurs | Low | Pin to explicit tag, not branch; update workflow documented |
| `nix flake check` fails after refactor | Low | Validate before finishing; keep current working state as reference |

## Rollback Plan

1. Rename `pkgs/gentle-ai-assets/default.nix` to `default.nix.new`
2. Restore original `default.nix` from git: `git checkout HEAD -- pkgs/gentle-ai-assets/default.nix`
3. Remove `vanilla.nix` if it causes issues
4. Revert `flake.nix` changes: `git checkout HEAD -- flake.nix`
5. Verify: `nix build .#gentle-ai-assets && nix flake check`

## Dependencies

- Existing 21 local skills in `modules/home/opencode/skills/`
- Current `gentle-ai` binary at v1.21.0
- Upstream `gentle-ai-src` repo access

## Success Criteria

- [ ] `vanilla.nix` builds and contains only unmodified upstream files
- [ ] `nix build .#gentle-ai-assets` produces layered output (upstream + local)
- [ ] All 21 local skill overrides present in final output
- [ ] `nix flake check` passes without warnings
- [ ] Update workflow documented in `docs/gentle-ai-update.md`
- [ ] `.last-sync` marker matches `gentle-ai-src` version in flake.lock
- [ ] Rollback steps verified to work
