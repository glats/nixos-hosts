# Delta for gentle-ai-asset-overlay

## ADDED Requirements

### Requirement: sdd-review-policy.md Asset Registration

The file `shared/opencode/assets/opencode/sdd-review-policy.md` SHALL exist as a local asset in the `extraAssets` tree. The existing `cp -r ${extraAssets}/. $TEMP_DIR/` mechanism in `pkgs/gentle-ai-assets/default.nix` SHALL copy it into the nix store at `$out/share/gentle-ai/opencode/sdd-review-policy.md` with no derivation changes needed.

#### Scenario: File placed under extraAssets

- GIVEN `shared/opencode/assets/opencode/sdd-review-policy.md` exists with review policy content
- WHEN `gentle-ai-assets` derivation builds
- THEN `${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/sdd-review-policy.md` SHALL match the source

#### Scenario: Flake check passes with new file

- GIVEN the new asset file exists in the source tree
- WHEN `nix flake check --no-build` runs
- THEN no errors are produced from the new file

### Requirement: ExtraAssets Inventory Completeness

The `shared/opencode/assets/` tree SHALL now contain both `opencode/sdd-orchestrator.md` (existing) and `opencode/sdd-review-policy.md` (new). This completes the inventory of local extraAssets — both files in the `opencode/` subdirectory are now tracked.

#### Scenario: Complete inventory

- GIVEN the full `shared/opencode/assets/` tree
- WHEN listing `opencode/` files
- THEN both `sdd-orchestrator.md` and `sdd-review-policy.md` are present
