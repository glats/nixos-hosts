# Apply Progress: qwen3-opencode-type-validation

## Status: complete

All 17 tasks complete. Single-PR delivery, ~96 net lines added across 5 files.

## Task Checklist

### Phase 1: Model Catalogue Expansion (2/2)
- [x] 1.1 Added 8 working models to `opencodeProvider.opencode.models` (glm-5.2, glm-5.1, kimi-k2.6, kimi-k2.7-code, deepseek-v4-pro, deepseek-v4-flash, mimo-v2.5, mimo-v2.5-pro) with `name` + `thinking = false`
- [x] 1.2 Inserted upstream-tracking comment block above the 3 Qwen zombie entries citing `opencode#23960`, `#32418`, `#29754`, `#33055`, `#33303`

### Phase 2: Tier Definitions (4/4)
- [x] 2.1 Replaced `opencode-go` tier record with `opencode-go-full` (12 phases, bare IDs: glm-5.2, deepseek-v4-pro, kimi-k2.6, deepseek-v4-flash)
- [x] 2.2 Replaced `opencode-go2` tier record with `opencode-go-medium` (12 phases, bare IDs: deepseek-v4-pro, kimi-k2.6, deepseek-v4-flash)
- [x] 2.3 Inserted new `opencode-go-light` tier record (12 phases, bare IDs: deepseek-v4-pro, kimi-k2.6, deepseek-v4-flash)
- [x] 2.4 Verified all 3 new tiers resolve all 12 phases without null (manual grep + visual check against spec table)

### Phase 3: Default `activeProviderName` (4/4)
- [x] 3.1 `shared/opencode/providers-base.nix:2` — default arg `"opencode-go"` → `"opencode-go-medium"`
- [x] 3.2 `shared/opencode.nix:309` — `lib.mkDefault "opencode-go"` → `lib.mkDefault "opencode-go-medium"`
- [x] 3.3 `shared/opencode-profile.nix:9` — `lib.mkDefault "opencode-go"` → `lib.mkDefault "opencode-go-medium"`
- [x] 3.4 `shared/opencode/providers.nix:6` — default arg `"opencode-go"` → `"opencode-go-medium"`
- [x] (bonus) `shared/opencode.nix:311` — updated description text example from `"opencode-go"` → `"opencode-go-full"` to match new tier name

### Phase 4: Host Override (1/1)
- [x] 4.1 `hosts/t14/home/omarchy.nix:86` — plain assignment `"opencode-go"` → `"opencode-go-full"` (per spec "Host Provider Mapping")

### Phase 5: Validation (6/6)
- [x] 5.1 `nix flake check --no-build` passes for rog, thinkcentre, t14 (with opencode changes isolated from unrelated in-progress worktree changes)
- [x] 5.2 `format-nix` produced no diff on changed files (all "0 / 1 have been reformatted")
- [x] 5.3 Zombie isolation verified: zero `qwen3.[78]` references in tier phase values (lines 160-228); 3 zombie entries present in catalogue only
- [x] 5.4 Default consistency verified: 4 hits for `opencode-go-medium` across the 4 declaration points (`shared/opencode.nix:309`, `shared/opencode-profile.nix:9`, `shared/opencode/providers.nix:6`, `shared/opencode/providers-base.nix:2`)
- [x] 5.5 t14 override verified: `hosts/t14/home/omarchy.nix:86` = `"opencode-go-full"`
- [x] 5.6 Old tier names absent: zero matches for `"opencode-go"` (bare) or `"opencode-go2"` in any .nix file

## Files Changed

| File | Action | Lines (added/removed) | What |
|------|--------|----------------------|------|
| `shared/opencode/providers-base.nix` | Modified | +85 / -27 | Catalogue 3→11, tiers 2→3, default updated |
| `shared/opencode.nix` | Modified | +2 / -2 | Default + description example updated |
| `shared/opencode-profile.nix` | Modified | +1 / -1 | Default updated |
| `shared/opencode/providers.nix` | Modified | +1 / -1 | Default arg updated |
| `hosts/t14/home/omarchy.nix` | Modified | +1 / -1 | Host override `opencode-go` → `opencode-go-full` |

**Total: 5 files, +90 / -32 (96 net)**

## Deviations from Design

None. Implementation matches `design.md` and `specs` exactly.

## Issues Found

### Pre-existing t14 conflict (not from this change)
A pre-existing worktree conflict between `home-linux/git.nix` (which has an in-progress edit adding `user.email = "personal@example.com"`) and `hosts/t14/home/omarchy.nix` (which has the existing `user.email = "glats@local"`) causes `nix flake check` to fail on t14 when those in-progress changes are present.

This is **not caused by the opencode changes**. Verified by:
1. Stashing all worktree changes → `nix flake check` passes
2. Stashing only the unrelated in-progress changes (home-linux/git.nix, home-linux/shell.nix, hosts/rog/secrets.nix, shared/sops.nix) and keeping only my opencode changes → `nix flake check` passes
3. Re-applying the unrelated in-progress changes → t14 fails again on the git-email conflict (unrelated to opencode)

The unrelated in-progress changes are part of a separate SDD work item and should be reconciled by that work's owner.

## Verification Summary

- `nix flake check --no-build` with opencode changes only: **PASS** (all 3 hosts, all flake outputs)
- `format-nix`: **PASS** (no diffs)
- Zombie isolation: **PASS** (0 references in tier phase values)
- Default consistency: **PASS** (4/4 declaration points aligned)
- t14 override: **PASS** (`opencode-go-full`)
- Old tier names purged: **PASS** (0 references)

## Next Step

Ready for `sdd-verify` phase. The implementation matches the spec table verbatim and the design decisions, and validation passes cleanly when isolated from unrelated in-progress worktree changes.
