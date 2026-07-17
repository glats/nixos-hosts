# Delta for gentle-ai-asset-overlay

## RENAMED Requirements

### Requirement: extraAssetsShared → extraFiles

The parameter in `pkgs/gentle-ai-assets/default.nix` (line 6) is renamed from `extraAssetsShared` to `extraFiles`. All call sites in `lib/packages.nix` (lines 29, 49, 88) MUST use the new name.

(Reason: After removing skills-directory merging, the parameter handles only flat files such as `review-gate.md`. The narrowed scope warrants a descriptive name.)
(Migration: In `lib/packages.nix`, rename `extraAssetsShared = ./../shared/assets` to `extraFiles = ./../shared/assets`. Update both `inherit` lines at 49 and 88. In `pkgs/gentle-ai-assets/default.nix`, rename the parameter and update the `optionalString` guard and loop variable.)

## MODIFIED Requirements

### Requirement: extraFiles Handles Flat Files Only

The `extraFiles` loop in `pkgs/gentle-ai-assets/default.nix` installPhase SHALL only copy flat files; directory merging logic MUST be removed. The `review-gate.md` file copy (flat-file branch, lines 86–88) SHALL be preserved.

(Previously: The `extraAssetsShared` loop split into directory merging — recursive `chmod` + per-subitem copy — and flat-file copy. Local skills were merged into `$TEMP_DIR/skills/` via the directory branch.)

#### Scenario: Flat file copied, directory skipped

- GIVEN `extraFiles` points to `shared/assets/` containing `review-gate.md` (file) and `skills/` (dir)
- WHEN `gentle-ai-assets` builds
- THEN `$out/share/gentle-ai/review-gate.md` matches the source file
- AND no content from `skills/` appears in `$out/share/gentle-ai/skills/`

#### Scenario: extraFiles is null (unchanged)

- GIVEN `extraFiles` is `null` (default)
- WHEN `gentle-ai-assets` builds
- THEN build succeeds with no flat-file overlay applied
