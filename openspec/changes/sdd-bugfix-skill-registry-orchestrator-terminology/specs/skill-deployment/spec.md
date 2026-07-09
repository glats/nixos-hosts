# Delta for Skill Deployment

## ADDED Requirements

### REQ-SKILLS-1: Upstream Canonical Skill Replacement

The 9 SDD phase skills deployed to `~/.config/opencode/skills/` (sdd-apply, sdd-archive,
sdd-design, sdd-explore, sdd-init, sdd-propose, sdd-spec, sdd-tasks, sdd-verify) MUST be
replaced with their canonical upstream versions from the `Gentleman-Programming/gentle-ai`
repository at path `internal/assets/skills/{skill-name}/`. Each replacement MUST include
the full `SKILL.md` and any `references/` subdirectory content present in upstream.
The replacement MUST NOT modify `_shared/` files, `sdd-onboard`, or the
`skills/_shared/` shared reference directory.

#### Scenario: Replaced skill matches upstream line count

- GIVEN the upstream canonical `sdd-apply/SKILL.md` is fetched from
  `Gentleman-Programming/gentle-ai` at `internal/assets/skills/sdd-apply/SKILL.md`
- WHEN the local file is compared to upstream
- THEN the local `~/.config/opencode/skills/sdd-apply/SKILL.md` SHALL match the upstream
  version in content
- AND the local file SHALL NOT be a truncated version (previously 37 lines vs ~200 upstream)

#### Scenario: References subdirectory is included

- GIVEN the upstream `sdd-init` skill includes a `references/init-details.md` file
- WHEN the local `sdd-init` skill is replaced
- THEN `~/.config/opencode/skills/sdd-init/references/init-details.md` SHALL be written
  with the upstream canonical content
- AND the file SHALL contain skill directory scanning rules for `sdd init`

#### Scenario: Shared files are NOT modified

- GIVEN `skills/_shared/sdd-phase-common.md` already matches upstream
- WHEN the replacement is executed
- THEN `skills/_shared/sdd-phase-common.md` SHALL NOT be modified
- AND `skills/_shared/openspec-convention.md` SHALL NOT be modified
- AND `skills/_shared/SKILL.md` SHALL NOT be modified

#### Scenario: sdd-onboard is NOT modified

- GIVEN `~/.config/opencode/skills/sdd-onboard/SKILL.md` already matches upstream
  (231 local lines vs ~220 upstream)
- WHEN the replacement is executed
- THEN `sdd-onboard/SKILL.md` SHALL NOT be modified

### REQ-SKILLS-2: Local-Only Skill Preservation

Local-only skills that have no upstream counterpart in `Gentleman-Programming/gentle-ai`
MUST NOT be removed, modified, or overwritten. This includes: caveman, caveman-commit,
caveman-compress, caveman-help, caveman-review, caveman-stats, nix-verify, and
customize-opencode.

#### Scenario: caveman-family skills are untouched

- GIVEN `~/.config/opencode/skills/caveman/SKILL.md` exists as a local-only skill
- WHEN the replacement is executed
- THEN the file SHALL exist with its original content unchanged
- AND the same SHALL hold for caveman-commit, caveman-compress, caveman-help,
  caveman-review, caveman-stats

#### Scenario: nix-verify is untouched

- GIVEN `~/.config/opencode/skills/nix-verify/SKILL.md` exists as a local-only skill
- WHEN the replacement is executed
- THEN the file SHALL exist with its original content unchanged

#### Scenario: customize-opencode is untouched

- GIVEN `~/.config/opencode/skills/customize-opencode/SKILL.md` exists as a
  local-only skill (built-in for NixOS opencode config)
- WHEN the replacement is executed
- THEN the file SHALL exist with its original content unchanged

### REQ-SKILLS-3: Non-SDD Skill Upstream Parity Verification

Non-SDD workflow skills that have an upstream counterpart MUST be compared against their
canonical version. If the upstream version contains meaningful improvements, the local
copy SHOULD be updated. If the local and upstream versions are identical or differ only
trivially (whitespace, formatting), the local copy SHALL NOT be modified. This applies to:
branch-pr, issue-creation, go-testing, skill-creator, judgment-day, chained-pr,
comment-writer, cognitive-doc-design, hermes-ephemeral-delegation, skill-improver,
work-unit-commits, and skill-registry.

#### Scenario: Already-matching skill is skipped

- GIVEN `~/.config/opencode/skills/branch-pr/SKILL.md` matches upstream SHA
- WHEN the verification runs
- THEN the local file SHALL NOT be replaced or modified

#### Scenario: Divergent skill is updated

- GIVEN `~/.config/opencode/skills/skill-registry/SKILL.md` diverges from upstream
  with meaningful content differences
- WHEN the verification runs
- THEN the local file SHALL be updated to match upstream
- AND the decision SHALL be logged with the diff summary

### REQ-SKILLS-4: Backup Before Replacement

Before any skill file at `~/.config/opencode/skills/` is replaced, a backup of the
current state MUST be created in a timestamped directory under `skills.backup/`. The
backup SHALL include all files that will be overwritten, preserving their full paths
relative to `~/.config/opencode/skills/`.

#### Scenario: Backup created before replacement

- GIVEN the replacement is about to execute
- WHEN the first skill file is about to be overwritten
- THEN a backup directory `skills.backup/YYYY-MM-DD_HHMMSS/` SHALL exist
- AND it SHALL contain a copy of every file being replaced

#### Scenario: Rollback from backup restores original files

- GIVEN a backup exists at `skills.backup/YYYY-MM-DD_HHMMSS/`
- AND the replacement has been applied
- WHEN the backup is restored to `~/.config/opencode/skills/`
- THEN all skill files SHALL match their pre-replacement state

### REQ-SKILLS-5: Directory Structure Preservation

The replacement MUST preserve the existing skill directory structure under
`~/.config/opencode/skills/`. No directory SHALL be renamed, moved, or deleted.
New subdirectories (like `references/`) MAY be created when present in upstream
but absent locally. No existing non-SDD skill directory SHALL be removed.

#### Scenario: Directory layout is unchanged

- GIVEN `~/.config/opencode/skills/` has the current directory structure
- WHEN the replacement completes
- THEN all pre-existing directories SHALL remain at their original paths
- AND no directory SHALL be renamed or moved
- AND no non-SDD skill directory SHALL be absent

#### Scenario: New references directory is created

- GIVEN the upstream `sdd-init` skill includes `references/init-details.md`
- AND the local `~/.config/opencode/skills/sdd-init/references/` directory
  does not exist or has an outdated version
- WHEN the replacement executes
- THEN `~/.config/opencode/skills/sdd-init/references/init-details.md` SHALL
  be created with upstream content
