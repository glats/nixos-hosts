# Design: Cleanup OpenCode Old Configs

## Technical Approach

Straightforward deletion and simplification refactor. No new features — remove 4 dead scripts, strip the `legacyFallback` option (migration complete), and validate builds. The lab/stable runtime system stays untouched.

## Architecture Decisions

### Decision: Remove vs Deprecate legacyFallback

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Keep with deprecation warning | Slower cleanup, cluttered module | ❌ Rejected |
| Remove entirely | Clean module, one NixOS rebuild required | ✅ Chosen |

**Rationale**: Migration is complete. `opencode-profile.nix` already sets `legacyFallback = false`. The `opencode-legacy.nix` module it references doesn't exist. Dead option adds confusion.

### Decision: Keep lab runtime

**Choice**: Keep both `stable` and `lab` runtime modes
**Alternatives**: Merge into single runtime
**Rationale**: User actively uses lab for isolated experimentation. No spec touches runtime mode — out of scope.

### Decision: Remove gentle-ai-tui from package derivation

**Choice**: Delete script file AND remove its install line from `pkgs/nixos-scripts/default.nix`
**Alternatives**: Keep derivation entry, point to missing file (broken build)
**Rationale**: The script downloads releases directly, bypassing Nix. It must be removed from both `bin/` and the derivation.

## Data Flow

No data flow changes. Removal only:

```
opencode.nix (module)
  ├─ options.home.opencode.enable     ← KEEP
  ├─ options.home.opencode.runtime     ← KEEP (stable/lab/both)
  ├─ options.home.opencode.legacyFallback  ← DELETE
  └─ config warnings block                  ← DELETE

opencode-profile.nix (profile)
  ├─ enable = true                     ← KEEP
  ├─ runtime = "stable"                ← KEEP
  ├─ legacyFallback = false            ← DELETE
  └─ plugins/tuiPlugins                ← KEEP

pkgs/nixos-scripts/default.nix (package)
  └─ cp $src/gentle-ai-tui ...         ← DELETE(line 45-46)
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `bin/sync-opencode-remote` | Delete | Broken — references missing `opencode.json.base` |
| `bin/sync-opencode-mac.sh` | Delete | Outdated API model mappings (deepinfra) |
| `bin/setup-opencode-keychain-mac.sh` | Delete | All providers removed from config |
| `bin/gentle-ai-tui` | Delete | Bypasses Nix versioning |
| `pkgs/nixos-scripts/default.nix` | Modify | Remove `gentle-ai-tui` install lines (45-46) |
| `modules/home/opencode.nix` | Modify | Remove `legacyFallback` option, migration warning block, and legacy references in runtime description |
| `modules/home/opencode-profile.nix` | Modify | Remove `legacyFallback = false;` line |

## Interfaces / Contracts

**Removed option** (breaking for any consumer that sets it):

```nix
# REMOVED from modules/home/opencode.nix
options.home.opencode.legacyFallback  # was types.bool, default true
```

No new interfaces. Existing options unchanged:

```nix
options.home.opencode.enable    # types.bool
options.home.opencode.runtime   # types.enum ["stable" "lab" "both"]
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Static | Nix evaluation succeeds | `nix flake check` |
| Formatting | No style violations | `format-nix` (idempotent) |
| Build | rog host config builds | `nixos-rebuild build --flake .#rog` |
| Build | thinkcentre host config builds | `nixos-rebuild build --flake .#thinkcentre` |
| Runtime | OpenCode starts after rebuild | Manual: `opencode` launches without error |

## Migration / Rollback

No migration required — this is removal of dead code.

**Rollback** (if something goes wrong):
1. `git checkout HEAD -- bin/sync-opencode-remote bin/sync-opencode-mac.sh bin/setup-opencode-keychain-mac.sh bin/gentle-ai-tui` — restore scripts
2. `git checkout HEAD -- pkgs/nixos-scripts/default.nix modules/home/opencode.nix modules/home/opencode-profile.nix` — restore module changes
3. `nixos-build` — rebuild

## Order of Operations

1. Delete 4 script files from `bin/`
2. Edit `pkgs/nixos-scripts/default.nix` — remove `gentle-ai-tui` lines
3. Edit `modules/home/opencode.nix` — remove `legacyFallback` option and warning block
4. Edit `modules/home/opencode-profile.nix` — remove `legacyFallback = false`
5. Run `format-nix`
6. Run `nix flake check`
7. Build both hosts (`nixos-build dry`)

## Open Questions

None — scope is clear and narrow.