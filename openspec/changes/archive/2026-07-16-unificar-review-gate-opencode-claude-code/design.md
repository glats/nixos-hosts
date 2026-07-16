# Design: Unify Review Gate across OpenCode and Claude Code

## Technical Approach

Extract the review gate content (lines 410-429 of `shared/opencode/assets/opencode/review-gate.md`) into a new platform-agnostic file `shared/assets/review-gate.md`. Route it to Claude Code through the `gentle-ai-assets` derivation (consistent with every other asset): `lib/packages.nix` passes `shared/assets/` as `extraAssetsShared`, `pkgs/gentle-ai-assets/default.nix` copies it into the store, and `shared/claude-code.nix` points its `home.file` source at the derivation path. OpenCode stays unchanged — its review gate is baked into the orchestrator overlay.

## Architecture Decisions

### Decision: Source file location

| Option | Tradeoff | Decision |
|--------|----------|----------|
| `shared/assets/review-gate.md` | New `shared/assets/` dir, parallel to `shared/opencode/assets/` | Chosen |
| Inline in `claude-code.nix` as `text = ''...''` | No new file, but couples content to Nix expression | Rejected |

**Rationale**: `shared/assets/` is the natural home for cross-platform shared assets. Keeping content in a `.md` file (not inline Nix `text`) allows non-Nix editing and re-use. Matches the pattern of `shared/opencode/assets/`.

### Decision: OpenCode stays as-is

**Choice**: Do NOT modify `shared/opencode.nix` or `shared/opencode/assets/opencode/review-gate.md`.
**Alternatives considered**: Extract OpenCode's review-gate.md to also source from `shared/assets/review-gate.md`.
**Rationale**: OpenCode's review gate is embedded in a 443-line orchestrator overlay. Extracting it would require splitting the overlay, changing the derivation, and updating the deployment path — large blast radius for a content-unification change. Out of scope per proposal. Future refactor can handle it.

### Decision: Platform-agnostic content

**Choice**: Replace "question tool" with "interactive prompt". Remove any MCP-specific references.
**Alternatives considered**: Keep the exact OpenCode wording.
**Rationale**: The file will be read by Claude Code, which has no "question" tool. Generic wording works for both platforms.

### Decision: File goes through derivation (not direct path)

| Option | Tradeoff | Decision |
|--------|----------|----------|
| `source = ./assets/review-gate.md` (direct path) | Simpler, one fewer moving part | Rejected |
| Via `gentle-ai-assets` derivation (`extraAssetsShared`) | Consistent with all other assets, survives Nix store immutability | Chosen |

**Rationale**: The user REQUIRED consistency — every asset (`extraSkills`, `extraAssets`) goes through the derivation. A direct `./assets/` path would be inconsistent: it would bypass the store and couple the file to the source tree at evaluation time, making it unresolvable when the source tree isn't available. The derivation pattern is battle-tested across all other assets.

## Data Flow

```
shared/assets/review-gate.md (NEW — single source)
         │
         ├──→ lib/packages.nix (extraAssetsShared = ./../shared/assets)
         │         │
         │         ├──→ pkgs/gentle-ai-assets/default.nix (new installPhase cp)
         │         │         │
         │         │         └──→ /nix/store/.../share/gentle-ai/review-gate.md
         │         │                    │
         │         │                    └──→ shared/claude-code.nix (source = derivation path)
         │         │                              └──→ ~/.claude/review-gate.md
         │         │
         │         └──→ (future: shared/opencode.nix could use same mechanism — NOT NOW)
         │
         └──→ OpenCode: goes through its own extraAssets at shared/opencode/assets/opencode/review-gate.md (UNCHANGED)
                   └──→ shared/opencode.nix (gentle-ai-assets derivation)
                            └──→ ~/.config/opencode/review-gate.md
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `shared/assets/review-gate.md` | Create | Platform-agnostic review gate content (done/retry/reiterate) |
| `lib/packages.nix` | Modify | Add `extraAssetsShared = ./../shared/assets;` to `sharedOpencodePaths`, pass to both linux and darwin `gentle-ai-assets` via `inherit` |
| `pkgs/gentle-ai-assets/default.nix` | Modify | Add `extraAssetsShared ? null` parameter, new installPhase block to copy `extraAssetsShared` into TEMP_DIR (same pattern as existing `extraAssets` block) |
| `shared/claude-code.nix` | Modify | Change `source` from old derivation path to `${pkgs.gentle-ai-assets}/share/gentle-ai/review-gate.md` |

## New File Content: `shared/assets/review-gate.md`

```markdown
# Review Gate (MANDATORY)

After every `sdd-apply` slice returns and before launching any subsequent
`sdd-apply` or `sdd-verify`, the orchestrator MUST present the review decision.
This gate MUST NOT be skipped regardless of apply outcome.

Do NOT attempt to locate a pre-existing review artifact. Instead, ALWAYS
present this question directly via an interactive prompt, with EXACTLY three
options:

1. **done** — verify -> archive. The change is correct.
2. **retry** — re-apply only, no re-explore. Same spec, same design. Small fix.
3. **reiterate** — full SDD cycle from explore. Large rework, needs rethinking.

Record the chosen verdict as the review artifact (`mem_save`, topic_key
`sdd/{change-name}/review` and/or `openspec/changes/{change-name}/review.md`).

Do NOT offer a fourth option. Do NOT auto-advance. Do NOT launch `sdd-verify`
unless the verdict is `done`.
```

Changes from original (lines 410-429): "via the `question` tool" → "via an interactive prompt". All other text identical.

## Edit: `lib/packages.nix`

Add `extraAssetsShared` to `sharedOpencodePaths` and pass it to `gentle-ai-assets` on both linux and darwin branches:

```nix
  sharedOpencodePaths = {
    extraSkills = ./../shared/skills;
    extraAssets = ./../shared/opencode/assets;
    extraAssetsShared = ./../shared/assets;  # NEW
  };

  gentle-ai-assets-linux = pkgs.callPackage ./pkgs/gentle-ai-assets {
    inherit (sharedOpencodePaths) extraSkills extraAssets extraAssetsShared;
  };
```

Line count: ~3 lines added (1 in the attrset, 1 `inherit` on each of 2 callPackage sites).

## Edit: `pkgs/gentle-ai-assets/default.nix`

Add parameter and copy block:

```nix
, extraAssetsShared ? null   # NEW — shared cross-platform assets (e.g. review-gate.md)
}:

let
  # ... existing code ...

  # NEW: copy extraAssetsShared if provided
  ${optionalString (extraAssetsShared != null) ''
    cp -r ${extraAssetsShared}/* "$TEMP_DIR/"
  ''}
```

The copy goes into the same `installPhase` as the existing `extraAssets` block. Identical pattern: `cp -r <source>/* "$TEMP_DIR/"`.

## Edit: `shared/claude-code.nix`

Current (lines 146-155):

```nix
    home.file = {
      ".claude/settings.json" = {
        force = true;
        source = settingsJson;
      };
      ".claude/review-gate.md" = {
        force = true;
        source = "${pkgs.gentle-ai-assets}/share/gentle-ai/claude/sdd-orchestrator.md";
      };
    };
```

After:

```nix
    home.file = {
      ".claude/settings.json" = {
        force = true;
        source = settingsJson;
      };
      ".claude/review-gate.md" = {
        force = true;
        source = "${pkgs.gentle-ai-assets}/share/gentle-ai/review-gate.md";
      };
    };
```

Only line 153 changes: old derivation path `claude/sdd-orchestrator.md` → `review-gate.md`.

## Why `shared/opencode.nix` Does NOT Change

OpenCode's review gate (lines 91-94) deploys from the `gentle-ai-assets` derivation, which bakes `shared/opencode/assets/opencode/review-gate.md` into a Nix store path. That file is part of a 443-line orchestrator overlay. Extracting just the gate section would require splitting the overlay into two files, updating the derivation build, and changing the source path — a refactor outside this change's scope. The current OpenCode path works correctly; leaving it untouched satisfies RG-003 (no regression).

## Host Coverage

All 4 hosts import `shared/claude-code.nix`:

| Host | Import Path | Line |
|------|------------|------|
| rog | `home-linux/shared-modules.nix` | 36 |
| thinkcentre | `home-linux/shared-modules.nix` | 36 |
| t14 | `hosts/t14/home/omarchy.nix` | 113 |
| mact2 | `home-darwin/shared-modules.nix` | 35 |

No host-specific changes needed — all inherit automatically.

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Build | `nix flake check --no-build` | Must exit 0 |
| Build | `nix build .#nixosConfigurations.t14.config.system.build.toplevel` | Fastest host build to verify derivation path resolves |
| Build | `nix build .#gentle-ai-assets` | Verify derivation produces `review-gate.md` in store |
| Deploy | `home-manager switch` on any host | Check `~/.claude/review-gate.md` exists |
| Content | `grep -E 'done|retry|reiterate' ~/.claude/review-gate.md` | All 3 options present |
| No regression | `git diff shared/opencode.nix` | Zero changes |
| No regression | `diff ~/.config/opencode/review-gate.md` before/after | Identical |

## Migration / Rollout

No migration required. `force = true` is already set on the `home.file` entry, so home-manager will overwrite the existing file on next switch.

## Open Questions

None. This is a 4-file change with no ambiguity (1 create, 3 edit).
