# Exploration: Refactor AI assets separation — independent skill sources

Change: `refactor-ai-assets-separation`

## Current State

### Derivation Architecture

The current architecture has **two layers** for all upstream AI assets:

```
gentle-ai-src ─┐
caveman-src ───┼──► gentle-ai-assets-vanilla ──► gentle-ai-assets (layered)
ponytail-src ──┘        (vanilla.nix)              (default.nix)
                                                    ↑
                           shared/opencode/assets/ ─┤ extraAssets (deep overlay)
                           shared/assets/          ─┘ extraFiles  (flat files)
```

**`gentle-ai-assets-vanilla`** (`pkgs/gentle-ai-assets/vanilla.nix`):
- Takes ALL 3 upstream sources and merges them into ONE derivation
- Output: `$out/share/gentle-ai/`
  - `AGENTS.md` (from gentle-ai-src root)
  - `opencode/` (plugins, commands, review-gate.md — from gentle-ai-src)
  - `skills/` (gentle-ai-src skills + caveman-src skills + ponytail-src skills, all merged)
  - `claude/` (agents, commands, personas — from gentle-ai-src)
  - `cursor/`, `windsurf/`, etc. (other agent configs from gentle-ai-src)

**`gentle-ai-assets`** (`pkgs/gentle-ai-assets/default.nix`):
- Takes vanilla as base, layers local overrides on top
- `extraAssets` (`shared/opencode/assets/`): deep overlay — any file at matching relative path overwrites vanilla
  - Currently provides: `opencode/review-gate.md` (443-line orchestrator version)
  - Contains empty `skills/.gitkeep` (remnant from when skills were overlaid here)
- `extraFiles` (`shared/assets/`): flat-file overlay at root level
  - Currently provides: `review-gate.md` (18-line short version for Claude Code)
- `extraCommands` = null (no local command forks)

**`local-ai-assets`** (`pkgs/local-ai-assets/default.nix`):
- Independent derivation, NOT part of the vanilla→layered chain
- Packages: `shared/assets/skills/` → `$out/share/local-ai/skills/`
- Contains 4 local skills: `audit-providers-models`, `git-feature-flow`, `nix-verify`, `opencode-session-recovery`

### Activation Script Flow

Both `opencode.nix` and `claude-code.nix` do manual copy from nix store:

**Skills** (2-source UNION in bash):
1. Copy from `skillsSource` = `${pkgs.gentle-ai-assets}/share/gentle-ai/skills`
2. Copy from `localSkillsSource` = `${pkgs.local-ai-assets}/share/local-ai/skills`
3. Orphan cleanup: delete files absent from BOTH sources

**Commands** (OpenCode): 1 source — `${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/commands`

**Commands** (Claude Code): 1 source — `${pkgs.gentle-ai-assets}/share/gentle-ai/claude/commands`

**AGENTS.md** (OpenCode): `${pkgs.gentle-ai-assets}/share/gentle-ai/AGENTS.md` (single file, no concat)

**review-gate.md**:
- OpenCode: `${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/review-gate.md` (443-line orchestrator)
- Claude Code: `${pkgs.gentle-ai-assets}/share/gentle-ai/review-gate.md` (18-line short version)

**Claude Code agents/personas**: `${pkgs.gentle-ai-assets}/share/gentle-ai/claude/agents`, `persona-*.md`, `output-style-*.md`

### Import Chain

```
host default.nix → home-manager → home-linux/shared-modules.nix
  → shared/opencode.nix (imports: agents.nix, gentle-ai-common.nix, permissions.nix, plugins.nix)
  → shared/opencode-profile.nix (imports: gentle-ai-common.nix)
  → shared/claude-code.nix (imports: gentle-ai-common.nix)
  → shared/claude-code-profile.nix (imports: gentle-ai-common.nix)
```

All 4 tools import `gentle-ai-common.nix` which defines the `home.gentle-ai` namespace:
- `home.gentle-ai.enable`
- `home.gentle-ai.skillsSource` (path to merged skills)
- `home.gentle-ai.localSkillsSource` (path to local skills)
- `home.gentle-ai.mcps` (base MCPs, defined in mcps-base.nix)
- `home.gentle-ai.extraMcps` (extension MCPs, defined in mcps.nix)
- `home.gentle-ai.engramConfig`

MCP options are also under `home.gentle-ai.mcps` namespace (mcps-base.nix, mcps.nix, home-darwin/opencode/mcps-extra.nix).

### agents.nix direct dependency

`shared/opencode/agents.nix` reads from BOTH:
- `${pkgs.gentle-ai-assets-vanilla}/share/gentle-ai/opencode/sdd-overlay-single.json` (upstream agent definitions)
- `${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/persona-gentleman.md` (overlaid persona)

This is the only reference to `gentle-ai-assets-vanilla` outside of the packages.nix/overlays plumbing.

### No host overrides

No host overrides `skillsSource` or `localSkillsSource` — all hosts use defaults.

## Affected Areas

### Derivations to create/rename/remove

| File | Action | Reason |
|------|--------|--------|
| `pkgs/gentle-ai-assets/default.nix` | **Replace** | New derivation: pure gentle-ai-src only (no caveman/ponytail). Same output structure but single source. |
| `pkgs/gentle-ai-assets/vanilla.nix` | **Remove** | No longer needed — no vanilla→layered chain |
| `pkgs/caveman-assets/default.nix` | **Create** | New derivation: caveman-src only (skills + commands) |
| `pkgs/ponytail-assets/default.nix` | **Create** | New derivation: ponytail-src only (skills + commands) |
| `pkgs/local-ai-assets/default.nix` | **Modify** | Already exists, may need expanded scope for local overrides |

### Package plumbing

| File | Action | Reason |
|------|--------|--------|
| `lib/packages.nix` | **Modify** | Remove vanilla, add caveman-assets + ponytail-assets; adjust sharedOpencodePaths |
| `overlays/linux.nix` | **Modify** | Remove `gentle-ai-assets-vanilla`; add `caveman-assets`, `ponytail-assets` |
| `overlays/darwin.nix` | **Modify** | Same as linux overlay |

### HM modules (namespace rename + N-way union)

| File | Action | Reason |
|------|--------|--------|
| `shared/gentle-ai-common.nix` → `shared/ai-assets.nix` | **Rename + rewrite** | Rename namespace `home.gentle-ai` → `home.ai-assets`. Replace `skillsSource` + `localSkillsSource` with `skillSources` (list of paths) |
| `shared/opencode.nix` | **Modify** | Import `ai-assets.nix` instead of `gentle-ai-common.nix`. Update activation: N-way skills union, N-way commands union, AGENTS.md concat from multiple sources |
| `shared/claude-code.nix` | **Modify** | Same updates as opencode.nix |
| `shared/opencode-profile.nix` | **Modify** | Update import path |
| `shared/claude-code-profile.nix` | **Modify** | Update import path |
| `shared/opencode/agents.nix` | **Modify** | Replace `pkgs.gentle-ai-assets-vanilla` with `pkgs.gentle-ai-assets` for sdd-overlay-single.json |
| `shared/opencode/mcps-base.nix` | **Modify** | Update `home.gentle-ai` → `home.ai-assets` |
| `shared/opencode/mcps.nix` | **Modify** | Update namespace |
| `home-darwin/opencode/mcps-extra.nix` | **Modify** | Update namespace |

### Cleanup

| File | Action | Reason |
|------|--------|--------|
| `shared/opencode/assets/skills/.gitkeep` | **Delete** + remove empty `skills/` dir | Empty directory, remnant from old override structure |
| `shared/assets/review-gate.md` | **Delete** | 18-line redundant version; the 443-line version at `shared/opencode/assets/opencode/review-gate.md` is the canonical one |

### Documentation

| File | Action | Reason |
|------|--------|--------|
| `docs/gentle-ai-update.md` | **Modify** | Update build commands, package names, verification steps |

## Approaches

### Approach 1: Minimal derivation split + N-way bash union (Recommended)

Each source gets its own derivation. The activation scripts iterate over a list of source paths for skills, commands, and AGENTS.md.

**Derivations:**
- `gentle-ai-assets` — from gentle-ai-src only, output: `$out/share/gentle-ai/` (AGENTS.md, opencode/, skills/, claude/)
- `caveman-assets` — from caveman-src only, output: `$out/share/caveman/` (skills/, commands/)
- `ponytail-assets` — from ponytail-src only, output: `$out/share/ponytail/` (skills/, commands/)
- `local-ai-assets` — existing, output: `$out/share/local-ai/` (skills/, plus new local overrides)

**HM options** (`home.ai-assets`):
```nix
skillSources = mkOption {
  type = types.listOf types.path;
  default = [
    "${pkgs.gentle-ai-assets}/share/gentle-ai/skills"
    "${pkgs.caveman-assets}/share/caveman/skills"
    "${pkgs.ponytail-assets}/share/ponytail/skills"
    "${pkgs.local-ai-assets}/share/local-ai/skills"
  ];
};

commandSources = mkOption {
  type = types.listOf types.path;
  # ...similar pattern
};
```

**Activation script**: bash loop over `skillSources` list — first to last, later wins on conflict. Same for commands. Orphan cleanup checks ALL sources.

**AGENTS.md concat**: Either a dedicated derivation (`concatTextFile`) or bash `cat` in activation. The concat derivation approach is cleaner (produces a store path, usable in `home.file`).

**Local overrides** (`review-gate.md`): Move the local `review-gate.md` to `local-ai-assets` with a mirrored path structure (e.g., `shared/assets/overrides/opencode/review-gate.md` → `$out/share/local-ai/overrides/opencode/review-gate.md`), handled as an additional path in the relevant source list. Or keep a slim `extraAssets` path in the HM options.

- **Pros**: Clean separation of concerns. Each source is independently updatable. Activation script is generalized (add a new source by extending the list). Minimal changes to existing derivation structure (vanilla.nix can be adapted rather than rewritten).
- **Cons**: N-way bash loops add complexity to already-complex activation scripts. AGENTS.md concat needs a new mechanism. Error handling for missing source paths needs care.
- **Effort**: Medium — ~15 files changed

### Approach 2: Nix-level merge derivation (pre-merged in a single derivation)

Instead of pushing the merge to the bash activation script, create a derivation that takes a list of source derivations and produces the merged output. The activation scripts then read from a single merged source.

- **Pros**: Activation scripts stay simple (single source). Merge logic is in Nix (evaluated at build time, not runtime). AGENTS.md concat happens at build time. Easier to test (just build the merge derivation).
- **Cons**: Re-introduces the "one big merged derivation" pattern we're trying to escape. Changes to any source invalidate the merge derivation cache. Still need the list-based option mechanism for flexibility.
- **Effort**: Medium-High

### Approach 3: Hybrid — derivations are independent, but a Nix-level merge derivation optionally combines them

A merge derivation exists but is optional — the HM options reference individual derivations AND a combined one. The activation scripts use the combined one by default but can be pointed at individual ones.

- **Pros**: Maximum flexibility. Both use cases supported.
- **Cons**: Over-engineered for a personal NixOS config. Two code paths to maintain.
- **Effort**: High

## Key Design Questions for `sdd-design`

1. **Where do local overrides go?** Currently `shared/opencode/assets/opencode/review-gate.md` overlays the upstream file via `extraAssets`. In the new model, should this live in `local-ai-assets` with a mirrored structure, or should we keep a dedicated `extraAssets` option?

2. **AGENTS.md concat mechanism**: A Nix derivation (`runCommand` with `cat`) vs bash in activation script? The derivation approach is more testable. But if only `gentle-ai-src` provides an AGENTS.md fragment, concat is trivial.

3. **Claude Code's 18-line review-gate.md**: After removing `shared/assets/review-gate.md`, claude-code needs an alternative source. The 443-line version at `shared/opencode/assets/opencode/review-gate.md` can be used, or the activation script can extract the relevant section.

4. **MCP namespace**: `home.gentle-ai.mcps` and `home.gentle-ai.extraMcps` should become `home.ai-assets.mcps` and `home.ai-assets.extraMcps`. This is a straightforward rename — no structural change needed.

5. **Commands merge**: Currently OpenCode commands are from `${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/commands`. After merging, caveman and ponytail each provide commands that need to land in `~/.config/opencode/commands/`. The activation script needs N-way union for commands too.

6. **Backward compatibility**: Is there any external consumer of these derivations or options? This is a personal NixOS config — no external consumers. Safe to rename aggressively.

## Recommendation

**Approach 1** — Minimal derivation split + N-way bash union — is recommended.

The primary goal (independent sources) is achieved cleanly without over-engineering. The bash union was already a pattern in the codebase (2-source union); extending to N sources is a natural generalization. The AGENTS.md concat can be handled by a small Nix derivation that takes a list of paths and concatenates existing files.

The key risk is activation script complexity. Mitigation: keep the bash loops structurally identical to the existing 2-source pattern, just generalize the source list. Test with `nix build` of affected hosts.

## Risks

- **Activation script regression**: The N-way union loops are more complex than the current 2-pass fixed pattern. A bug (wrong order, missing source) could corrupt the skills/ directory. Mitigate by using the same proven cmp-guard copy pattern.
- **commands/ merge conflicts**: If caveman-src and ponytail-src both provide a command with the same filename, the union order matters. This is already handled (later sources win), but needs to be explicit in the source list order.
- **AGENTS.md size**: If multiple sources provide AGENTS.md, concatenation could produce a very large file. Currently only gentle-ai-src provides one, so this is theoretical. Mitigate by only concatenating non-empty files.
- **Cache invalidation**: Each source derivation change invalidates its own cache, not others'. This is an improvement over the current model but means more derivations in the dependency graph. Build time impact is negligible for these small file-only derivations.

## Ready for Proposal

Yes — the exploration provides a complete map of the current state and clear options. Ready for `sdd-propose` to define scope, approach, and rollback plan.
