# sed-validation Specification

## Purpose

Validation for the sed patch in `opencode.nix` that strips `<!-- section:model-capable -->` markers from SDD skill files. Ensures silent no-op failures are surfaced as visible warnings.

## Requirements

### Requirement: Marker Absence Warning

The `opencode.nix` activation script SHALL emit a visible warning to stderr when the `<!-- section:model-capable -->` marker is NOT found on line 1 of `sdd-apply/SKILL.md` or `sdd-verify/SKILL.md`. This prevents silent failures when upstream removes or reformats the marker.

#### Scenario: Marker present — silent success

- GIVEN line 1 of `sdd-apply/SKILL.md` is `<!-- section:model-capable -->`
- WHEN the activation sed loop runs
- THEN the marker is stripped AND no warning is emitted

#### Scenario: Marker missing — warning emitted

- GIVEN line 1 of `sdd-apply/SKILL.md` does NOT contain `<!-- section:model-capable -->`
- WHEN the activation sed loop runs
- THEN stderr SHALL contain `WARNING: sdd-apply/verify model-capable marker not found`

#### Scenario: Skill file missing — no warning

- GIVEN `~/.config/opencode/skills/sdd-apply/SKILL.md` does not exist
- WHEN the activation sed loop runs
- THEN NO warning is emitted (the `if [ -f "$skill_file" ]` guard skips the check)

#### Scenario: Both skills checked independently

- GIVEN marker present in `sdd-verify` but missing in `sdd-apply`
- WHEN the activation sed loop runs
- THEN `sdd-apply` triggers the warning AND `sdd-verify` proceeds silently
