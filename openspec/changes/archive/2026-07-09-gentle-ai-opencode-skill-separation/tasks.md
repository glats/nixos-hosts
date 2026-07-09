# Tasks: gentle-ai-opencode-skill-separation

## Task List

### T1: Copy sdd-review-policy.md into extraAssets tree

- **Description**: Copy `~/.config/opencode/sdd-review-policy.md` verbatim to `shared/opencode/assets/opencode/sdd-review-policy.md`. The existing `default.nix:68` `cp -r ${extraAssets}/. $TEMP_DIR/` mechanism automatically copies it into the nix store at `$out/share/gentle-ai/opencode/sdd-review-policy.md`. No derivation changes needed.
- **Files**:
  - `shared/opencode/assets/opencode/sdd-review-policy.md` (create, 115 lines)
- **Acceptance**:
  - File exists at target path
  - Content matches source `~/.config/opencode/sdd-review-policy.md` exactly (diff exits 0)
  - `git diff --stat` shows 1 new file, +115 lines
- **Dependencies**: None
- **Estimate**: Trivial

### T2: Add home.file entry for sdd-review-policy.md in opencode.nix

- **Description**: Insert a `home.file` entry for `sdd-review-policy.md` sourcing from `${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/sdd-review-policy.md` in `shared/opencode.nix`. Place after line 102 (the `sdd-orchestrator.md` block), before the `# skills/` comment on line 103. Same pattern as the existing `sdd-orchestrator.md` entry: `force = true`, `${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/sdd-review-policy.md` as the source.
- **Files**:
  - `shared/opencode.nix` (modify, +5 lines)
- **Acceptance**:
  - Insertion is syntactically valid Nix (verified by `nix flake check --no-build`)
  - Entry is before the `# skills/` comment, not after
  - Source path uses `${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/sdd-review-policy.md`
  - `force = true` is set (matches sdd-orchestrator.md pattern)
- **Dependencies**: T1 (the source file must exist at the extraAssets path for the derivation)
- **Estimate**: Trivial

### T3: Add sdd-review-policy.md to activation loop in opencode.nix

- **Description**: Add `sdd-review-policy.md` to the `for file in` list on line 145 of `shared/opencode.nix`, which converts HM symlinks to real copies at activation time. Insert between `sdd-orchestrator.md` and `instructions/universal.md` to maintain alphabetical grouping.
- **Files**:
  - `shared/opencode.nix` (modify, +1 word in string list)
- **Acceptance**:
  - `sdd-review-policy.md` appears in the loop list on line 145
  - After activation, `~/.config/opencode/sdd-review-policy.md` is a real (non-symlink) file
  - `file ~/.config/opencode/sdd-review-policy.md` reports "ASCII text" not "symbolic link"
  - `nix flake check --no-build` passes
- **Dependencies**: T2 (both modify same file, order top-to-bottom for clean diff)
- **Estimate**: Trivial

### T4: Add sed no-op warning for model-capable marker

- **Description**: Add an `elif [ -f "$skill_file" ]` branch after line 189 in the sed loop (`shared/opencode.nix` lines 187-192) that emits `"WARNING: sdd-apply/verify model-capable marker not found"` to stderr when the marker is absent but the file exists. This distinguishes "file missing" (expected on truncation windows, silent) from "file present but marker missing" (indicates upstream format change).
- **Files**:
  - `shared/opencode.nix` (modify, +3 lines)
- **Acceptance**:
  - After line 189's `if` block, an `elif [ -f "$skill_file" ]` branch is added
  - Warning text contains `WARNING:` prefix and goes to `>&2`
  - No warning emitted when marker is present (silent success)
  - No warning emitted when skill file does not exist (file-missing guard)
  - Warning emitted only when file exists but line 1 does NOT match `^<!-- section:model-capable -->$`
  - `nix flake check --no-build` passes
- **Dependencies**: T3 (same file, sequential edits for clean atomic diff)
- **Estimate**: Trivial

### T5: Append asset boundary documentation to AGENTS.md

- **Description**: Add a "Gentle AI Asset Boundary" section to repo `AGENTS.md` after line 127 (end of "Owned Repos" section). Content includes: an inventory table mapping each deployed asset to its origin/source (Upstream, Local, Mixed, Generated), a note on the override mechanism (extraSkills, extraAssets, agents.nix merge), and the policy/mechanism pair relationship between `sdd-review-policy.md` and `sdd-orchestrator.md`.
- **Files**:
  - `AGENTS.md` (modify, +24 lines)
- **Acceptance**:
  - New section appears after "Owned Repos", before EOF
  - Inventory table lists all 10 asset rows matching the design table
  - Override mechanism paragraph explains extraSkills, extraAssets, agents.nix merge
  - Policy/Mechanism pair relationship documented
  - No markdown formatting errors
- **Dependencies**: None (independent of T1-T4)
- **Estimate**: Small

### T6: Run verification suite

- **Description**: Run full verification: `format-nix` for formatting, `nix flake check --no-build` for all hosts, and `nixos-build dry` on rog for build evaluation. Fix any issues found.
- **Files**: All affected files may be revisited for fixes
- **Acceptance**:
  - `format-nix` produces no unexpected diffs
  - `nix flake check --no-build` exits 0 (pre-existing failures on unrelated hosts noted)
  - `nixos-build dry` on rog completes without evaluation errors
  - `git diff --stat` shows correct total: ~148 lines added, 0 removed
- **Dependencies**: T1, T2, T3, T4, T5 (all must be applied before verification)
- **Estimate**: Small

## Dependency Graph

```
T1 (source file) ──→ T2 (home.file) ──→ T3 (activation loop) ──→ T4 (sed warning)
                                                                        │
T5 (AGENTS.md) ─────────────────────────────────────────────────────────┤
                                                                        │
                                                                        ▼
                                                                   T6 (verify)
```

T2→T3→T4 share `shared/opencode.nix` — must be edited sequentially top-to-bottom (line 102 → line 145 → line 189) for clean incremental diffs.

## Apply Order

1. T1 — foundation: asset file must exist before derivation references it
2. T2 — home.file entry references the store path generated by T1
3. T3 — activation loop entry, same file as T2, edit lower in the file
4. T4 — sed elif, same file as T2/T3, edit near end of file
5. T5 — AGENTS.md, independent, can apply any time
6. T6 — final verification

## Review Workload Forecast

- **Source file** (T1): 115 lines — pure copy, trivial review
- **opencode.nix** (T2+T3+T4): ~9 net lines — 3 distinct insertions in same file
- **AGENTS.md** (T5): ~24 lines — documentation only
- **Total changed lines**: ~148
- **Chained PRs recommended**: No (well within 1200-line review budget)
- **Decision needed before apply**: No

## Verification Matrix

| Verification | Tool | Expectation |
|-------------|------|-------------|
| Formatting | `format-nix` | No unexpected diff |
| Nix syntax | `nix flake check --no-build` | Exit 0 for all hosts |
| Build | `nixos-build dry` on rog | Evaluation succeeds |
| File presence | `ls -la shared/opencode/assets/opencode/sdd-review-policy.md` | File exists, 115 lines |
| File content | `diff ~/.config/opencode/sdd-review-policy.md shared/opencode/assets/opencode/sdd-review-policy.md` | Exit 0 (identical) |
