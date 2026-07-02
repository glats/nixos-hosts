# Design: anti-hallucination-sdd-paths

## Technical Approach

Add a generic `extraAssets` overlay parameter to the `gentle-ai-assets` derivation. This parameter accepts a directory whose structure mirrors `$out/share/gentle-ai/` and recursively copies on top of vanilla assets, overwriting matching files. Three override files in `shared/opencode/assets/` inject anti-hallucination notes into `sdd-orchestrator.md`, `sdd-explore/SKILL.md`, and `sdd-init/SKILL.md`. The `sdd-orchestrator.md` source in `shared/opencode.nix` switches from `gentle-ai-assets-vanilla` to `gentle-ai-assets` so the layered version is deployed.

## Architecture Decisions

### Decision: `extraAssets` as recursive directory overlay

**Choice**: New `extraAssets ? null` parameter; `cp -r ${extraAssets}/. $out/share/gentle-ai/` after vanilla copy.
**Alternatives considered**: (a) Per-file patch parameters, (b) forking the derivation, (c) inline `sed` patches in activation script.
**Rationale**: Mirrors existing `extraSkills`/`extraCommands` pattern. Convention-based: `shared/opencode/assets/` mirrors `$out/share/gentle-ai/` structure. Single mechanism handles any future file override without derivation changes. Activation-script `sed` patches are the fragile approach this change replaces.

### Decision: Keep `extraCommands` separate from `extraAssets`

**Choice**: `extraAssets` is a new parameter; `extraCommands` is not deprecated.
**Alternatives considered**: Deprecate `extraCommands`, fold into `extraAssets`.
**Rationale**: `extraCommands` is for executable scripts in `opencode/commands/`; `extraAssets` is for arbitrary static files at any depth. Different semantics. Combining them adds confusion without benefit.

### Decision: Source orchestrator from layered asset

**Choice**: `shared/opencode.nix:100` uses `${pkgs.gentle-ai-assets}` instead of `${pkgs.gentle-ai-assets-vanilla}`.
**Alternatives considered**: Keep sourcing from vanilla, patch only in activation.
**Rationale**: When overrides exist, the layered asset IS the authoritative source. Sourcing from vanilla defeats the purpose. The activation script already deploys skills/commands from `gentle-ai-assets`; the orchestrator file should follow the same pattern.

### Decision: Override files are full copies, not patches

**Choice**: `shared/opencode/assets/` contains complete file copies (vanilla + anti-hallucination note appended).
**Alternatives considered**: Diff/patch files, `sed` injection at build time.
**Rationale**: Full copies are diffable, reviewable, and survive `nix flake update` with a clear regeneration procedure. Patches are fragile and opaque.

## Data Flow

```
shared/opencode/assets/          pkgs/gentle-ai-assets/default.nix
┌─────────────────────┐          ┌──────────────────────────────────┐
│ opencode/           │          │ 1. Copy vanilla → $TEMP_DIR      │
│   sdd-orchestrator.md│──┐      │ 2. Overlay extraSkills           │
│ skills/             │  │      │ 3. Overlay extraCommands          │
│   sdd-explore/      │  ├─────▶│ 4. Overlay extraAssets (NEW)      │
│     SKILL.md        │  │      │ 5. Move $TEMP_DIR → $out/...      │
│   sdd-init/         │  │      └──────────────────────────────────┘
│     SKILL.md        │──┘                  │
└─────────────────────┘                    ▼
                                $out/share/gentle-ai/
                                          │
                    ┌─────────────────────┤
                    ▼                     ▼
         shared/opencode.nix     activation script
         (sdd-orchestrator.md    (skills/, commands/
          home.file symlink)      directory sync)
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `pkgs/gentle-ai-assets/default.nix` | Modify | Add `extraAssets ? null` parameter; add recursive copy block after `extraCommands` |
| `lib/packages.nix` | Modify | Add `extraAssets` to `sharedOpencodePaths`; pass to both platform `gentle-ai-assets` |
| `shared/opencode/assets/opencode/sdd-orchestrator.md` | Create | Vanilla copy + anti-hallucination note in Artifact Store Policy section |
| `shared/opencode/assets/skills/sdd-explore/SKILL.md` | Create | Vanilla copy + anti-hallucination note after Retrieving Context section |
| `shared/opencode/assets/skills/sdd-init/SKILL.md` | Create | Vanilla copy + anti-hallucination note after Hard Rules section |
| `shared/opencode.nix` | Modify | Line 100: `gentle-ai-assets-vanilla` → `gentle-ai-assets` |

## Interfaces / Contracts

### `extraAssets` parameter contract

```nix
# pkgs/gentle-ai-assets/default.nix signature
{ lib, stdenvNoCC, vanilla, extraSkills ? null, extraCommands ? null, extraAssets ? null }:
```

**Convention**: `extraAssets` directory structure MUST mirror `$out/share/gentle-ai/`. Example:
```
extraAssets/
├── opencode/sdd-orchestrator.md   → overwrites $out/share/gentle-ai/opencode/sdd-orchestrator.md
└── skills/sdd-explore/SKILL.md    → overwrites $out/share/gentle-ai/skills/sdd-explore/SKILL.md
```

### Build-phase insertion point

In `installPhase`, after the `extraCommands` conditional block (line 59) and before "Move to final destination" (line 62):

```bash
# Overlay extra assets (arbitrary file overrides)
if [ -n "${extraAssets}" ] && [ -d "${extraAssets}" ]; then
  cp -r ${extraAssets}/. $TEMP_DIR/
fi
```

Uses Nix-level conditional (same pattern as `extraCommands`) for evaluation-time safety. The `cp -r ${extraAssets}/.` copies contents (not the directory itself) into `$TEMP_DIR`, overwriting matching paths.

### Anti-hallucination note content

**For `sdd-orchestrator.md`** — insert after line 74 (end of Artifact Store Policy bullet list):
```markdown
> **Anti-hallucination**: The Engram topic key prefix `sdd/` (e.g., `sdd/{change-name}/proposal`) refers to Engram memory keys, NOT filesystem paths. The canonical filesystem path for SDD artifacts is `openspec/changes/`. Do NOT reference `.sdd/`, `sdd/`, or `sdds/` as filesystem directories. These do not exist.
```

**For `sdd-explore/SKILL.md`** — insert after line 57 (end of "Retrieving Context" section):
```markdown
> **Anti-hallucination**: Engram topic keys use `sdd/` prefix for memory organization — this is NOT a filesystem path. The canonical filesystem directory for SDD artifacts is `openspec/`. Never reference `.sdd/`, `sdds/`, or bare `sdd/` as filesystem paths.
```

**For `sdd-init/SKILL.md`** — insert after line 44 (end of "Hard Rules" section):
```markdown
> **Anti-hallucination**: Engram topic keys use `sdd/` prefix for memory organization — this is NOT a filesystem path. The canonical filesystem directory for SDD artifacts is `openspec/`. Never reference `.sdd/`, `sdds/`, or bare `sdd/` as filesystem paths.
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Build | `extraAssets` overlay produces correct output | `nix build .#gentle-ai-assets` then `grep "Anti-hallucination" result/share/gentle-ai/opencode/sdd-orchestrator.md` |
| Integration | Activation deploys overridden files | `nixos-build dry` then `nixos-build switch`; verify `~/.config/opencode/sdd-orchestrator.md` contains note |
| Regression | Vanilla assets still deploy correctly | Verify `AGENTS.md`, skills, commands all present after build |
| Cross-platform | Darwin build works | `nix build .#darwinPackages.x86_64-darwin.gentle-ai-assets` |

## Migration / Rollout

No migration required. The change is additive:
1. `extraAssets ? null` defaults to null — existing consumers unaffected
2. Override files are new — no existing files modified in-repo
3. `shared/opencode.nix` source switch is a single-line change with immediate effect on next `nixos-build switch`

### Vanilla drift mitigation

When `gentle-ai-src` flake input is updated, override files in `shared/opencode/assets/` may carry stale logic. Regeneration procedure:
1. `nix build .#gentle-ai-assets-vanilla`
2. Diff `result/share/gentle-ai/opencode/sdd-orchestrator.md` against `shared/opencode/assets/opencode/sdd-orchestrator.md`
3. Re-apply anti-hallucination note to updated vanilla content
4. Repeat for `sdd-explore/SKILL.md` and `sdd-init/SKILL.md`

Track 2 (upstream PR) eliminates drift risk by making the notes part of vanilla itself.

## Open Questions

- [ ] Should `_shared/sdd-phase-common.md` also receive an anti-hallucination note? (Lower priority — it's referenced by skills, not read as a standalone prompt)
