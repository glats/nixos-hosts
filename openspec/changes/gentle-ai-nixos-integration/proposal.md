# Proposal: gentle-ai-nixos-integration

## Intent

Formalize the gentle-ai integration into a proper NixOS/Home Manager module with declarative options, clear separation of concerns, and documented update workflows. Currently, gentle-ai integration is spread across ad-hoc derivations and manual scripts. This change establishes a maintainable, version-pinned architecture that balances upstream vanilla assets with NixOS-specific customizations.

## Scope

### In Scope
- **NixOS Module Structure**: Create `modules/home/gentle-ai/` with proper option declarations
- **Version Synchronization**: Unify gentle-ai binary version with assets version via single flake input
- **Asset Management Strategy**: Document and formalize the upstream + local overlay pattern
- **Update Workflow**: Define clear process for bumping gentle-ai versions
- **Configuration Options**: Expose key toggles (enable, runtime mode, vanilla vs customized)
- **Documentation**: Migration guide from current ad-hoc setup to formal module

### Out of Scope
- Modifying upstream gentle-ai repository
- Supporting non-NixOS installations
- Auto-update mechanisms (manual version bumps only)
- Alternative AI agent integrations (Claude, Cursor, etc.)
- Rewriting gentle-ai CLI in Nix

## Capabilities

### New Capabilities
- `gentle-ai-nixos-module`: Formal Home Manager module with `programs.gentle-ai` options
- `gentle-ai-version-sync`: Single source of truth for binary + assets versioning
- `gentle-ai-vanilla-mode`: Option to use pure upstream assets without local customizations
- `gentle-ai-custom-overlay`: Structured mechanism for local rule/skill additions

### Modified Capabilities
- `gentle-ai-assets-derivation`: Enhanced to support vanilla vs overlay modes
- `opencode-config-module`: Refactored to depend on gentle-ai module options

## Approach

### 1. Module Architecture
Create `modules/home/gentle-ai/` with clear separation:
```
modules/home/gentle-ai/
├── default.nix          # Main module entry, option declarations
├── assets.nix           # Asset derivation logic (upstream + overlay)
├── binary.nix           # Binary package reference
└── update.nix           # Update script derivation
```

### 2. Version Synchronization Strategy
Pin both binary and assets to the same upstream version:
```nix
# flake.nix
gentle-ai-src = {
  url = "github:Gentleman-Programming/gentle-ai/v1.23.0";
  flake = false;
};

# pkgs/gentle-ai/default.nix
version = "1.23.0";  # Match gentle-ai-src
```

Update workflow: Edit both versions together in a single commit.

### 3. Vanilla First Approach

**Phase 1 (Now)**: Start with pure vanilla upstream
- `programs.gentle-ai.vanilla = true` (default)
- No local customizations
- Clean baseline to evaluate what we actually need

**Phase 2 (Later)**: Evaluate and add customizations selectively
- Use vanilla for a period to identify gaps
- Document what features are missing
- Add customizations ONLY if proven necessary:
  - Caveman skills? → Only if ultra-compressed mode is needed
  - Other custom skills? → Only if specific project needs arise

**Note**: The following are already included in vanilla or configurable via TUI:
- Engram support (comes from upstream)
- Model assignments (upstream defaults)
- TDD strict mode (enable via gentle-ai TUI)

This avoids maintaining customizations "just in case" and ensures we only keep what we actually use.

### 4. Asset Merge Strategy
Formalize the two-phase merge already implemented:
1. Copy upstream assets from `gentle-ai-src`
2. Overlay `local-assets/` (skills, plugins, commands)
3. Apply NixOS-specific PERSONA.md prefix (English-only rules)

### 5. Update Workflow
Document the process:
1. Check upstream releases: `gentle-ai releases`
2. Update `flake.nix`: Change `gentle-ai-src` URL to new tag
3. Update `pkgs/gentle-ai/default.nix`: Change `version` and `hash`
4. Run `nix flake lock --update-input gentle-ai-src`
5. Build and test: `nixos-build`
6. Commit with version bump message

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `modules/home/gentle-ai/` | New | Formal module structure with options |
| `modules/home/opencode.nix` | Modified | Refactor to use gentle-ai module |
| `flake.nix` | Modified | Add version comment linking to gentle-ai-src |
| `pkgs/gentle-ai/default.nix` | Modified | Add comment linking to flake.nix version |
| `docs/gentle-ai-integration.md` | New | Complete integration guide |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|-------------|
| Version drift (binary vs assets) | Low | Document link between versions, use update script |
| Breaking changes in upstream asset structure | Med | Pin to specific versions, test before updating |
| Local customizations lost | Low | Git-tracked local-assets/, vanilla mode for testing |
| Module option conflicts | Low | Use `mkDefault`, test on both hosts |

## Rollback Plan

1. **Immediate**: `git revert HEAD` to restore previous module structure
2. **Configuration**: Set `programs.gentle-ai.vanilla = true` to skip local overlays
3. **Legacy restore**: Switch imports back to current `opencode.nix` standalone
4. **Rebuild**: `nixos-build switch`

## Dependencies

- Upstream gentle-ai repository structure remains stable
- Home Manager module system
- Existing `local-assets/` directory structure

## Success Criteria

### Phase 1 (Vanilla Baseline)
- [ ] `programs.gentle-ai.enable` option works on both hosts
- [ ] `programs.gentle-ai.vanilla = true` (default) uses pure upstream assets
- [ ] `nix flake check` passes with new module
- [ ] Update workflow documented in `docs/gentle-ai-integration.md`
- [ ] Version synchronization between binary and assets is explicit
- [ ] Migration guide explains how to move from current setup to new module

### Phase 2 (Selective Customization - Future)
- [ ] Documented evaluation: what features are missing from vanilla?
- [ ] Decision log: which customizations were added back and why
- [ ] Only proven-necessary customizations re-added to `local-assets/`
