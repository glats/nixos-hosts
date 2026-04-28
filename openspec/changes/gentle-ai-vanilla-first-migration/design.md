# Design: Gentle-AI Vanilla-First Migration

## Technical Approach

Migrate from the current heavily-customized gentle-ai setup to a vanilla-first architecture: run pure upstream assets in a parallel runtime, validate basic functionality, cutover production, then selectively restore customizations one layer at a time. This leverages the existing `runtime` mechanism (`stable`/`lab`/`both`) and the `vanilla.nix` derivation from the `gentle-ai-nixos-vanilla-integration` change.

## Architecture Decisions

### Decision: Backup Location & Structure

| Option | Tradeoff | Decision |
|--------|----------|----------|
| `.atl/backups/{ts}/` in repo | Git-tracked, survives rebuilds, discoverable | **Yes** |
| `/tmp/` backup | Ephemeral, lost on reboot | No |
| Git stash | Can't capture Nix store hash or runtime state | No |
| External disk | Fragile, manual | No |

**Chosen**: `.atl/backups/pre-vanilla-migration-{YYYYMMDD-HHMMSS}/` with MANIFEST.md (sha256 of every file) and `restore.sh`. Also create git tag `pre-vanilla-migration`. 14 categories backed up: `hosts/`, `modules/`, `pkgs/`, `secrets/`, `.sops.yaml`, `flake.nix`, `flake.lock`, `lib/`, `bin/`, `AGENTS.md`, `gentle-ai-investigation/`, `openspec/`, `.atl/`, `.opencode/` (local state).

### Decision: Vanilla Runtime Mode

| Option | Tradeoff | Decision |
|--------|----------|----------|
| New `vanilla` runtime in opencode.nix | Extends existing pattern, parallel testing | **Yes** |
| Replace `stable` directly | No rollback path, dangerous | No |
| Docker container isolation | Overkill, Nix can do this declaratively | No |
| Separate flake output | Doesn't test Home Manager integration | No |

**Chosen**: Add `vanilla` as a new runtime option. `home.opencode.runtime = "vanilla"` creates `~/.config/opencode-vanilla/` using **only** `gentle-ai-assets-vanilla` (no localPersonaRules, no extraSkills, no custom agents/MCPs). The `mkRuntimeConfig` function gets a new `vanilla` entry in `runtimeConfigs` that points to the vanilla derivation.

### Decision: Vanilla Config Generation

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Generate from upstream JSON template | Faithful to vanilla, minimal Nix code | **Yes** |
| Strip current config to vanilla | Easy to miss customizations, drift risk | No |
| Copy Docker investigation output | Snapshot, not declarative | No |

**Chosen**: For `opencode.json`, use `gentle-ai-src`'s embedded `sdd-overlay-multi.json` as the base (vanilla agents), extracted via `opencodeLib.extractFromJson`. No model overrides, no custom MCPs, no custom permissions — just what gentle-ai upstream provides. The vanilla runtime does NOT set custom agents, mcps, or permissions — it uses the upstream defaults directly.

### Decision: Cutover Method

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Switch `runtime` from `"stable"` to `"stable"` with vanilla assets | Nix rebuild, instant rollback via `nixos-rebuild --rollback` | **Yes** |
| Swap symlinks manually | Fragile, not declarative | No |
| Delete stable, copy vanilla over | Destructive, no rollback | No |

**Chosen**: Phase the cutover through the `home.opencode` module options:
1. Test phase: `runtime = "both"` (stable + vanilla side by side)
2. Cutover: Switch `assetsSource` from `"custom"` to `"vanilla"` for the stable runtime
3. Rollback: Revert the option change and `nixos-rebuild switch --rollback`

### Decision: Selective Restoration Architecture

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Add back one layer at a time via module options | Incremental, testable, declarative | **Yes** |
| Copy-paste from backup | Not declarative, drift risk | No |
| Merge all at once | Defeats vanilla-first purpose | No |

**Chosen**: Use `home.opencode` module options as toggle switches. Each restoration layer is a separate Nix option that composes on top of vanilla. Priority order:

- **P0 (Critical)**: `modelAssignments` — per-phase models (without this, all agents use default model)
- **P1 (Important)**: `mcpServers` — engram, github, nixos, context7, exa
- **P1 (Important)**: `permissions` — bash allow rules, read deny for secrets
- **P2 (Nice-to-have)**: `personaRules` — English-only, no-emojis prepend
- **P2 (Nice-to-have)**: `plugins` — engram.ts, background-agents.ts
- **P3 (Optional)**: `extraSkills` — caveman-*, nix-verify, go-testing, etc.
- **P3 (Optional)**: `orchestratorPrompt` — custom orchestrator with normalize-project-name

Each P-level is tested individually before moving to the next.

## Data Flow

```
Phase 0: Backup
  .atl/backups/pre-vanilla-migration-{ts}/
  ├── MANIFEST.md (sha256 of all files)
  ├── restore.sh (chmod 755, verify-then-restore)
  └── git tag pre-vanilla-migration

Phase 1: Vanilla Derivation & Runtime
  gentle-ai-src ──→ vanilla.nix ──→ gentle-ai-assets-vanilla
       │                                    │
       │                              (upstream-only assets)
       │                                    │
       ▼                                    ▼
  gentle-ai-assets (custom)    gentle-ai-assets-vanilla (clean)
       │                                    │
       ▼                                    ▼
  stable runtime               vanilla runtime
  ~/.config/opencode/          ~/.config/opencode-vanilla/
  (custom agents+mcps+persona) (upstream defaults only)

Phase 2: Cutover
  home.opencode.assetsSource = "vanilla"  ──→  stable uses vanilla assets
  
Phase 3: Selective Restoration (incremental)
  P0: modelAssignments ──→ test ──→ commit
  P1: mcpServers + permissions ──→ test ──→ commit
  P2: personaRules + plugins ──→ test ──→ commit
  P3: extraSkills + orchestratorPrompt ──→ test ──→ commit
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `pkgs/gentle-ai-assets/vanilla.nix` | Create | Copy-only derivation: upstream assets with no local modifications |
| `pkgs/gentle-ai-assets/default.nix` | Modify | Refactor to use vanilla derivation as base, overlay local mods on top |
| `flake.nix` | Modify | Add `gentle-ai-assets-vanilla` package, pin `gentle-ai-src` tag |
| `modules/home/opencode.nix` | Modify | Add `vanilla` runtime config, add `assetsSource` option |
| `modules/home/opencode/agents.nix` | Modify | Support vanilla mode (no custom agents when `assetsSource = "vanilla"`) |
| `modules/base/overlays.nix` | Modify | Expose `gentle-ai-assets-vanilla` package |
| `pkgs/gentle-ai/default.nix` | Modify | Version 1.21.0 → 1.24.1, new sha256 |
| `.atl/backups/pre-vanilla-migration-{ts}/` | Create | Full backup with MANIFEST.md and restore.sh |
| `bin/backup-vanilla-migration.sh` | Create | Automated backup script for Phase 0 |
| `bin/restore-vanilla-migration.sh` | Create | Restore script with checksum verification |

## Interfaces / Contracts

### New NixOS Module Option: `home.opencode.assetsSource`

```nix
home.opencode.assetsSource = mkOption {
  type = types.enum [ "custom" "vanilla" ];
  default = "custom";
  description = "Asset source for opencode configuration.";
};
```

When `"custom"`: uses `pkgs.gentle-ai-assets` (current behavior — localPersonaRules + extraSkills).
When `"vanilla"`: uses `pkgs.gentle-ai-assets-vanilla` (upstream only, no modifications).

### New Runtime Config: `vanilla`

```nix
runtimeConfigs.vanilla = {
  dir = "opencode-vanilla";
  label = "vanilla";
};
```

Creates `~/.config/opencode-vanilla/` with vanilla derivation assets and a minimal `opencode.json` generated from upstream defaults.

### Backup Manifest Schema

```yaml
change: gentle-ai-vanilla-first-migration
timestamp: "YYYY-MM-DDTHH:MM:SS"
gentle_ai_version: "1.24.1"
git_tag: pre-vanilla-migration
categories: [14 categories with paths]
checksums_sha256: auto-generated
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Build | Vanilla derivation builds cleanly | `nix build .#gentle-ai-assets-vanilla` |
| Build | Custom derivation still builds | `nix build .#gentle-ai-assets` |
| Build | Flake check passes | `nix flake check` |
| Build | Both hosts dry-run | `nixos-rebuild dry-build --flake .#rog` + `.#thinkcentre` |
| Integration | Vanilla runtime starts | `OPENCODE_CONFIG_DIR=~/.config/opencode-vanilla opencode` |
| Integration | Vanilla skills load | `ls ~/.config/opencode-vanilla/skills/`
| Integration | SDD workflow works in vanilla | Run `/sdd-init` in vanilla runtime |
| Integration | Cutover to vanilla stable works | Switch `assetsSource = "vanilla"`, rebuild, verify |
| Regression | Custom stable still works with `"custom"` | Verify existing config unchanged |
| Regression | Rollback works | `nixos-rebuild switch --rollback` |
| Per-layer | P0 model assignments | Verify agents use correct models after P0 restore |
| Per-layer | P1 MCP servers | Verify engram, github, nixos MCPs respond |
| Per-layer | P2 persona rules | Verify English-only + no-emojis in PERSONA.md |

## Migration / Rollout

**Phase 0 — Backup** (blocks all phases):
1. Run backup script → creates `.atl/backups/` + MANIFEST.md
2. Create git tag `pre-vanilla-migration`
3. Verify integrity (checksums match)

**Phase 1 — Vanilla Derivation & Runtime**:
1. Create `vanilla.nix` derivation
2. Add `gentle-ai-assets-vanilla` to flake outputs
3. Add `vanilla` runtime config to `opencode.nix`
4. Set `runtime = "both"` (stable + vanilla side by side)
5. Build and verify both runtimes

**Phase 2 — Validate Vanilla**:
1. Start vanilla runtime: `OPENCODE_CONFIG_DIR=~/.config/opencode-vanilla opencode`
2. Verify basic functionality: skills load, SDD commands, MCPs
3. Verify SDD workflow end-to-end

**Phase 3 — Cutover**:
1. Switch production: `assetsSource = "vanilla"` for stable runtime
2. Rebuild and verify
3. If any issue: `nixos-rebuild switch --rollback`

**Phase 4 — Selective Restoration** (P0 → P1 → P2 → P3):
Each P-level is a separate commit with testing:
- P0: Add `modelAssignments` → test → commit
- P1: Add `mcpServers` + `permissions` → test → commit
- P2: Add `personaRules` + `plugins` → test → commit
- P3: Add `extraSkills` + `orchestratorPrompt` → test → commit

**Rollback Triggers**:
- `nix flake check` fails → fix before proceeding
- Vanilla runtime doesn't start → diagnose, don't cutover
- SDD workflow broken in vanilla → add P0/P1 customization and retest
- Any host build fails → `nixos-rebuild switch --rollback`

## Open Questions

- [ ] Should vanilla `opencode.json` use the embedded `sdd-overlay-multi.json` directly, or generate a minimal config from Nix? (Leaning: extract from upstream JSON — faithful to vanilla)
- [ ] Current binary is v1.21.0 but upstream investigation used v1.24.1 — should this migration include the version bump? (Recommend: separate change, this one focuses on vanilla-first architecture)
- [ ] Should the vanilla runtime inherit `permissions` from the custom config or use upstream defaults? (Leaning: upstream defaults for true vanilla testing)