# Proposal: Engram Vanilla Integration

## Intent

Replicate the Gentle AI vanilla + layered pattern for Engram to eliminate manual maintenance of the local `engram.ts` plugin (449 lines). Current integration requires manual syncing when upstream releases new versions. This change achieves:

- **Consistency**: Same vanilla + overlay pattern as Gentle AI
- **Maintainability**: Plugin comes from upstream, not local copy
- **Version sync**: Binary and plugin version always match (both v1.14.6)

## Scope

### In Scope
- Add `engram-src` input to `flake.nix` (pin to v1.14.6)
- Create `pkgs/engram-assets/vanilla.nix` to extract plugin from upstream
- Create `pkgs/engram-assets/default.nix` for ENGRAM_BIN overlay
- Export packages via flake outputs and overlay
- Update `modules/home/opencode.nix` to use nix store path for plugin
- Update `pkgs/engram/default.nix` binary to v1.14.6
- Delete local `modules/home/opencode/plugins/engram.ts`

### Out of Scope
- Engram MCP server configuration (already in mcps.nix)
- Changes to memory instructions or plugin behavior
- TUI plugin packaging (separate concern)
- Supporting multiple Engram versions simultaneously

## Capabilities

### New Capabilities
- `engram-vanilla-derivation`: Pure upstream plugin extraction from `engram-src`
- `engram-layered-derivation`: Layered build with ENGRAM_BIN customization via overlay

### Modified Capabilities
- None (configuration-level change, not behavioral spec change)

## Approach

Follow the Gentle AI vanilla pattern exactly:

1. **Flake input**: Add `engram-src = { url = "github:Gentleman-Programming/engram/v1.14.6"; flake = false; }`

2. **Vanilla derivation** (`pkgs/engram-assets/vanilla.nix`):
   - Copy `plugin/opencode/engram.ts` from upstream to `$out/share/engram/opencode/engram.ts`
   - Handle single file (unlike Gentle AI multi-asset structure)

3. **Layered derivation** (`pkgs/engram-assets/default.nix`):
   - Import vanilla as base
   - Apply ENGRAM_BIN overlay (default to nix store path, allow override via overlay)
   - Use `substituteInPlace` or `runCommand` to inject binary path

4. **Flake outputs**: Add `engram-assets-vanilla` and `engram-assets` to `packages.${system}`

5. **Module update**: Change `opencode.nix` to reference `${pkgs.engram-assets}/share/engram/opencode/engram.ts`

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `flake.nix` | Modified | Add `engram-src` input to inputs and outputs |
| `pkgs/engram-assets/vanilla.nix` | New | Pure upstream plugin derivation |
| `pkgs/engram-assets/default.nix` | New | Layered derivation with ENGRAM_BIN overlay |
| `pkgs/engram/default.nix` | Modified | Bump version from v1.12.0 to v1.14.6, update hash |
| `modules/home/opencode.nix` | Modified | Change plugin source from local path to nix store |
| `modules/home/opencode/plugins/engram.ts` | Removed | Delete 449-line local copy |
| `modules/base/overlays.nix` | Modified | Add `engram-assets` to overlay |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Upstream repo structure changes | Low | Pin to specific version (v1.14.6), update derivation when upgrading |
| ENGRAM_BIN override breaks | Low | Keep overlay support, test with custom path |
| Binary/plugin version mismatch | Low | Both updated together in same PR, validated via `nix flake check` |
| Plugin loading fails after switch | Low | Test on lab runtime first, keep stable fallback |

## Rollback Plan

1. Revert `flake.nix` to remove `engram-src` input and outputs
2. Restore local `modules/home/opencode/plugins/engram.ts` from git history
3. Revert `pkgs/engram/default.nix` to v1.12.0
4. Revert `modules/home/opencode.nix` to use local plugin path
5. Remove `pkgs/engram-assets/` directory
6. Run `nix flake check && nixos-build dry` to verify

## Dependencies

- `engram-src` flake input (GitHub: Gentleman-Programming/engram v1.14.6)
- Gentle AI vanilla pattern already established (reference implementation)

## Success Criteria

- [ ] `nix build .#engram-assets-vanilla` produces output with `engram.ts` matching upstream
- [ ] `nix build .#engram-assets` produces layered output with correct ENGRAM_BIN path
- [ ] `nix flake check` passes with no errors
- [ ] `modules/home/opencode/plugins/engram.ts` deleted
- [ ] `pkgs/engram` builds v1.14.6 binary
- [ ] Lab runtime test: plugin loads without errors
- [ ] No manual plugin file maintenance required for future updates
