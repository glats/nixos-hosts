# Verification Report — hm-activation-gap

**Change**: Two-layer fix for Home Manager activation gap (nixos-build + opencode activation scripts)
**Date**: 2026-07-17
**Mode**: Tasks-only (no specs or design artifacts)
**Strict TDD**: false

## Completeness Table

| Artifact | Present | Used |
|----------|---------|------|
| Proposal | No | — |
| Specs | No | — |
| Design | No | — |
| Tasks | Yes | tasks.md |

## Task Completion

| # | Task | Status | Evidence |
|---|------|--------|----------|
| 1.1 | Replace 3 `exit 0` guards with `mkdir -p` in shared/opencode.nix | ✅ PASS | git diff shows 3 replacements: line 127 (`mkdir -p "$runtime_dir"`), line 229 (`mkdir -p "$runtime_dir"`), line 284 (`mkdir -p "$opencode_skills_dir"`) — matching claude-code.nix pattern |
| 1.2 | Add post-switch HM activation to `switch` case | ✅ PASS | Lines 139-147 in bin/nixos-build |
| 1.3 | Add post-switch HM activation to `upgrade` case | ✅ PASS | Lines 201-209 in bin/nixos-build |
| 1.4 | Add post-switch HM activation to `safe` case | ✅ PASS | Lines 330-338 in bin/nixos-build |

## Build / Test Evidence

| Command | Result | Details |
|---------|--------|---------|
| `nix flake check --no-build` | ✅ PASS | All 3 NixOS configurations (rog, thinkcentre, t14) + all derivations validated; all checks passed |
| `format-nix` | ✅ PASS | 376 .nix files checked; 0 reformatted (no formatting changes needed) |
| `bash -n bin/nixos-build` | ✅ PASS | Exit 0 — no shell syntax errors |

## Correctness Review

| Check | Result | Evidence |
|-------|--------|----------|
| 3 `exit 0` guards replaced with `mkdir -p` | ✅ | `git diff HEAD -- shared/opencode.nix` shows all 3 guards removed and replaced |
| Hook present in `switch` case | ✅ | Lines 139-147 |
| Hook present in `upgrade` case | ✅ | Lines 201-209 |
| Hook present in `safe` case | ✅ | Lines 330-338 |
| Hook NOT in `boot` case | ✅ | Lines 150-162 — no `HM_ACTIVATE` |
| Hook NOT in `test` case | ✅ | Lines 164-176 — no `HM_ACTIVATE` |
| Hook NOT in `dry` case | ✅ | Lines 212-226 — no `HM_ACTIVATE` |
| Hook NOT in `check` case | ✅ | Lines 228-231 — no `HM_ACTIVATE` |
| Hook NOT in `build` case | ✅ | Lines 233-244 — no `HM_ACTIVATE` |
| Hook uses `$HOME` (cross-user compatible) | ✅ | Path: `$HOME/.local/state/nix/profiles/home-manager/activate` |
| Hook guarded by `-x` test | ✅ | `if [ -x "$HM_ACTIVATE" ]` — safe if HM not installed |
| Hook safe to run twice (idempotent) | ✅ | HM activation is idempotent by design; activation scripts use cmp guards and `mkdir -p` |
| `shared/opencode.nix` follows claude-code pattern | ✅ | `mkdir -p "$runtime_dir"` matches `mkdir -p "$claude_dir"` in shared/claude-code.nix:172 |
| `makeOpencodeConfigMutable-default` | ✅ | Line 127: `mkdir -p "$runtime_dir"` (was `exit 0` guard) |
| `setupOpencodePluginRuntime-default` | ✅ | Line 229: `mkdir -p "$runtime_dir"` (was `exit 0` guard) |
| `syncOpencodeSkillsToOpenfang-default` | ✅ | Line 284: `mkdir -p "$opencode_skills_dir"` (was `exit 0` guard) |

## Issues

No issues found. All tasks completed correctly, all automated checks pass, and the manual code review confirms the implementation matches the change description exactly.

## Verdict

**PASS** — All 4 tasks verified complete. All 3 automated checks pass. Code review confirms correctness, correct placement, and idempotency of all changes.
