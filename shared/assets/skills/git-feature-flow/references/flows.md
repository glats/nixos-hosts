# Git Feature Flow — Command Reference

Full command sequences for the hash-preserving Git Feature Flow. The canonical example uses
`feature/TASK-XXX`; the same applies to `hotfix/`, `fix/`, and `chore/`.

## Branch Types

| Prefix | Purpose |
|---|---|
| `feature/` | New functionality |
| `hotfix/` | Urgent production fix |
| `fix/` | Bug fix |
| `chore/` | Maintenance or technical tasks |

`hotfix/` and `chore/` follow the same promotion flow as features. Hotfixes should reach
`main` as soon as possible and be promoted quickly into `develop` and `uat` to reduce
environment divergence. Low-risk chores (docs, formatting) rarely conflict; high-impact
chores (dependencies, shared config, build systems, migrations) are treated like features.

## Standard Flow (no conflicts)

```bash
# 1. Create branch from main
git checkout main
git pull origin main
git checkout -b feature/TASK-XXX

# 2. Develop and commit normally
git add .
git commit -m "Your descriptive commit message"

# 3. Push
git push -u origin feature/TASK-XXX
```

4. **PR into `develop`** — publish the PR in the DEV chat, complete code review, address
   observations, merge after approval. Feature deploys to DEV; functional validation runs.
5. **PR into `uat`** — after DEV validation. No second code review; only the merge-request
   process (already reviewed during DEV promotion). Feature deploys to UAT; QA begins.
6. **PR into `main`** — after QA certification. Merge triggers production deployment.

Result: `main -> feature/TASK-XXX -> develop -> uat -> main`.

## Detecting Merge Conflicts Locally

Verify against an environment WITHOUT touching canonical branch history:

```bash
git fetch origin
git checkout feature/TASK-XXX
git merge --no-commit --no-ff origin/develop   # or origin/uat
```

- **No conflicts**: `git merge --abort` — merge the canonical branch normally.
- **Conflicts**: `git merge --abort` — create the integration branch (below).

NEVER commit the temporary merge test into the canonical feature branch.

## Conflict Flow — Integration Branches

Integration branches exist ONLY when a direct merge into an environment branch conflicts.
They keep the canonical branch clean and original feature hashes unchanged.

Naming: `feature/TASK-XXX-develop` (for DEV), `feature/TASK-XXX-uat` (for UAT).
Same pattern for `hotfix/`, `fix/`, `chore/`.

```bash
# 1. Create the integration branch from the canonical branch
git checkout feature/TASK-XXX
git checkout -b feature/TASK-XXX-develop

# 2. Merge the target environment into it
git fetch origin
git merge origin/develop

# 3. Resolve all conflicts manually, then
git add .
git commit        # creates the environment-specific merge commit

# 4. PR the integration branch into its matching environment (develop)
```

Rules for integration branches:

- Created only when conflicts exist.
- Environment-specific.
- Merged only into their matching environment.
- Must NEVER be merged into `main`.

## Environment Branch Behavior

`uat` follows the validated state of `develop`: features are validated in `develop` first,
then the SAME canonical branch is promoted to `uat`. `uat` should not contain work that was
never validated in `develop`, so both branches stay mostly aligned.

Valid divergence: a feature already in `develop` not yet promoted to `uat` — temporary and
expected.

## Preserving Feature Hashes

Feature commits (F1, F2) must appear identically in `develop`, `uat`, and `main` — no
rebasing, no rewriting. This gives traceability between environments, easier rollbacks,
cleaner promotion, predictable merges, and no duplicated conflict resolution.

## Edge Cases

### Dependency on another feature

If `feature/TASK-759` depends on unmerged `feature/TASK-700`, branch from `feature/TASK-700`
instead of `main`. Promotion order MUST be respected: `TASK-700 -> main` before
`TASK-759 -> main`.

### Conflict when merging into `main`

Rare, because canonical branches start from `main`. If `main` moved forward and conflicts:

1. Keep the canonical branch.
2. Add a NEW explicit compatibility/fix commit on it (e.g. `F1---F2---F3`, where F3 is the
   fix for current `main`).
3. Push the branch.
4. Merge the canonical branch into `main` again.

Do NOT merge `main` into the canonical branch. The production fix stays visible as a real
feature commit instead of being hidden inside a merge resolution.
