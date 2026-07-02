# Verify Report: qwen3-opencode-type-validation

**Date**: 2026-06-30
**Mode**: hybrid (Engram + openspec)
**Status**: PASS

## Completeness Table

| Dimension | Status | Evidence |
|-----------|--------|----------|
| Tasks (all 17) | ✅ Complete | apply-progress confirms all 17/17 checked |
| Spec requirements (6/6) | ✅ Met | All scenarios verified |
| Design coherence | ✅ No deviations | Design confirms spec-aligned approach |
| Build (nix flake check) | ✅ Pass | 3 hosts pass; all flake outputs valid |
| Format (format-nix) | ✅ Pass | No diffs after formatting |
| Zombie isolation | ✅ Pass | 0 qwen3.7/3.8 in tier phase values |

## Build/Tests Evidence

| Command | Result | Details |
|---------|--------|---------|
| `nix flake check --no-build` | PASS | rog, thinkcentre, t14 all evaluate; all packages, checks, nixosConfigurations, formatter pass. Deprecation warning for `qt.platformTheme.name` is pre-existing and unrelated. |
| `format-nix` | PASS | All 5 changed files + 4 others formatted; 0 diffs produced |
| `grep qwen3.[78]` (outside catalogue) | PASS | Only matches in model catalogue (lines 103, 107, 111) + comment block — zero in tier phase assignments |
| `grep 'opencode-go-medium'` (4 sites) | PASS | 4/4 declaration points: providers-base.nix:2, opencode.nix:309, opencode-profile.nix:9, providers.nix:6 |
| `grep '"opencode-go"'` (bare, no suffix) | PASS | Zero matches |
| `grep '"opencode-go2"'` | PASS | Zero matches |

## Spec Compliance Matrix

### Requirement 1: Model Catalogue Completeness

| Scenario | Result | Evidence |
|----------|--------|----------|
| All 8 working models declared | PASS | glm-5.2, glm-5.1, kimi-k2.6, kimi-k2.7-code, deepseek-v4-pro, deepseek-v4-flash, mimo-v2.5, mimo-v2.5-pro — all present with `name` + `thinking = false` |
| 3 zombie Qwen entries with tracking comment | PASS | qwen3.7-plus, qwen3.7-max, qwen3.8-ultra all present. Comment block (lines 94-102) cites opencode#23960, #32418, #29754, #33055, #33303 |
| Total count = 11 | PASS | `opencodeProvider.opencode.models` has exactly 11 entries |

### Requirement 2: Tier Phase Routing

| Scenario | Result | Evidence |
|----------|--------|----------|
| opencode-go-full resolves all 12 phases | PASS | kimi-k2.6 × 5, glm-5.2 × 3, deepseek-v4-pro × 2, deepseek-v4-flash × 2 — matches spec table row-by-row |
| opencode-go-medium resolves all 12 phases | PASS | kimi-k2.6 × 5, deepseek-v4-pro × 3, deepseek-v4-flash × 4 — matches spec table row-by-row |
| opencode-go-light resolves all 12 phases | PASS | deepseek-v4-pro × 3, kimi-k2.6 × 2, deepseek-v4-flash × 7 — matches spec table row-by-row |
| No zombie Qwen in any tier phase | PASS | Zero `qwen3.7`/`qwen3.8` references outside model catalogue |

### Requirement 3: Default Provider Selection

| Scenario | Result | Evidence |
|----------|--------|----------|
| Default is opencode-go-medium | PASS | All 4 declaration points set to `"opencode-go-medium"` |
| All declaration points agree | PASS | providers-base.nix:2, opencode.nix:309, opencode-profile.nix:9, providers.nix:6 — all consistent |

### Requirement 4: Host Provider Mapping

| Scenario | Result | Evidence |
|----------|--------|----------|
| t14 uses opencode-go-full | PASS | `hosts/t14/home/omarchy.nix:86` — plain assignment `"opencode-go-full"` |
| rog inherits default (medium) | PASS | No active override (line 156 override is commented out): `#   home.opencode.activeProviderName = "github-copilot";` |
| thinkcentre inherits default (medium) | PASS | No active override (line 57 override is commented out): `#   home.opencode.activeProviderName = "github-copilot";` |
| mact2 unchanged (github-copilot) | PASS | `darwin/default.nix:56` still `"github-copilot"` |

### Requirement 5: Removed Tiers

| Scenario | Result | Evidence |
|----------|--------|----------|
| "opencode-go" (bare) absent | PASS | Zero matches in providers list |
| "opencode-go2" absent | PASS | Zero matches in any file |
| New tiers present | PASS | opencode-go-full, opencode-go-medium, opencode-go-light all in providers list |

### Requirement 6: Build Validation

| Scenario | Result | Evidence |
|----------|--------|----------|
| `nix flake check --no-build` passes | PASS | All 3 Linux hosts evaluate; all flake outputs pass |
| `format-nix` produces no diffs | PASS | All 5 changed files formatted clean; no diffs |

## Correctness Table

| Check | Result | Note |
|-------|--------|------|
| All 12 phases assigned in each tier | PASS | No null phase assignments |
| Phase values use bare model IDs (not prefixed) | PASS | e.g., `"kimi-k2.6"` not `"opencode/kimi-k2.6"` |
| All working models have `thinking = false` | PASS | 8/8 working models |
| Zombie models also have `thinking = false` | PASS | 3/3 zombie models |
| Providers list includes old free tier | PASS | `opencode-go-free` untouched |
| Description example text updated | PASS | `shared/opencode.nix:311` mentions `"opencode-go-full"` |

## Design Coherence

No deviations from design.md. Implementation matches the design decision to use bare model IDs, 3-tier structure (full/medium/light), and zombie-model retention approach.

## Issues Found

None. All 6 spec requirements pass without exception.

### Note on Checklist Count Discrepancy

The user's verification checklist states medium tier counts as "kimi-k2.6 × 7, v4-pro × 3, v4-flash × 2". The spec table actual count is kimi-k2.6 × 5, v4-pro × 3, v4-flash × 4. The implementation matches the **spec table** row-by-row (verified above). The checklist count is a documentation error, not an implementation bug. The spec table is authoritative.

## Verdict

**PASS** — All 17 tasks complete. All 6 spec requirements verified with build evidence. No discrepancies between specs and implementation.
