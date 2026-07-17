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

## ADDED Requirements

### Requirement: sdd-review-policy.md Deployment

`shared/opencode.nix` SHALL deploy `sdd-review-policy.md` to `~/.config/opencode/sdd-review-policy.md` using the same pattern as `sdd-orchestrator.md`:

- A `home.file` entry sourcing from `${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/sdd-review-policy.md`
- An entry in the `makeOpencodeConfigMutable` activation for-loop (line 145) for symlink-to-real-copy conversion

#### Scenario: File deployed on rebuild

- GIVEN `nixos-build switch` completes
- WHEN checking `~/.config/opencode/sdd-review-policy.md`
- THEN the file exists as a real (non-symlink) file matching the source

#### Scenario: File survives nuke and rebuild

- GIVEN `~/.config/opencode/` is fully deleted
- WHEN `nixos-build switch` runs
- THEN `sdd-review-policy.md` is present AND identical to the source in the nix store

#### Scenario: Activation loop converts symlink to real copy

- GIVEN Home Manager created a symlink at `~/.config/opencode/sdd-review-policy.md`
- WHEN `makeOpencodeConfigMutable` activation runs
- THEN the symlink is replaced with a real copy via `cp --remove-destination`

#### Scenario: Orphan cleanup does not delete the file

- GIVEN orphan cleanup runs on `skills/` and `commands/` only
- WHEN `sdd-review-policy.md` exists at `~/.config/opencode/`
- THEN the file is NOT deleted (orphan cleanup scope excludes root-level files)

### Requirement: localSkillsSource Option

`shared/gentle-ai-common.nix` MUST expose `home.gentle-ai.localSkillsSource` (type: `types.path`, default: `"${pkgs.local-ai-assets}/share/local-ai/skills"`). This provides the path to locally maintained skills, independent from `skillsSource` (upstream). The `local-ai-assets` package SHALL be registered in platform overlays so that HM modules can resolve it at evaluation time.

#### Scenario: Option resolves at evaluation

- GIVEN `gentle-ai-common.nix` is imported
- WHEN `config.home.gentle-ai.localSkillsSource` is evaluated
- THEN it resolves to the `local-ai-assets` store path under `share/local-ai/skills`

### Requirement: Dual-Source Skill Deployment with Union Cleanup

| Field | Details |
|-------|---------|
| **Sources** | `skillsSource` (upstream) + `localSkillsSource` (local) |
| **Copy strategy** | Two independent cmp-guarded copy passes — one per source |
| **Orphan cleanup** | Single union pass after both copies complete |
| **Rule** | File removed only if absent from BOTH sources |

`shared/opencode.nix` and `shared/claude-code.nix` activation scripts SHALL implement this dual-source pattern for the `skills/` directory. No per-source orphan cleanup SHALL run during individual copy passes.

(Previously: A single `dir_pair` loop copied from one source (`skillsSource`) with inline per-source orphan cleanup.)

#### Scenario: Both sources deploy to opencode

- GIVEN upstream skills in `${skillsSource}` and local skills in `${localSkillsSource}`
- WHEN `makeOpencodeConfigMutable` activation runs
- THEN `~/.config/opencode/skills/` contains the union of files from both sources

#### Scenario: Cross-source orphan safety

- GIVEN `nix-verify/SKILL.md` exists only in `localSkillsSource` and `sdd-explore/SKILL.md` only in `skillsSource`
- WHEN union cleanup runs after both copy passes
- THEN neither `nix-verify/SKILL.md` nor `sdd-explore/SKILL.md` is deleted

#### Scenario: Stale file removed by union cleanup

- GIVEN `~/.config/opencode/skills/dead-skill/SKILL.md` exists but is absent from both sources
- WHEN union cleanup runs
- THEN `dead-skill/SKILL.md` is deleted

### Requirement: Unchanged End-State

After deployment, the file set in `~/.config/opencode/skills/` and `~/.claude/skills/` MUST be identical to the pre-change state — same skill directories, same file contents. No skill SHALL be added, removed, or modified.

#### Scenario: End-state diff is empty

- GIVEN a baseline listing from current deployment
- WHEN the change is built, switched, and skills are deployed
- THEN `diff <(baseline-ls ~/.config/opencode/skills/) <(ls -R ~/.config/opencode/skills/)` shows zero differences
- AND `~/.claude/skills/` matches `~/.config/opencode/skills/`
