# Proposal: Cleanup OpenCode Old Configs

## Intent

Remove obsolete scripts and simplify the OpenCode configuration system by eliminating completed migration artifacts. The migration from legacy to declarative Nix-based configuration is complete; cleanup technical debt from that transition.

## Scope

### In Scope

**1. Delete Obsolete Scripts**
- `bin/sync-opencode-remote` — References missing `opencode.json.base`, broken
- `bin/sync-opencode-mac.sh` — Outdated API model mappings (deepinfra → github-copilot)
- `bin/setup-opencode-keychain-mac.sh` — All providers removed from config, useless
- `bin/gentle-ai-tui` — Bypasses Nix versioning by downloading latest release directly

**2. Simplify Lab/Legacy System**
- Remove `legacyFallback` option from `modules/home/opencode.nix`
- Remove migration warnings block referencing legacyFallback
- Update `modules/home/opencode-profile.nix` to remove `legacyFallback = false`
- Clean up comments referencing non-existent `opencode-legacy.nix`
- **Decision**: Keep "lab" runtime — user actively uses both stable and lab

### Out of Scope
- Deleting `backup/` directory (keep)
- Deleting `.nixos-sdd/` directory (keep)
- Deleting `openspec/specs/` (main specs — source of truth)
- Deleting `openspec/changes/gentle-ai-*` (historical archive)
- Deleting `.atl/changes/` (historical artifacts)
- Removing `bin/opencode-worktree` or `bin/oc-wt` (still used)

## Capabilities

### New Capabilities
None — this is cleanup/simplification only.

### Modified Capabilities
- `opencode-config`: Remove `legacyFallback` option, simplify module interface

## Approach

1. Delete 4 obsolete scripts from `bin/`
2. Edit `modules/home/opencode.nix`:
   - Remove `legacyFallback` option definition (lines ~140-159)
   - Remove migration warning block (lines ~163-171)
   - Update `runtime` option description to remove legacy references
3. Edit `modules/home/opencode-profile.nix`:
   - Remove `legacyFallback = false;` line
4. Run `nix flake check` to validate
5. Run `format-nix` to ensure formatting

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `bin/sync-opencode-remote` | Removed | Broken script referencing missing files |
| `bin/sync-opencode-mac.sh` | Removed | Outdated API mappings |
| `bin/setup-opencode-keychain-mac.sh` | Removed | All providers removed, useless |
| `bin/gentle-ai-tui` | Removed | Bypasses Nix versioning |
| `modules/home/opencode.nix` | Modified | Remove legacyFallback option and warnings |
| `modules/home/opencode-profile.nix` | Modified | Remove legacyFallback setting |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Accidental deletion of still-used script | Low | Verified `opencode-worktree` and `oc-wt` are separate, still in use |
| Breaking existing user config that sets legacyFallback | Low | Option only existed during migration; user already has it set to false |
| Lab runtime confusion after cleanup | Low | Keeping lab runtime, only removing legacy fallback |

## Rollback Plan

1. Restore deleted scripts from git: `git checkout HEAD -- bin/<script>`
2. Restore module changes: `git checkout HEAD -- modules/home/opencode.nix modules/home/opencode-profile.nix`
3. Rebuild: `nixos-build`

## Dependencies

None — cleanup only, no external dependencies.

## Success Criteria

- [ ] 4 obsolete scripts deleted from `bin/`
- [ ] `legacyFallback` option removed from `modules/home/opencode.nix`
- [ ] Migration warning block removed from `modules/home/opencode.nix`
- [ ] `legacyFallback = false` removed from `modules/home/opencode-profile.nix`
- [ ] `nix flake check` passes
- [ ] `format-nix` produces no changes (or changes applied)
- [ ] System rebuilds successfully with `nixos-build`
