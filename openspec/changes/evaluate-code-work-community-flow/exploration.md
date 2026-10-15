# Exploration: evaluate-code-work-community-flow

## Purpose

Determine whether the desired flow — `code-work <task>` creates/enters a Git worktree, the
user launches a normal OpenCode session, the agent works and commits normally, the developer
explicitly integrates, and cleanup is separate — is a standard community pattern, and whether
the existing legacy `code-work --done` behavior (requires a pushed branch, then deletes the
worktree and branch) is harmful or appropriate compared with community practice.

This is an evidence-only exploration. No source code is modified.

## Current State

`code-work` is a Go command (`pkgs/nixos-scripts/cmd/code-work/main.go`) with two independent
surfaces plus a zsh wrapper:

### Legacy lifecycle (the subject of this exploration)

- `code-work <name>` (`cmdCreate`) creates a linked worktree at `<repo>/.worktrees/<name>`
  on branch `<name>` (new branch from the current branch, or an existing local/origin branch),
  writes a `.worktree-base` marker, and warns if `.worktrees/` is not gitignored.
- The zsh wrapper (`linux/home/shell.nix`, `code-work()` `*)` branch) then `cd`s into the
  worktree and launches `opencode` (a normal session, no agent profile, no restrictions),
  printing `code-work --done` / `code-work --abort` hints on exit.
- `code-work --done` (`cmdDone`) — run from inside the worktree:
  1. Verifies it is inside `.worktrees/` and reads `.worktree-base`.
  2. Refuses if the worktree has uncommitted changes.
  3. Refuses if the branch has **no upstream** (`hasUpstream` = `git rev-parse --abbrev-ref
     <branch>@{u}` succeeds), printing "Local commits would be lost on deletion."
  4. `git checkout <base-branch>` from the main checkout.
  5. `git worktree remove <path> --force`.
  6. `git branch -D <branch>` (force delete).
  7. `git worktree prune`.
- `code-work --abort` (`cmdAbort`) force-removes the worktree (falling back to `rm -rf`),
  force-deletes the branch, and prunes — regardless of dirty state.
- `code-work --list` / `--prune` list worktrees / prune stale references.

### Managed lifecycle (context only)

`code-work new|check|ready|status|merge|clean|abandon|recover-lock` (`managed.go`,
`internal/managedworktree`) is a state machine (`active → ready-for-integration → integrated`,
plus `abandoned`). It already implements the community-recommended split:

- `merge <task>` performs the integration (non-fast-forward merge + validation, optional
  `--activate`), and never pushes or cleans up.
- `clean <task>` removes the worktree and branch **only** when the record is `integrated` or
  `abandoned`; `abandon <task>` preserves branch and worktree for diagnosis.
- The managed writing agent (`managed-writing-task`) has been stripped of every `code-work`
  grant (archive `2026-09-24-remove-code-work-agent-wiring`): it can edit/commit/test but has
  no push, integration, or cleanup authority.

## Affected Areas

- `pkgs/nixos-scripts/cmd/code-work/main.go` — `cmdDone`/`cmdAbort` implement the legacy
  lifecycle under evaluation (`--force` remove, `-D` branch delete, `hasUpstream` gate).
- `pkgs/nixos-scripts/internal/gitutil/gitutil.go` — worktree-list parsing and naming rules;
  no branch-safety or ahead/behind helpers exist here today.
- `linux/home/shell.nix` — the `code-work()` wrapper launches a normal `opencode` session and
  is the only place the `--done`/`--abort` hints are surfaced.
- `pkgs/nixos-scripts/cmd/code-work/managed.go` + `internal/managedworktree/` — the already
  community-aligned managed lifecycle, referenced as the in-repo contrast.
- `docs/managed-agent-worktrees.md` — documents the managed contract ("nothing pushes or
  cleans up automatically").

## Evidence (mandatory research, pre-repo)

### Primary Git documentation

`git-worktree` man page (git-scm.com, kernel.org, googlesource `git-worktree.adoc`):

- `git worktree remove` removes a worktree; it **refuses** when the worktree has modified or
  untracked files (or submodules) unless `--force`, and refuses twice for a locked worktree.
  It **never deletes the branch** — branch and commits survive removal.
- `git worktree prune` removes `$GIT_DIR/worktrees` admin records for directories already gone;
  it deletes **no files and no branches**, and silently skips locked worktrees.
- `git gc` automatically runs `worktree prune --expire 3.months.ago`; the knob is
  `gc.worktreePruneExpire`.
- Branch deletion is a separate operation: `git branch -d` (safe, refuses if unmerged) vs
  `git branch -D` (force, orphaning commits until reflog/gc expiry).

### Community articles (Exa)

- **Nx blog "How Git Worktrees Changed My AI Agent Workflow"** — the worktree-per-task + agent
  pattern is presented as standard; integration is explicitly "merge back in the main repo … or
  via PR"; recommends a `wt new/open/remove` convenience CLI (John Lindquist `worktree`).
- **Augment Code "Git Worktrees for Parallel AI Agent Execution"** — "worktree-per-task
  (recommended default)" is "confirmed in production at incident.io"; mandates
  "prefer `git worktree remove` over `rm -rf`"; cleanup is a post-merge CI/cron concern.
- **Zylos Research "Git Worktree Isolation Patterns"** — "remove worktrees immediately after
  merge"; "run `git worktree prune` in CI post-merge hooks".
- **Continuum `git worktree remove`/`prune` guides** — "remove never deletes the branch";
  "delete it separately with `git branch -d`"; force-removal is the one case that costs real
  work, so check the diff first.

### Prior-art CLI wrappers (GitHub)

`worktrunk` (max-sixty, "CLI for Git worktree management, designed for parallel AI agent
workflows"), `workmux` (raine, "worktrees + tmux"), `treehouse` (kunchenguid, "manage worktrees
without managing worktrees"), `git-worktree-runner` (coderabbitai), `dmux` (standardagents),
`git-worktree.nvim` (ThePrimeagen), John Lindquist `worktree`, plus agent IDEs `orca`
(stablyai) and `superset` (superset-sh). All converge on the same shape: create/list/open/remove
worktrees, with merge/PR integration kept as a distinct human step and branch deletion separate
from worktree removal.

## Analysis

### Verdict 1 — The desired flow IS a standard community pattern

The desired flow is exactly "worktree-per-task" plus "explicit integration + separate cleanup".
Every primary source and prior-art tool confirms it:

- Create a worktree + branch per task (`git worktree add -b <task> …`).
- Run the agent/editor in that worktree; it commits on its own branch.
- The developer integrates separately (merge, or open/merge a PR).
- Cleanup (worktree removal, branch deletion, prune) happens later and explicitly.

The legacy `code-work <name>` + wrapper already matches the first two steps (create/enter +
normal OpenCode session). The deviation is only in `--done` (below). The in-repo managed flow
(`merge` then `clean`/`abandon`) is already the community-correct shape.

### Verdict 2 — `code-work --done` is partially harmful / inappropriate

`--done` conflates "finished" with "destroy", and its one safety gate is implemented at the
wrong level:

1. **Unpushed-commit data loss (the concrete bug).** The gate is `hasUpstream` = "an upstream
   ref is configured", **not** "the branch is in sync with upstream". A branch pushed once
   (`git push -u origin <branch>`) then given *more* local commits still satisfies
   `hasUpstream`, so `--done` proceeds to `git branch -D`, force-orphaning those commits.
   There is no `git rev-list --count @{u}..HEAD` / ahead-behind check. The printed guidance
   ("Local commits would be lost") only fires when there is *no* upstream at all.
2. **Unnecessary and unsafe force flags.** It verifies a clean tree, then still runs
   `git worktree remove --force` (bypassing the very safety check Git would apply) and
   `git branch -D` (force, instead of `-d` which refuses on unmerged). Community practice is
   `remove` (no force) + `branch -d` after merge.
3. **Branch deletion is coupled into "done".** Primary docs and every wrapper keep worktree
   removal and branch deletion as separate, merge-aware steps. `--done` bundles push-requirement
   + worktree removal + force branch delete + prune into one command with no integration step,
   so it is really "discard-after-push", not "done and integrated".

What `--done` gets right: it refuses on a dirty tree, refuses when no upstream exists at all,
returns to the base branch, and leaves integration entirely explicit (the human integrates
elsewhere). Those instincts match community practice; the force flags and the
configured-upstream ≠ pushed gap are what make it harmful.

## Approaches

1. **Native Git manual lifecycle** — `git worktree add -b`, `list`, `remove`, `prune`,
   `git branch -d`; no wrapper.
   - Pros: zero code; matches the man page exactly; safest (`remove`/`-d` refuse on risk).
   - Cons: highest ceremony per task; nothing enforces the `.worktrees/` layout or the
     base-branch marker; easy to forget cleanup (stale worktrees) and branch deletion.
   - Effort: Low (no code).

2. **Minimal convenience wrapper (current legacy create, minus `--done`/`--abort`)** —
   keep `code-work <name>` create/enter/list/prune; replace destructive finish with a
   *report* ("push, open PR, merge, then `code-work clean`").
   - Pros: matches worktrunk/workmux/treehouse; keeps integration + branch deletion human and
     merge-aware; no force flags.
   - Cons: still two surfaces (legacy + managed) to reconcile; `clean` must add an
     integrated/merged check (or `-d`).
   - Effort: Low.

3. **Automatic cleanup on done (current `--done`, fixed)** — keep one-command finish but
   replace `hasUpstream` with a true ahead/behind gate and swap `-D`→`-d` and `--force`→
   plain remove.
   - Pros: preserves the existing one-command muscle memory; closes the data-loss gap.
   - Cons: still couples "done" with "destroy + branch delete"; still no integration step, so
     "done" remains semantically "abandon-after-push"; diverges from community practice.
   - Effort: Low–Medium.

4. **Explicit cleanup after merge/push/PR (managed-flow shape, generalized)** — make
   `merge`/`integrate` the only authority that advances state, and `clean`/`abandon` the only
   paths that remove worktrees/branches, exactly as the managed lifecycle already does.
   - Pros: this is the documented community recommendation and already exists in-repo for the
     managed surface; guarantees merge authority stays human and branch deletion is merge-aware.
   - Cons: requires retiring or folding the legacy `--done`/`--abort` surface; larger surface
     unification effort.
   - Effort: Medium.

## Recommendation

Confirm the desired flow is the standard community pattern (Verdict 1) and adopt **Approach 4**
as the target, with **Approach 2** as the minimal intermediate fix. Specifically:

1. Treat the legacy `--done`/`--abort` force-delete semantics as the thing to change: remove the
   `--force` worktree remove, the `-D` branch delete, and the configured-upstream gate in favor
   of explicit `merge`-then-`clean`/`abandon` (or, minimally, a true ahead/behind check + `-d`).
2. Prefer convergence on the managed lifecycle (which is already correct) over maintaining two
   divergent worktree surfaces.

The orchestrator should tell the user: the desired flow is community-standard; the legacy
`--done` is the one non-standard, slightly data-unsafe piece (force branch deletion gated on
"upstream configured" rather than "pushed/in-sync"); the managed `merge`/`clean`/`abandon`
surface already implements the recommended shape.

## Risks

- **Unpushed commits silently orphaned** — `hasUpstream` (upstream configured) passes even when
  the branch is ahead of upstream, so `git branch -D` in `--done` destroys unpushed commits.
- **Worktree removal with `--force`** — bypasses Git's dirty/locked refusal; unnecessary given
  the prior clean check, and a footgun if state changes between check and remove.
- **Branch deletion with `-D`** — force-deletes an unmerged branch, orphaning commits until
  reflog/gc expiry (unreachable objects ~2 weeks by default).
- **Merge authority ambiguity** — `--done` performs no integration, so "success" means
  "pushed + discarded locally", not "integrated"; a developer who runs `--done` before
  opening/merging a PR loses the local branch (recoverable only via origin).
- **Stale worktrees** — no post-merge cleanup automation; relies on human `clean`/`prune`
  (default `gc.worktreePruneExpire` is 3 months).

## Ready for Proposal

Yes — recommend a proposal that (a) declares the desired flow community-standard, (b) removes or
gates the legacy `--done`/`--abort` force-delete behavior, and (c) converges on the explicit
`merge`-then-`clean`/`abandon` lifecycle (generalizing the existing managed surface).
