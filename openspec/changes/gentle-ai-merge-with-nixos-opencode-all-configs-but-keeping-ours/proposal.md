# Proposal: gentle-ai-merge-with-nixos-opencode-all-configs-but-keeping-ours

## Intent

Eliminate the manual sync script (`bin/sync-gentle-ai`) by making the Nix derivation (`pkgs/gentle-ai-assets/`) the single source of truth. The derivation will merge upstream gentle-ai assets at build time while preserving local customizations through a structured overlay system.

## Scope

### In Scope
- **Version Pinning**: Use specific tags (e.g., `v1.23.0`) for `gentle-ai-src` flake input - NOT floating main branch
- **Local Assets Structure**: Create `pkgs/gentle-ai-assets/local-assets/` containing:
  - `skills/` - caveman skills (caveman, caveman-commit, caveman-review)
  - `plugins/` - engram.ts and local plugins
  - `commands/` - caveman commands
  - Modified SDD skills with ORCHESTRATOR GATE customizations
- **Two-Phase Derivation Merge**:
  - Phase 1: Copy upstream assets from gentle-ai-src
  - Phase 2: Overlay `local-assets/` (overwrites with local customizations)
- **Documentation**: Create `docs/gentle-ai-updates.md` with update workflow, conflict resolution, rollback procedures
- **Sync Script Deprecation**: Add warning to `bin/sync-gentle-ai` pointing to new workflow
- **Update Script Enhancement**: Improve `bin/update-gentle-ai` to handle version bumps with `local-assets/` awareness

### Out of Scope
- Modifying upstream gentle-ai repository (it has no Nix files)
- Changing local model assignments (DeepInfra: Kimi, Qwen, DeepSeek, GLM, etc.)
- Reorganizing NixOS module framework structure
- Adding new hosts or changing host MCP toggles
- Editing `AGENTS.md` (root documentation) - it is project docs, not generated config

## Capabilities

### New Capabilities
- `gentle-ai-assets-merge`: Build-time merge with local-assets/ overlay pattern
- `local-assets-preservation`: Structured preservation of caveman skills, custom plugins, ORCHESTRATOR GATE modifications
- `version-pinning-workflow`: Documented process for updating upstream version in flake.nix

### Modified Capabilities
- `gentle-ai-derivation`: Enhanced two-phase merge logic (upstream → local overlay)
- `update-script`: Enhanced to handle local-assets/ and version pinning workflow
- `sync-script`: Deprecated with warning message

## Approach

### 1. Create Local Assets Structure
Create `pkgs/gentle-ai-assets/local-assets/` with subdirectories:
```
local-assets/
├── skills/
│   ├── caveman/
│   ├── caveman-commit/
│   ├── caveman-review/
│   ├── sdd-*/ (with ORCHESTRATOR GATE customizations)
│   └── nix-verify/
├── plugins/
│   └── engram.ts
└── commands/
    ├── caveman.md
    ├── caveman-commit.md
    └── caveman-review.md
```

### 2. Two-Phase Derivation Merge
Update `pkgs/gentle-ai-assets/default.nix`:
```nix
installPhase = ''
  # Phase 1: Copy upstream assets
  mkdir -p $out/share/gentle-ai
  cp -r $src/internal/assets/opencode/* $out/share/gentle-ai/opencode/
  cp -r $src/internal/assets/skills/* $out/share/gentle-ai/skills/
  
  # Phase 2: Overlay local-assets (overwrites upstream with local customizations)
  if [ -d ./local-assets/skills ]; then
    cp -r ./local-assets/skills/* $out/share/gentle-ai/skills/
  fi
  if [ -d ./local-assets/plugins ]; then
    cp -r ./local-assets/plugins/* $out/share/gentle-ai/opencode/plugins/
  fi
  if [ -d ./local-assets/commands ]; then
    cp -r ./local-assets/commands/* $out/share/gentle-ai/opencode/commands/
  fi
'';
```

### 3. Version Pinning
Update `flake.nix` to use specific tags:
```nix
gentle-ai-src = {
  url = "github:Gentleman-Programming/gentle-ai/v1.23.0";  # Pinned version
  flake = false;
};
```

### 4. Documentation
Create `docs/gentle-ai-updates.md`:
- Step-by-step update process
- How to handle 3 types of conflicts:
  1. Upstream adds new file (we want it) → automatic
  2. Upstream modifies file we customized → manual review
  3. Upstream deletes file we customized → decision needed
- Rollback procedures
- Best practices

### 5. Sync Script Deprecation
Update `bin/sync-gentle-ai`:
```bash
echo "WARNING: This script is deprecated."
echo "Use the derivation-based workflow instead:"
echo "  1. Update flake.nix with new gentle-ai-src version"
echo "  2. Run: nix flake lock --update-input gentle-ai-src"
echo "  3. Run: nixos-build switch"
echo ""
echo "See docs/gentle-ai-updates.md for details."
exit 1
```

### 6. Project Name Normalization Fix
Keep the fix in `modules/home/opencode/agents.nix`:
```nix
# Normalize the project name (CRITICAL): Remove leading dots from directory names
# (e.g., ".nixos" -> "nixos")
```
This is a local workaround for an upstream bug.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `pkgs/gentle-ai-assets/local-assets/` | New | Local files that override upstream |
| `pkgs/gentle-ai-assets/default.nix` | Modified | Two-phase merge logic |
| `flake.nix` | Modified | Version pinning documentation |
| `docs/gentle-ai-updates.md` | New | Update workflow documentation |
| `bin/sync-gentle-ai` | Modified | Deprecation warning |
| `bin/update-gentle-ai` | Modified | Enhanced for local-assets workflow |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Local customizations lost during update | Low | Explicit local-assets/ directory structure, version controlled |
| Merge logic breaks skill loading | Low | Test build, validate JSON syntax, run `nix flake check` |
| Upstream API changes break derivation | Med | Pin to specific versions, test before updating |
| Documentation becomes stale | Low | Update docs/gentle-ai-updates.md with each version bump |

## Rollback Plan

1. **Immediate rollback**: `git revert HEAD` to restore previous state
2. **Version rollback**: Edit `flake.nix` to previous `gentle-ai-src` tag, run `nix flake lock --update-input gentle-ai-src`
3. **Restore sync script**: Revert `bin/sync-gentle-ai` changes if needed
4. **Rebuild**: `nixos-build switch`

## Dependencies

- Upstream gentle-ai repository accessible during build
- `nixfmt` for formatting changes
- Existing `bin/update-gentle-ai` script infrastructure

## Success Criteria

- [ ] `nix flake check` passes
- [ ] `nixos-build` succeeds on both hosts (rog, thinkcentre)
- [ ] Upstream SDD skills present in `/nix/store/...-gentle-ai-assets/share/gentle-ai/skills/`
- [ ] Local caveman skills present and override any upstream conflicts
- [ ] Local engram.ts plugin is installed correctly
- [ ] `bin/sync-gentle-ai` shows deprecation warning and exits
- [ ] `docs/gentle-ai-updates.md` exists with complete workflow documentation
- [ ] Project name normalization fix preserved in agents.nix
- [ ] No emojis or Spanish in generated configs (English-only policy preserved)
