# Design: Gentle AI Freshly Into NixOS for OpenCode

## Technical Approach

Split the monolithic `default.nix` into a pure upstream `vanilla.nix` and a layered `default.nix` that composes on top. Pin `gentle-ai-src` to `v1.21.0` tag in `flake.nix`. The vanilla derivation copies all upstream assets verbatim (including ALL plugins); the default derivation uses `runCommand` to copy-vanilla-then-overlay local persona rules and 21 skill directories only. Plugins are NOT touched by the layered derivation — upstream plugins come from vanilla, local-only plugins (engram.ts) are copied by the activation script.

## Architecture Decisions

### Decision: Composition Method

| Option | Tradeoff | Decision |
|--------|----------|----------|
| `runCommand` on vanilla derivation | Simple, explicit, writable copy-then-overlay | **Yes** |
| `symlinkJoin` with `paths` | Can't overwrite individual files inside dirs (persona) | No |
| `stdenvNoCC.mkDerivation` with phases | Heavier than needed, no source to unpack | No |
| `buildEnv` | For package environments, not file trees | No |

**Rationale**: `runCommand` is the lightest Nix primitive for "copy from A, modify, output B". It handles the persona-prepend and skill-overlay naturally because `$out` is writable after copy. `symlinkJoin` fails because persona-gentleman.md sits inside `opencode/` — you can't symlink the dir and override one file.

### Decision: vanilla.nix uses stdenvNoCC.mkDerivation

| Option | Tradeoff | Decision |
|--------|----------|----------|
| `stdenvNoCC.mkDerivation` with `src` | Standard pattern, `version` from `gentle-ai-src.rev` | **Yes** |
| `runCommand` | Needs manual version passthru, less idiomatic | No |

**Rationale**: Vanilla follows the same pattern as the current `default.nix` (mkDerivation with installPhase). It sets `version` from the source rev, giving us a traceable version string. `runCommand` doesn't natively support `version`/`meta` without extra wrapping.

### Decision: default.nix takes `vanilla` as argument instead of `gentle-ai-src`

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Pass `vanilla` derivation directly | Clean dependency, no duplicated src logic | **Yes** |
| Pass `gentle-ai-src` + re-derive inside | Duplicates vanilla logic, defeats separation | No |

**Rationale**: `default.nix` should not know about upstream source structure — that's vanilla's job. Passing the pre-built `vanilla` derivation makes the layering explicit and testable: build vanilla alone, then build layered on top.

### Decision: Version pinning via tag in flake.nix

| Option | Tradeoff | Decision |
|--------|----------|----------|
| `url = "github:owner/repo/v1.21.0"` | Immutable, explicit, matches binary | **Yes** |
| Branch ref with lock file | Lock can drift on `nix flake update` | No |

**Rationale**: Tags are immutable and self-documenting. A branch ref (`master`) causes lock drift when `--update-input` is run for other reasons.

### Decision: Upstream plugins only, no local overrides

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Always use upstream plugins, PR fixes upstream | No local drift, simpler derivation | **Yes** |
| Local plugin overrides for bug fixes | Quick fixes, but creates maintenance burden | No |

**Rationale**: Local plugin overrides create a maintenance burden and drift from upstream. If an upstream plugin has a bug, the fix should be contributed upstream. The only exception is `engram.ts`, which does not exist upstream and is 100% local — handled by the activation script, not the derivation.

## Data Flow

```
flake.nix
  │
  ├── gentle-ai-src (pinned to v1.21.0)
  │       │
  │       ▼
  │   vanilla.nix ──► gentle-ai-assets-vanilla (pure upstream)
  │       │                                │
  │       │                                │ includes ALL plugins/
  │       │                                ▼
  │   default.nix ──► gentle-ai-assets (vanilla + local)
  │       │                   │
  │       │               ┌───┴───┐
  │       │               │       │
  │       │         prepend persona  overlay skills/
  │       │         (writeText)    (extraSkills/)
  │       │               │       │
  │       │               └───┬───┘
  │       │                   │
  │       │                $out/share/gentle-ai/
  │       │                   │
  │       ▼                   ▼
  │   overlays.nix ──► pkgs.gentle-ai-assets
  │   overlays.nix ──► pkgs.gentle-ai-assets-vanilla
  │
  └── opencode.nix ──► ${pkgs.gentle-ai-assets}/share/gentle-ai/...
                         │
                         ├── upstream plugins from nix store path
                         │   (e.g., background-agents.ts)
                         │
                         └── engram.ts from local path (special case)
                             (does NOT exist upstream)
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `pkgs/gentle-ai-assets/vanilla.nix` | Create | Pure upstream copy: AGENTS.md, opencode/ (including ALL plugins/), skills/, agent configs |
| `pkgs/gentle-ai-assets/default.nix` | Modify | Refactored: takes `vanilla` + `writeText` + `extraSkills`, overlays persona + skills only (NO plugin overlay) |
| `flake.nix` | Modify | Pin `gentle-ai-src` to `v1.21.0`, add `gentle-ai-assets-vanilla` package, update callPackage |
| `modules/base/overlays.nix` | Modify | Expose `gentle-ai-assets-vanilla` |
| `modules/home/opencode.nix` | Modify | Fix activation script: upstream plugins from nix store, engram.ts from local path |
| `modules/home/opencode/plugins/background-agents.ts` | Delete | Use upstream version instead of local override |
| `modules/home/opencode/plugins/engram.ts` | Keep | 100% local plugin — does not exist upstream |
| `modules/home/opencode/.last-sync` | Modify | Update marker from `v1.23.0` to `v1.21.0` |
| `docs/gentle-ai-update.md` | Create | Step-by-step update workflow |
| `openspec/config.yaml` | Modify | Set `strict_tdd: true` (was false) |

## Interfaces / Contracts

### `vanilla.nix` — Function Signature

```nix
{ lib, stdenvNoCC, gentle-ai-src }:
# Input: only upstream source, no local args
# Output: derivation with $out/share/gentle-ai/{AGENTS.md, opencode/{plugins/,commands/,...}, skills/, claude/, ...}
# Version: gentle-ai-src.rev or "unstable"
# Note: copies ALL of internal/assets/opencode/plugins/ — no exclusions
```

### `default.nix` — Function Signature

```nix
{ lib, stdenvNoCC, writeText, vanilla, extraSkills ? null }:
# Input:  vanilla      — derivation from vanilla.nix
#         writeText    — for localPersonaRules
#         extraSkills  — path to local skills dir (nullable)
#         # NO extraPlugins — plugins are NOT layered
# Output: derivation with $out/share/gentle-ai/ (vanilla + persona prepend + skill overlay)
#         plugins/ is identical to vanilla (no modifications)
```

### `flake.nix` — Package Wiring

```nix
gentle-ai-assets-vanilla = pkgs.callPackage ./pkgs/gentle-ai-assets/vanilla.nix {
  inherit gentle-ai-src;
};
gentle-ai-assets = pkgs.callPackage ./pkgs/gentle-ai-assets/default.nix {
  inherit (pkgs) writeText;
  inherit gentle-ai-assets-vanilla;
  extraSkills = ./modules/home/opencode/skills;
  # NO extraPlugins — plugins handled by activation script
};
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Build | Vanilla derivation builds | `nix build .#gentle-ai-assets-vanilla` |
| Build | Layered derivation builds | `nix build .#gentle-ai-assets` |
| Build | Flake check passes | `nix flake check` |
| Content | Vanilla is unmodified | Diff vanilla output against `gentle-ai-src` files |
| Content | Persona rules prepended | `head -5 .../persona-gentleman.md` shows local rules |
| Content | All 21 local skills present | `ls .../skills/ | wc -l` includes local dirs |
| Content | Local skill overrides upstream | `caveman/SKILL.md` is local version, not upstream |
| Content | Upstream plugins in vanilla | `ls .../opencode/plugins/` contains upstream plugins |
| Content | Layered plugins = vanilla plugins | Diff layered plugins/ vs vanilla plugins/ — identical |
| Content | Activation uses nix store for upstream | Grep `opencode.nix` — upstream plugins use `${pkgs.gentle-ai-assets}/...` |
| Content | Activation uses local path for engram.ts | Grep `opencode.nix` — engram.ts uses `${./opencode/plugins/engram.ts}` |
| Config | TDD strict enabled by default | `openspec/config.yaml` has `strict_tdd: true` |

## Migration / Rollout

No migration required. The change is a pure refactor of the derivation with identical external output. If any issue arises:
1. `git checkout HEAD -- pkgs/gentle-ai-assets/default.nix flake.nix modules/base/overlays.nix`
2. Remove `vanilla.nix`
3. Verify: `nix build .#gentle-ai-assets && nix flake check`

## Open Questions

- [ ] Should `gentle-ai-src.rev` change from commit hash to semantic version when pinned to a tag? (Current code uses `rev or "unstable"` which gives a commit SHA; pinned tag still resolves to SHA in `flake.lock`)
- [ ] Should upstream `background-agents.ts` plugin be enabled by default, or remain opt-in via `plugins.nix` toggle?
