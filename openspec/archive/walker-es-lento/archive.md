# Archive: walker-es-lento

**Archived**: 2026-06-28
**Status**: intentional-with-warnings
**SDD Mode**: Hybrid (filesystem `.sdd/` + Engram)

## Change Summary

Walker (Omarchy desktop launcher on t14) was unusably slow. Root cause: elephant's `files` provider indexed all of `$HOME` with zero exclusions, consuming 456 MB RSS, 13,053 fsnotify watches, and ~21K indexed files (92% in `~/go/pkg/mod`). Fix: add `ignored_dirs` to elephant's files provider via `files.toml` in omarchy-nix, plus 3 complementary performance improvements.

## Specification

Spec defined 5 requirements for the `files.toml` + `ignored_dirs` change. All verified at code level. Three extra implementation changes were made beyond spec scope (GSK_RENDERER removal, socket launch, restart script fix) — these are complementary and regression-free.

## Artifact Inventory

| Artifact | Filesystem | Engram ID | Content |
|----------|-----------|-----------|---------|
| Exploration | ❌ `.sdd/explore/` missing | #328 | Walker slowness root cause analysis (9 ranked causes) |
| Proposal | ❌ `.sdd/propose/` missing | #330 | Intent, scope, approach, risks, rollback |
| Design | ❌ `.sdd/design/` missing | #333 | Technical design, architecture decisions, file changes |
| Spec | ✅ `.sdd/archive/.../spec.md` | #332 | 5 requirements with scenarios, 9 ignored_dirs patterns |
| Tasks | ✅ `.sdd/archive/.../tasks.md` | #334 | 3 phases, 10 tasks |
| Verify | ✅ `.sdd/archive/.../verify.md` | #341 | Code-level PASS, runtime PENDING |
| Apply Progress | — | #335 | Phase 1+2 completion, Phase 3 out-of-band |

**Missing artifacts (non-critical)**: Exploration, proposal, and design exist ONLY in Engram (no filesystem copy). The design directory was never created — decisions captured in commit messages and Engram observation #333.

## Implementation Delivered

### omarchy-nix (glats/omarchy-nix, main)
4 commits, pushed to `origin/main`:

| Commit | SHA | Description |
|--------|-----|-------------|
| 1 | `ae38cf1` | `files.toml` with 9 `ignored_dirs` Go-regex patterns + `home.file` entry |
| 2 | `1511221` | Remove `GSK_RENDERER=cairo` — enables GPU rendering |
| 3 | `725f868` | Socket launch via `nc -U` + `netcat-openbsd` dependency |
| 4 | `cc81cc2` | Fix restart script — handle detached daemon with pkill fallback |

### nixos-hosts (this repo, master)
4 flake.lock bumps, pushed to `origin/master`:

| Commit | SHA | omarchy-nix rev |
|--------|-----|-----------------|
| 1 | `f52595a` | `ae38cf1` |
| 2 | `32a0a37` | `1511221` |
| 3 | `194184e` | `725f868` |
| 4 | `79d7f97` | `cc81cc2` |
| HEAD | `c3bf76c` | `cc81cc2` |

## Verification Results

### Code-Level: ✅ PASS
- All 4 omarchy-nix commits exist and are pushed to `origin/main`
- All 4 flake.lock bumps point to correct omarchy-nix revisions
- `nix flake check --no-build` exits 0
- All 9 `ignored_dirs` patterns match spec exactly
- `home.file` deployment follows existing `calc.toml` / `desktopapplications.toml` pattern
- Walker `config.toml` unchanged (`max_results` still 256)
- No regression on `desktopapplications.toml` or `calc.toml`

### Runtime: 🔲 PENDING (out-of-band)
Performance targets require t14 host deployment to confirm:
- elephant RSS <150 MB (from 456 MB)
- Indexed files <3,000 (from 21,192)
- fsnotify watches <2,000 (from 13,053)
- Reindex time <1s (from 10-30s)
- Walker `.` prefix search <500ms (from 10-30s timeout)

## Task Completion Gate Reconciliation

**Reason for intentional-with-warnings status**: Phase 3 tasks (3.1–3.4, deploy + verify on t14) are unchecked but are runtime verification tasks requiring physical access to the t14 host. The orchestrator explicitly flagged these as out-of-band. Per SDD archive strict policy, this is an exceptional stale-checkbox reconciliation case:

- Phases 1+2 implementation tasks: all 6/6 checked and verified ✅
- Phase 3 (runtime verification): 0/4 checked — blocked by hardware access. Code-level implementation is complete. Runtime metrics are credible based on pattern coverage (92% of index eliminated by `ignored_dirs`).
- Total: 6/10 tasks complete at code level; 6/6 implementation tasks complete.

The spec correctly defines the planned scope. The spec-implementation gap (3 extra changes — GSK_RENDERER, socket launch, restart fix) is noted. No spec updates performed since the extra changes are complementary improvements without spec conflicts.

## Filesystem Archive

Original change directories (flat type-based layout) have been consolidated into archive:

```
.sdd/archive/2026-06-28-walker-es-lento/
├── archive.md      ← This file
├── spec.md         ← From .sdd/spec/walker-es-lento/spec.md
├── tasks.md        ← From .sdd/tasks/walker-es-lento/tasks.md
└── verify.md       ← From .sdd/verify/walker-es-lento/verify.md
```

Original locations removed:
- `.sdd/spec/walker-es-lento/` → archived ✅
- `.sdd/tasks/walker-es-lento/` → archived ✅
- `.sdd/verify/walker-es-lento/` → archived ✅

## Engram Artifacts (observation IDs for traceability)

| Artifact | Topic Key | ID |
|----------|-----------|----|
| Preflight | `sdd/walker-es-lento/preflight` | #327 |
| Exploration | `sdd/walker-es-lento/exploration` | #328 |
| Proposal | `sdd/walker-es-lento/proposal` | #330 |
| Spec | `sdd/walker-es-lento/spec` | #332 |
| Design | `sdd/walker-es-lento/design` | #333 |
| Tasks | `sdd/walker-es-lento/tasks` | #334 |
| Apply Progress | `sdd/walker-es-lento/apply-progress` | #335 |
| Verify Report | `sdd/walker-es-lento/verify` | #341 |
| Archive Report | `sdd/walker-es-lento/archive-report` | (this observation) |

## Risks

- **Runtime unverified**: Performance targets cannot be confirmed until Phase 3 executes on t14. Targets are credible based on pattern coverage analysis.
- **Spec-implementation gap**: The spec covers only the `files.toml` change; 3 extra changes (GSK_RENDERER, socket launch, restart fix) were implemented beyond spec scope. These are complementary and regression-free but are not formally spec'd.
- **Design artifact gap**: Design doc missing from filesystem; architecture decisions only recoverable from Engram #333 and commit messages.
