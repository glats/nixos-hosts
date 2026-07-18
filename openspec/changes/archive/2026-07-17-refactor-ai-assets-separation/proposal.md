# Proposal: Refactor AI assets separation — independent skill sources

## Intent

Split the monolithic `gentle-ai-assets-vanilla`→`gentle-ai-assets` derivation chain into independent per-source derivations. Each upstream source (gentle-ai, caveman, ponytail) produces its own build artifact. Activation scripts consume N-way source lists for skills, commands, and AGENTS.md/CLAUDE.md concatenation. The `extraAssets`/`extraFiles` overlay mechanism is removed — local files are referenced directly in `home.file`.

## Scope

### In Scope
- Split `gentle-ai-assets-vanilla` into `gentle-ai-assets` (gentle-ai-src only), `caveman-assets` (caveman-src only), `ponytail-assets` (ponytail-src only)
- Rename `home.gentle-ai` namespace to `home.ai-assets`
- Replace `skillsSource`+`localSkillsSource` with `skillSources` (list of paths), N-way union in activation script
- New `commandSources` option for N-way commands union (both OpenCode and Claude Code)
- New `agentsMdSources` option for AGENTS.md/CLAUDE.md concatenation via bash in activation script — symmetric for both tools
- Delete `shared/assets/review-gate.md` (18-line redundant version)
- Delete `shared/opencode/assets/skills/.gitkeep` (empty dir remnant)
- Remove `extraAssets`/`extraFiles` plumbing from `lib/packages.nix` and `gentle-ai-assets/default.nix`
- Reference local review-gate.md directly in `home.file` via local `./` path

### Out of Scope
- Changing engram-assets or secret-guard-assets derivation chains
- Modifying gentle-ai-src or caveman-src upstream content
- Changing plugin management (plugins stay as-is)
- Host-specific skill/command overrides (no host uses them today)

## Capabilities

### New Capabilities
None. This is a structural refactor — no new user-facing capabilities.

### Modified Capabilities
None. Behavior is preserved; implementation changes.

## Approach

**Approach 1 from exploration** — N-way bash union — with user-directed adjustments:

1. **Derivations**: `gentle-ai-assets` (was vanilla, now pure gentle-ai-src), new `caveman-assets` and `ponytail-assets`. Old layered `gentle-ai-assets` is deleted. `local-ai-assets` unchanged.

2. **Namespace/options**: `shared/gentle-ai-common.nix` → `shared/ai-assets.nix` with `home.ai-assets` namespace. Three new list options: `skillSources`, `commandSources`, `agentsMdSources`. MCP options renamed in-place.

3. **Activation scripts**: Generalize the existing 2-pass copy pattern to N-pass loops using `for src in $sources; do ... done`. Orphan cleanup checks ALL sources in the list. AGENTS.md/CLAUDE.md: `cat` each existing file from `agentsMdSources` → consolidated output.

4. **Local file references**: Review-gate.md (443-line) at `shared/opencode/assets/opencode/review-gate.md` linked directly via `./shared/opencode/assets/opencode/review-gate.md` in `home.file`. Claude Code's review-gate.md uses the same file. Claude Code also gets CLAUDE.md via the same `agentsMdSources` concat mechanism as AGENTS.md.

5. **agents.nix**: Reference `pkgs.gentle-ai-assets` instead of `pkgs.gentle-ai-assets-vanilla` for the sdd-overlay JSON.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `pkgs/gentle-ai-assets/default.nix` | Rewritten | Pure gentle-ai-src only; no vanilla→layered chain |
| `pkgs/gentle-ai-assets/vanilla.nix` | Deleted | Merged into default.nix |
| `pkgs/caveman-assets/default.nix` | Created | caveman-src skills + commands |
| `pkgs/ponytail-assets/default.nix` | Created | ponytail-src skills + commands |
| `lib/packages.nix` | Modified | Add caveman/ponytail assets; remove extraAssets/extraFiles |
| `overlays/linux.nix`, `overlays/darwin.nix` | Modified | Add/remove package names in overlay |
| `shared/gentle-ai-common.nix` → `shared/ai-assets.nix` | Renamed + rewritten | Namespace `home.ai-assets`; N-way list options |
| `shared/opencode.nix` | Modified | Import ai-assets.nix; N-way skills/commands; AGENTS.md concat; direct review-gate path |
| `shared/claude-code.nix` | Modified | Same N-way patterns; CLAUDE.md concat; direct review-gate path |
| `shared/opencode-profile.nix` | Modified | Update import path |
| `shared/claude-code-profile.nix` | Modified | Update import path |
| `shared/opencode/agents.nix` | Modified | Replace vanilla reference |
| `shared/opencode/mcps-base.nix`, `mcps.nix` | Modified | Namespace rename |
| `home-darwin/opencode/mcps-extra.nix` | Modified | Namespace rename |
| `shared/assets/review-gate.md` | Deleted | Redundant 18-line file |
| `shared/opencode/assets/skills/.gitkeep` | Deleted | Empty dir remnant |
| `docs/gentle-ai-update.md` | Modified | Update package names, commands |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Activation script regression from N-way generalization | Med | Keep cmp-guard copy pattern; test with `nix build` on all affected hosts |
| `home.gentle-ai` namespace rename breaks hosts that reference old options | Low | No host overrides exist; namespace is internal to shared modules |
| AGENTS.md/CLAUDE.md concat order produces wrong consolidated content | Low | Only gentle-ai-src provides AGENTS.md today; order is deterministic from list |
| Darwin overlay mismatch | Low | Both overlays mirror each other; test mact2 build |

## Rollback Plan

1. Revert `shared/ai-assets.nix` → `shared/gentle-ai-common.nix` (git mv back)
2. Revert `home.ai-assets` → `home.gentle-ai` in all importing files
3. Restore `pkgs/gentle-ai-assets/vanilla.nix` and old `default.nix`
4. Delete `pkgs/caveman-assets/` and `pkgs/ponytail-assets/`
5. Restore `extraAssets`/`extraFiles` in `lib/packages.nix`
6. Revert activation scripts to 2-source fixed pattern
7. Build and switch: `nixos-build`

## Dependencies

- `gentle-ai-src` flake input must have `skills/`, `opencode/commands/`, `AGENTS.md` at expected paths
- `caveman-src` flake input must have `skills/` and `commands/` at expected paths
- `ponytail-src` flake input must have `skills/` and `commands/` at expected paths

## Success Criteria

- [ ] `nix flake check --no-build` passes with zero errors
- [ ] `nix build .#nixosConfigurations.rog.config.system.build.toplevel` succeeds (NixOS)
- [ ] `nix build .#nixosConfigurations.mact2.config.system.build.toplevel` succeeds (Darwin)
- [ ] All 4 local skills (`audit-providers-models`, `git-feature-flow`, `nix-verify`, `opencode-session-recovery`) deploy to `~/.config/opencode/skills/`
- [ ] All caveman skills deploy to `~/.config/opencode/skills/`
- [ ] All ponytail skills deploy to `~/.config/opencode/skills/`
- [ ] `~/.config/opencode/AGENTS.md` contains content from all `agentsMdSources`
- [ ] `~/.claude/CLAUDE.md` contains same content as `~/.config/opencode/AGENTS.md`
- [ ] `~/.config/opencode/review-gate.md` is the 443-line orchestrator version
- [ ] `~/.claude/review-gate.md` is the 443-line orchestrator version
- [ ] No orphan files remain in `shared/opencode/assets/skills/` or `shared/assets/review-gate.md`
- [ ] No references to `home.gentle-ai` remain in codebase
- [ ] No references to `gentle-ai-assets-vanilla` remain in codebase
