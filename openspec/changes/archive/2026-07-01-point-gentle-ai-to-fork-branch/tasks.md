# Tasks: Point gentle-ai fork to main + fix PR #988 CodeRabbit comments

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~12 (reviewable) + auto-generated flake.lock |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR per repo (2 independent repos) |
| Delivery strategy | ask-on-risk |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

### Work Units

| Unit | Goal | Repo | Notes |
|------|------|------|-------|
| 1 | Sync fork + apply 3 CodeRabbit fixes + MD022 | glats/gentle-ai | Commit to fork `main` |
| 2 | Point flake input + lock update | glats/nixos-hosts | No commit — user reviews first |

## Phase 1: Sync + Fixes (glats/gentle-ai fork)

- [ ] 1.1 Clone/pull `glats/gentle-ai`, sync `main` with upstream `Gentleman-Programming/gentle-ai/main` (git pull upstream main)
- [ ] 1.2 Apply CodeRabbit fix 1: `internal/assets/skills/sdd-apply/SKILL.md` — add standalone bolded "Filesystem path convention" note (+3 lines)
- [ ] 1.3 Apply CodeRabbit fix 2: `internal/assets/skills/sdd-archive/SKILL.md` — fix archive path to `openspec/changes/archive/YYYY-MM-DD-{change-name}/`
- [ ] 1.4 Apply CodeRabbit fix 3: `internal/assets/skills/sdd-explore/SKILL.md` — add explicit "Output Contract" section (+4 lines)
- [ ] 1.5 Fix MD022 markdownlint warnings on `sdd-apply/SKILL.md` and `sdd-explore/SKILL.md` (blank lines around headings)
- [ ] 1.6 Commit + push to `glats/gentle-ai/main`

## Phase 2: Point Flake Input (glats/nixos-hosts)

- [ ] 2.1 Edit `flake.nix` L44: change `url = "github:Gentleman-Programming/gentle-ai/main"` → `"github:glats/gentle-ai/main"`
- [ ] 2.2 Run `nix flake lock --update-input gentle-ai-src`
- [ ] 2.3 Run `nix flake check --no-build` to verify
- [ ] 2.4 Stage changes (`flake.nix` + `flake.lock`) but do NOT commit — user reviews first
