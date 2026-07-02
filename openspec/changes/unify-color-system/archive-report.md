# Archive Report: Unify Color System

**Change**: unify-color-system
**Status**: COMPLETED
**Archived**: 2026-06-09
**Archive path**: `openspec/changes/archive/unify-color-system-2026-06-09/`

---

## Summary

Centralized the color system across the NixOS configuration. Created a shared `lib/colors.nix` with three helper functions (`hexToRgb`, `doubleHex`, `byteDoubleHex`), refactored the kmscon terminal to use a shared palette import, replaced hardcoded hex literals in GTK CSS with palette references, aligned Darwin Ghostty color8 with Linux (base03), and replaced local duplicate color function definitions with aliases to the shared library.

## Files Changed

| File | Action |
|------|--------|
| `lib/colors.nix` | NEW — shared color helper library |
| `modules/desktop/kmscon.nix` | REFACTORED — shared palette + color imports |
| `home-linux/mate.nix` | REFACTORED — aliases to shared lib |
| `home-linux/theme.nix` | REFACTORED — palette CSS interpolation |
| `home-darwin/ghostty.nix` | FIXED — color8 alignment |

## Artifacts in Archive

- `proposal.md` — Change proposal with intent and scope
- `specs/` — Delta specs with requirements and scenarios (14 scenarios, all compliant)
- `design.md` — Technical design document
- `tasks.md` — Task breakdown (7 tasks, all completed)
- `apply-progress.md` — Implementation progress and validation log
- `verify-report.md` — Full verification report

## Key Decisions

1. **Shared helper library**: lib/colors.nix receives `{ lib }` as argument and exports `hexToRgb`, `doubleHex`, `byteDoubleHex` — bare output (no `rgb()` wrapper in hexToRgb).
2. **Alias pattern**: mate.nix uses `hexToRgb = colors.hexToRgb` aliases rather than calling `colors.hexToRgb` directly at call sites — acceptable indirection matching design doc.
3. **Path deviation**: kmscon.nix imports `../../lib/colors.nix` (not `../lib/colors.nix` as in the design) — the design had a path bug; implementation is correct.
4. **kmscon palette**: Direct `import ../../shared/palette.nix` with no arguments (no `{ lib }` wrapper), producing a bare attrset.

## Verification

- **Build**: `nix flake check` — all checks passed (exit 0)
- **Format**: `nix fmt --check` — no formatting errors (5 files)
- **Spec compliance**: 14/14 scenarios compliant
- **Issues**: 0 critical, 0 warnings (1 style suggestion noted in verify-report)

## Follow-up

- None required. All tasks are complete and verified.
