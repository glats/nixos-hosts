# Delta for skill-deployment

## ADDED Requirements

### Requirement: localSkillsSource Option

`shared/gentle-ai-common.nix` MUST expose `home.gentle-ai.localSkillsSource` (type: `types.path`, default: `"${pkgs.local-ai-assets}/share/local-ai/skills"`). This provides the path to locally maintained skills, independent from `skillsSource` (upstream).

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
