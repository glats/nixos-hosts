# Delta for Skill Deployment

## REMOVED Requirements

### Requirement: Local SDD Skill Override Files

The system previously provided 8 local SDD skill override directories under
`shared/opencode/assets/skills/` (sdd-apply, sdd-archive, sdd-design,
sdd-explore, sdd-init, sdd-propose, sdd-spec, sdd-tasks). These were layered
via `extraAssets` in `pkgs/gentle-ai-assets/default.nix` and overwrote
upstream gentle-ai-src `SKILL.md` files. This override behavior is removed —
all 8 skill directories and their contents SHALL be deleted.

(Reason: Local overrides duplicated upstream gentle-ai and would block future
compressed upstream versions from PR #988. Removal ensures all SDD skills
come from upstream gentle-ai-src with no local drift.)

(Migration: None required. `extraAssets` mechanism stays active for
`opencode/sdd-orchestrator.md`. All 8 sdd-* skill directories at
`~/.config/opencode/skills/` will continue to exist after rebuild — sourced
from the upstream gentle-ai-assets package instead of local overrides.)

#### Scenario: Before state — local overrides present

- GIVEN the nixos-hosts repo at current HEAD
- WHEN listing `shared/opencode/assets/skills/`
- THEN 8 sdd-* directories exist alongside `.gitkeep`
- AND each contains a `SKILL.md` file

#### Scenario: After deletion — only .gitkeep remains

- GIVEN all 8 sdd-* directories are deleted
- WHEN listing `shared/opencode/assets/skills/`
- THEN only `.gitkeep` exists
- AND no sdd-* directories remain

#### Scenario: sdd-orchestrator.md is preserved

- GIVEN the 8 sdd-* directories are deleted
- WHEN checking `shared/opencode/assets/opencode/sdd-orchestrator.md`
- THEN the file exists unchanged
- AND `extraAssets` layering continues to deploy it

#### Scenario: Build passes — no breakage

- GIVEN the 8 directories are deleted
- WHEN running `nix flake check --no-build`
- THEN zero errors are produced
- AND the check passes cleanly

#### Scenario: Deployment — skills come from upstream

- GIVEN `nixos-build switch` completes successfully
- WHEN listing `~/.config/opencode/skills/sdd-*/SKILL.md`
- THEN all 8 sdd-* skills exist
- AND each file is sourced from the upstream gentle-ai-assets package
- AND no file is sourced from deleted local overrides

#### Scenario: Git history — only deletions

- GIVEN the change is committed
- WHEN inspecting `git log -1 --stat`
- THEN only deletions appear in the diff
- AND no files are added or created
- AND no Nix modules (`*.nix`, `flake.nix`) are modified

#### Scenario: Rollback — restore local overrides

- GIVEN the removal commit is applied
- WHEN running `git revert` on that commit
- THEN all 8 sdd-* directories with their `SKILL.md` files are restored
- AND the system returns to the before-state behavior
