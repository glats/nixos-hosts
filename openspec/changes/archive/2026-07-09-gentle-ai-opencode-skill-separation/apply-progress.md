# Apply Progress: gentle-ai-opencode-skill-separation

## Status: COMPLETE

All 6 tasks implemented and verified.

## Files Changed

| File | Action | Lines | Description |
|------|--------|-------|-------------|
| `shared/opencode/assets/opencode/sdd-review-policy.md` | Create | +115 | Verbatim copy of `~/.config/opencode/sdd-review-policy.md` |
| `shared/opencode.nix` | Modify | +8 | home.file entry (T2), activation loop entry (T3), sed elif warning (T4) |
| `AGENTS.md` | Modify | +23 | Gentle AI Asset Boundary section (T5) |

## Verification Results

| Check | Result |
|-------|--------|
| `diff ~/.config/opencode/sdd-review-policy.md .../sdd-review-policy.md` | Exit 0 (identical) |
| `format-nix` | Clean (only pre-existing fonts.nix diff) |
| `nix flake check --no-build` | All checks passed (rog, thinkcentre, t14) |

## Task Details

### T1: Source file
- Created `shared/opencode/assets/opencode/sdd-review-policy.md` as verbatim copy
- Verified: `diff` exits 0

### T2: home.file entry
- Inserted after line 102 (`sdd-orchestrator.md` block), before `# skills/` comment
- Uses `${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/sdd-review-policy.md` with `force = true`

### T3: Activation loop entry
- Added `sdd-review-policy.md` to `for file in` list after `sdd-orchestrator.md`

### T4: Sed elif warning
- Added `elif [ -f "$skill_file" ]` branch emitting warning to stderr when marker missing
- Silent when file missing (expected on truncation windows)

### T5: Boundary docs
- Appended "Gentle AI Asset Boundary" section to AGENTS.md after "Owned Repos"
- Includes inventory table, override mechanism, policy/mechanism pair

### T6: Verification
- `format-nix`: Clean
- `nix flake check --no-build`: All checks passed
- Total: ~146 lines added, 0 removed (excluding pre-existing dirty files)
