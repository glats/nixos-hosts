# Design: Gentle-AI NixOS Vanilla Integration

## Technical Approach

Keep current NixOS declarative structure intact, update gentle-ai binary v1.21.0 → v1.24.1, re-sync skills/commands from the new `gentle-ai-src` flake input, and create a comprehensive backup before any changes. The NixOS setup already correctly implements vanilla+TDD strict (byte-identical skills). The change is a version bump + skill sync + backup infrastructure.

## Architecture Decisions

### Decision: Backup Location & Structure

**Choice**: Timestamped directory under `.atl/backups/` in the repo
**Alternatives considered**: `/tmp/` (ephemeral), external disk (fragile), git stash (doesn't cover binary)
**Rationale**: `.atl/` is already an SDD-managed directory. Backups must survive a failed rebuild, so they need to persist. Git stash can't capture the Nix store hash. A structured directory with a manifest enables selective restore.

### Decision: Binary Version Update Method

**Choice**: Use the built-in `passthru.updateScript` in `pkgs/gentle-ai/default.nix`, then verify manually
**Alternatives considered**: Manual `sed` + `nix-prefetch-url`, flake input update only
**Rationale**: The update script already exists and handles version detection + hash prefetching. It writes version and sha256. Manual verification catches edge cases. The script updates `default.nix` in place, which is the cleanest approach.

### Decision: gentle-ai-src Flake Input Version Sync

**Choice**: Update `gentle-ai-src` flake input to the git tag matching the binary version (v1.24.1), then `nix flake update`
**Alternatives considered**: Leave at current rev (drift risk), use `github:Gentleman-Programming/gentle-ai/v1.24.1` tag pin
**Rationale**: Assets must match the binary. Currently `gentle-ai-src` uses `github:Gentleman-Programming/gentle-ai` without a tag — it floats to HEAD. Pinning to `v1.24.1` tag ensures the skills/commands/persona compiled into the binary match those in the derivation. The `gentle-ai-assets` package extracts from this input.

### Decision: Skill Re-sync Strategy

**Choice**: Nix rebuild handles it — `gentle-ai-assets` derivation already copies from `gentle-ai-src` input + local `extraSkills`. No manual `gentle-ai sync` needed.
**Alternatives considered**: Manual `gentle-ai sync` (DANGEROUS — overwrites Nix-managed files), rsync from extracted binary
**Rationale**: The `gentle-ai-assets` derivation in `pkgs/gentle-ai-assets/default.nix` already handles the full pipeline: copy from `gentle-ai-src` → prepend local persona rules → add extra skills from `modules/home/opencode/skills/`. These are deployed as Nix store symlinks via `home.file`. Running `gentle-ai sync` would break the Nix-managed symlinks. The `.last-sync` file needs updating after rebuild.

### Decision: Conflict Resolution for Local Skills

**Choice**: Extra skills in `modules/home/opencode/skills/` are overlaid AFTER upstream skills. If upstream adds a skill with the same name, upstream takes precedence in the Nix store, but local file wins via `extraSkills` parameter (last `cp -r` wins).
**Rationale**: The `gentle-ai-assets/default.nix` copies upstream skills first (`cp -r $src/internal/assets/skills/*`), then overlays extra skills (`cp -r ${extraSkills}/*`). This means local custom skills (caveman-*, nix-verify, etc.) overwrite upstream if same name. We need to check for name collisions during sync.

## Data Flow

```
Phase 0: Backup
    .atl/backups/{timestamp}/
    ├── manifest.yaml          ← Lists all 14 categories + checksums
    ├── flake.nix              ← Current flake
    ├── flake.lock             ← Current lock
    ├── pkgs/                  ← Current package definitions
    ├── modules/home/opencode/ ← Current opencode config
    └── checksums.sha256       ← Verification file

Phase 1: Version Bump
    pkgs/gentle-ai/default.nix  ← version: 1.21.0 → 1.24.1 + new hash
    flake.nix                   ← gentle-ai-src Pin to v1.24.1 tag
    nix flake update            ← Update flake.lock

Phase 2: Skill Re-sync (Automatic via Nix rebuild)
    gentle-ai-src (v1.24.1)
         │
         ▼
    gentle-ai-assets derivation
         ├── Copy upstream skills from src
         ├── Prepend local persona rules to PERSONA.md
         └── Overlay extra skills (caveman-*, nix-verify, etc.)
         │
         ▼
    home.file symlinks → ~/.config/opencode/skills/, commands/, etc.
         │
         ▼
    Update .last-sync timestamp

Phase 3: Validate
    nix flake check        ← Syntax validation
    nixos-build dry         ← Dry-run both hosts
    nixos-build switch     ← Apply on rog first, then thinkcentre
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `.atl/backups/{timestamp}/` | Create | Full backup of 14 categories before changes |
| `pkgs/gentle-ai/default.nix` | Modify | Version 1.21.0 → 1.24.1, new sha256 hash |
| `flake.nix` | Modify | Pin `gentle-ai-src` to tag `v1.24.1` |
| `flake.lock` | Modify | Updated by `nix flake update` after flake.nix change |
| `modules/home/opencode/.last-sync` | Modify | Update timestamp to reflect sync from v1.24.1 |
| `modules/home/opencode/agents.nix` | Possible Modify | If upstream orchestrator prompt changed in v1.24.1 |
| `modules/home/opencode/skills/*` | Possible Modify | If skill names collide with new upstream skills |

## Interfaces / Contracts

### Backup Manifest Schema (`manifest.yaml`)
```yaml
change: gentle-ai-nixos-vanilla-integration
timestamp: "2026-04-27T..."
gentle_ai_version_before: "1.21.0"
gentle_ai_version_after: "1.24.1"
categories:
  - name: host-configs
    paths: [hosts/rog/default.nix, hosts/thinkcentre/default.nix]
  - name: base-modules
    paths: [modules/base/]
  - name: hardware-modules
    paths: [modules/hardware/]
  - name: desktop-modules
    paths: [modules/desktop/, modules/features/desktop/]
  - name: service-modules
    paths: [modules/features/services/]
  - name: virtualisation-modules
    paths: [modules/virtualisation/]
  - name: networking-modules
    paths: [modules/networking/]
  - name: home-modules
    paths: [modules/home/]
  - name: custom-packages
    paths: [pkgs/]
  - name: flake-config
    paths: [flake.nix, flake.lock]
  - name: secrets
    paths: [secrets/, .sops.yaml]
  - name: opencode-config
    paths: [modules/home/opencode/]
  - name: overlays
    paths: [modules/base/overlays.nix]
  - name: custom-skills
    paths: [modules/home/opencode/skills/]
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Build | Flake syntax | `nix flake check` |
| Build | Host configs | `nixos-build dry` on rog |
| Build | Host configs | `nixos-build dry` on thinkcentre |
| Integration | gentle-ai binary runs | `gentle-ai --version` shows 1.24.1 |
| Integration | Skills deployed | `ls ~/.config/opencode/skills/` has all expected dirs |
| Integration | Personal rules | PERSONA.md starts with English-only rules |
| Integration | Extra skills | caveman-*, nix-verify present in skills/ |
| Regression | Services still work | Check key services after switch |

## Migration / Rollout

**Phase 0 — Backup** (must complete before any changes):
1. Create `.atl/backups/{timestamp}/` directory
2. Copy flake.nix, flake.lock, pkgs/, modules/home/opencode/, hosts/
3. Generate `checksums.sha256` for all backed-up files
4. Verify checksums match originals

**Phase 1 — Version Bump** (single atomic commit):
1. Run `pkgs/gentle-ai/default.nix`'s update script or manually update version+hash
2. Pin `gentle-ai-src` in flake.nix to tag v1.24.1
3. Run `nix flake update`
4. Run `nix flake check`

**Phase 2 — Deploy & Verify** (sequentially):
1. `nixos-build switch` on rog (primary)
2. Verify gentle-ai --version, skills, persona
3. `nixos-build switch` on thinkcentre (secondary)
4. Verify same

**Rollback Triggers**:
- `nix flake check` fails → fix before proceeding
- Binary hash mismatch → re-prefetch with `nix-prefetch-url`
- Skill collisions (upstream adds caveman-*) → rename local skill before merge
- `nixos-build switch` fails → `nixos-rebuild switch --rollback`

## Open Questions

- [ ] Does v1.24.1 orchestrator prompt differ from current? Need to compare `internal/assets/opencode/sdd-overlay-multi.json` after updating src
- [ ] Does v1.24.1 introduce any new skills that collide with local custom skills (caveman-*, nix-verify)?