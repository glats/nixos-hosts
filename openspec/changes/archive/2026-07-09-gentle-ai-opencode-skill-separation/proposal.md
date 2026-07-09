# Proposal: gentle-ai-opencode-skill-separation

## Intent

Document the upstream/local boundary for gentle-ai assets deployed to `~/.config/opencode/`, and bring the unmanaged `sdd-review-policy.md` into the Nix pipeline -- the only file in `~/.config/opencode/` not tracked by any `.nix` file.

## Motivation

`sdd-review-policy.md` (115 lines, review loop policy) is manually placed and survives rebuilds only because orphan cleanup covers `skills/` and `commands/`, not root-level files. If `~/.config/opencode/` is nuked, this file is lost -- contradicting declarative NixOS. Additionally, no document describes which assets come from upstream vs local additions, making maintenance opaque as upstream evolves.

## Scope

| In | Out |
|----|-----|
| Move `sdd-review-policy.md` into extraAssets + opencode.nix deployment | Rewriting policy content |
| Document upstream/local boundary + override mechanism | Changing review gate behavior |
| Document policy/mechanism relationship | Upstream monitoring automation |
| Add sed-patch no-op validation | Local-skills allowlist (optional, deferred) |

## Capabilities

### Modified Capabilities

- **gentle-ai-asset-overlay**: Add `sdd-review-policy.md` to extraAssets; document complete inventory (both `opencode/` files: orchestrator + review-policy).
- **skill-deployment**: Add `sdd-review-policy.md` to opencode.nix home.file + activation loop, mirroring `sdd-orchestrator.md` pattern.
- **review-gates**: Note policy file is now Nix-managed (no behavior change).

## Approach

### 1. Bring sdd-review-policy.md into Nix (primary fix)

Copy `~/.config/opencode/sdd-review-policy.md` to `shared/opencode/assets/opencode/sdd-review-policy.md`. The existing `extraAssets` mechanism (`default.nix` line 68: `cp -r ${extraAssets}/. $TEMP_DIR/`) copies it into the nix store. Add to `opencode.nix`:

- `home.file` entry (after line 101, mirroring `sdd-orchestrator.md`)
- Activation for-loop entry (line 145, alongside `sdd-orchestrator.md`)

No new derivation needed. The manual file is replaced on next rebuild.

### 2. Document the boundary

Add a boundary section to repo `AGENTS.md` (or `openspec/specs/gentle-ai-asset-overlay/spec.md`):

| Layer | What | Origin |
|-------|------|--------|
| Skills (30) | SDD, caveman, workflow | Upstream (untouched) |
| Skills (+2) | nix-verify, opencode-session-recovery | Local (extraSkills) |
| Commands (12) | Caveman slash-commands | Upstream (untouched) |
| Agents (18 base) | sdd-overlay-single.json | Upstream |
| Agent overlays | Engram tools, permissions, instructions | Local (local-agent-overlays.json + agents.nix merge) |
| sdd-orchestrator.md | 431-line upstream base + 42-line local additions (Review Gate, Session Startup) | Mixed (extraAssets override) |
| sdd-review-policy.md | Review loop policy (115 lines) | Local (extraAssets, NEW) |
| IDENTITY.md | Persona | Local (home.file) |
| instructions/universal.md | Common rules | Local (home.file) |

**Override mechanism**: `extraSkills` replaces entire skill directories; `extraAssets` copies a mirrored tree over vanilla, overwriting matching files. `agents.nix` reads upstream JSON + merges `local-agent-overlays.json` via `__replace__` markers.

### 3. Document policy/mechanism pair

`sdd-review-policy.md` (WHAT: diagram, protocol, guard lines) and `sdd-orchestrator.md` Review Gate section (HOW: artifact resolution, verdict table, binary decision) form a policy/mechanism pair. Both are local; both will be Nix-managed after this change.

### 4. Risk mitigations

- **Sed fragility**: Add `|| echo "WARNING: sdd-apply/verify model-capable marker not found" >&2` after lines 189-190 in opencode.nix.
- **Upstream divergence**: Document merge strategy in boundary docs (diff vanilla vs local on upstream updates).
- **Agent fragmentation**: Document the 3-source merge (upstream JSON + local overlays + agents.nix `__replace__` logic) in boundary docs.

## Affected Areas

| Area | Change | Files |
|------|--------|-------|
| extraAssets | Add file | `shared/opencode/assets/opencode/sdd-review-policy.md` (new) |
| opencode deployment | 2 additions | `shared/opencode.nix` (+home.file, +activation loop) |
| Boundary docs | New section | `AGENTS.md` or spec |
| Sed validation | Add warning | `shared/opencode.nix` (line 190) |

## Risks

| Risk | Mitigation |
|------|------------|
| Orphan cleanup deletes manual file before home.file deploys | home.file runs before activation; orphan cleanup only touches `skills/` and `commands/` |
| sdd-orchestrator.md reference breaks | File path unchanged -- only SOURCE moves into Nix store |

## Rollback Plan

Remove the home.file entry + activation loop line from `opencode.nix`, delete `shared/opencode/assets/opencode/sdd-review-policy.md`. Rebuild restores manual placement behavior.

## Dependencies

None. No new flake inputs, no upstream PRs needed.

## Success Criteria

- [ ] `shared/opencode/assets/opencode/sdd-review-policy.md` exists with policy content
- [ ] `nix flake check --no-build` passes for all hosts
- [ ] After rebuild, `~/.config/opencode/sdd-review-policy.md` is a real file matching source
- [ ] Boundary documentation lists all upstream vs local assets
- [ ] Sed no-op warning fires when upstream removes the model-capable marker
