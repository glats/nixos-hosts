# Skill Re-sync Specification

## Purpose

Extract updated skills from the new gentle-ai v1.24.1 binary and reconcile them with local customizations, preserving all 10 extra local skills.

## Requirements

### Requirement: Extract Upstream Skills

The system MUST extract the complete skill set from the gentle-ai v1.24.1 binary.

#### Scenario: Extract skills from binary

- GIVEN gentle-ai v1.24.1 binary is available
- WHEN the extraction command runs
- THEN all upstream SKILL.md files are extracted to a temporary directory
- AND the extraction completes without errors

#### Scenario: Extracted skills are valid

- GIVEN extracted skills in a temp directory
- WHEN each SKILL.md is validated
- THEN every skill has a valid SKILL.md file
- AND no extraction artifacts are corrupted

### Requirement: Diff Local vs Upstream

The system MUST compare extracted upstream skills against current local skill copies to identify changes.

#### Scenario: Identify changed skills

- GIVEN upstream skills and local skills
- WHEN a diff is performed
- THEN a report lists skills that differ between upstream and local
- AND each difference includes the nature of change (added, modified, removed)

#### Scenario: Identify unchanged skills

- GIVEN upstream skills and local skills
- WHEN a diff is performed
- THEN a report lists skills with no differences
- AND unchanged skills are skipped from update

### Requirement: Preserve Local Extra Skills

The system MUST preserve all 10 extra local skills that do not exist in upstream gentle-ai.

#### Scenario: Local-only skills untouched

- GIVEN 10 local skills not present in upstream
- WHEN the re-sync completes
- THEN all 10 local skills remain in their original locations
- AND their content is unmodified

#### Scenario: Local skill paths preserved

- GIVEN local skills in `modules/home/opencode/skills/`
- WHEN the re-sync completes
- THEN the directory structure for local skills is intact
- AND no local skill files are deleted

### Requirement: Update Upstream Skill Copies

The system MUST update local copies of upstream skills that have changed in v1.24.1.

#### Scenario: Modified upstream skills updated

- GIVEN an upstream skill that differs from local copy
- WHEN the update is applied
- THEN the local copy is replaced with the upstream version
- AND a changelog entry documents what changed

#### Scenario: New upstream skills added

- GIVEN a new skill in upstream not present locally
- WHEN the update is applied
- THEN the new skill is copied to the local skills directory
- AND it is registered in the skill registry
