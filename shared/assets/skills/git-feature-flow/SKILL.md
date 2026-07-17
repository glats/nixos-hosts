---
name: git-feature-flow
description: "Trigger: PR conflict, conflicto en PR, merge conflict, conflicted GitHub pull request, git feature flow, feature branch, promote to develop/uat/main, integration branch. Preserves commit hashes across environments."
metadata:
  version: "1.0"
---

## Activation Contract

Load when creating branches, opening PRs, a GitHub PR reports merge conflicts ("This branch has conflicts that must be resolved"), resolving merge conflicts locally, or promoting work across `develop` -> `uat` -> `main` in a repo using this Git Feature Flow.

## Hard Rules

- `main` is the production source of truth; everything in it must be deployable.
- Canonical branches: `feature/TASK-XXX`, `hotfix/TASK-XXX`, `fix/TASK-XXX`, `chore/TASK-XXX`. Always start them from `main`.
- NEVER rebase, squash, or rewrite feature commits — hashes must appear identically in `develop`, `uat`, and `main`.
- NEVER merge `main` into a canonical branch to fix a conflict — add an explicit fix commit on the canonical branch instead.
- Integration branches (`<canonical>-develop`, `<canonical>-uat`) are created ONLY on conflict, are environment-specific, merge ONLY into their matching environment, and must NEVER reach `main`.
- Promotion order is strict: PR -> `develop` (code review) -> `uat` (no second review) -> `main` (after QA certification).

## Decision Gates

| Situation | Action |
|---|---|
| New work | Branch from `main` as `<type>/TASK-XXX` |
| PR to `develop`/`uat` merges clean | Merge the canonical branch directly |
| Conflict merging into `develop` | Create `<canonical>-develop`, merge `origin/develop` into it, resolve, PR it into `develop` |
| Conflict merging into `uat` | Create `<canonical>-uat`, merge `origin/uat` into it, resolve, PR it into `uat` |
| Conflict merging into `main` | Add explicit fix commit on the canonical branch, push, merge again |
| Feature depends on unmerged feature | Branch from that feature; promote the dependency first |
| Hotfix | Same promotion flow; reach `main` ASAP, then promote to `develop`/`uat` quickly |

## Execution Steps

1. **Start**: `git checkout main && git pull origin main && git checkout -b feature/TASK-XXX`
2. **Work**: commit normally; `git push -u origin feature/TASK-XXX`
3. **Optional pre-check**: `git fetch origin && git merge --no-commit --no-ff origin/<env>`, inspect, then `git merge --abort`. NEVER commit this test merge.
4. **Promote**: PR into `develop` -> review -> merge -> validate -> PR into `uat` -> merge -> QA -> PR into `main` -> merge.
5. **On conflict**: follow the Decision Gates integration-branch flow; resolve conflicts only inside the integration branch.

## Output Contract

- Branch names and PR targets matching the tables above.
- Conflicts resolved only in integration branches or as explicit fix commits on canonical branches.
- No rewritten history on canonical branches; feature hashes preserved end to end.

## References

- `references/flows.md` — full command sequences for standard, conflict, and edge-case flows.
