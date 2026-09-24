# Exploration: make-code-work-cleanup-safe-v2

## Purpose

Correct the legacy `code-work --done` command so that finishing a worktree is non-destructive,
while retaining the existing `code-work <task>`, `--list`, `--prune`, and the explicit destructive
`--abort`. This change **supersedes** the malformed SDD planning attempt `make-code-work-cleanup-safe`
(only that change; it is left untouched for audit). This is an evidence-only exploration: no source
code is modified.

## Correction (fixed — non-negotiable)

The correction is fixed and must be implemented as stated:

1. Retain simple `code-work <task>` (create/enter), `--list`, `--prune`, and the explicit
   destructive `--abort`.
2. Make legacy `code-work --done` **non-destructive**: it must never force-remove a worktree
   (`git worktree remove --force`) and never force-delete a branch (`git branch -D`).
3. `--done` emits **concise guidance**: integrate first (merge / open+merge a PR), then
   `git worktree remove <path>` and `git branch -d <branch>`.
4. Do **not** add state, commands, permissions, profiles, wrappers, or lifecycle automation.

The boundary between the two paths is explicitness: `--abort` is the single explicit destructive
escape hatch (the user is discarding work); the non-explicit `--done` path must never force-remove
or force-delete.

## Current State

`code-work` is a Go command (`pkgs/nixos-scripts/cmd/code-work/main.go`). The legacy surface
(`cmdCreate` / `cmdDone` / `cmdAbort` / `cmdList` / `cmdPrune`) coexists with a managed lifecycle
(`managed.go` + `internal/managedworktree`, verbs `new|check|ready|status|merge|clean|abandon|recover-lock`).

Relevant current behavior (confirmed by code inspection):

- `cmdCreate` (`main.go:259-319`) creates a linked worktree at `<repo>/.worktrees/<name>`, writes a
  `.worktree-base` marker, warns on missing gitignore, and prints post-create hints that advertise
  `--done` ("success: cleanup after push") and `--abort` ("discard").
- `cmdDone` (`main.go:324-388`), run from inside the worktree:
  1. Refuses outside `.worktrees/`; reads `.worktree-base`.
  2. Refuses on uncommitted changes.
  3. Refuses when the branch has **no upstream** (`hasUpstream`, `main.go:146-148` = "an upstream
     ref is configured", not "branch is in sync with upstream").
  4. `git checkout <base>`, then `git worktree remove <path> --force`, then `git branch -D <branch>`,
     then `git worktree prune`.
  This is the unsafe piece: the `--force` remove and `-D` delete orphan unpushed/unmerged commits,
  and the configured-upstream gate does not guarantee the branch is pushed or in sync.
- `cmdAbort` (`main.go:392-429`) force-removes (`git worktree remove --force` falling back to
  `rm -rf`), force-deletes (`git branch -D`), and prunes — regardless of dirty state. This is the
  retained explicit-destructive escape hatch.
- `cmdList` (`main.go:432-441`) and `cmdPrune` (`main.go:444-459`) list worktrees / prune stale
  references. `cmdPrune` shares the managed-lifecycle lock.
- `readMarker` (`main.go:172-194`) already prints the exact native cleanup guidance the correction
  wants (return to base branch, `git worktree remove <path>`, `git branch -d <branch>`) for the
  missing-marker case; the non-destructive `--done` should mirror this wording.

Wrapper: `linux/home/shell.nix` `code-work()` (`:66-97`) routes `--done|--abort` through a case
that `cd`s back to the main checkout after the command (`:71-76`), and the `*)` case creates the
worktree, `cd`s in, launches a normal `opencode` session, and prints `--done`/`--abort` hints.

Tests: `pkgs/nixos-scripts/cmd/code-work/main_test.go` `TestCodeWorkCommandHelperProcess`
(`:48-89`) dispatches only `managed`, the managed top-level verbs, and `prune`. It does **not**
dispatch `--done`, `--abort`, `--list`, or the default create path, so `cmdDone`/`cmdAbort`
currently have **zero test coverage**.

## Evidence (mandatory research, pre-repo)

### Git worktree docs

Context7 was unavailable this session (monthly quota exceeded), so the authoritative Git
documentation was read directly from git-scm.com (the same source Context7 indexes), `git-worktree`
2.54.0:

- `remove`: "Only clean worktrees (no untracked files and no modification in tracked files) can be
  removed. Unclean worktrees or ones with submodules can be removed with `--force`." Removing a
  worktree **never deletes the branch**.
- `--force` on `remove` is reserved for unclean/locked worktrees (`--force` twice for locked).
- `prune` removes `$GIT_DIR/worktrees` admin records for directories already gone; it deletes no
  files and no branches.
- The canonical safe finish is `git worktree remove <path>` (no force) followed by a separate,
  merge-aware `git branch -d <branch>`.

### GitHub (identity + community wrapper cleanup patterns)

`get_me` returned login `glats` (Juan Cuzmar). Prior-art and community
wrappers were confirmed — the earlier exploration's list (`worktrunk`, `workmux`, `treehouse`,
`git-worktree-runner`, `dmux`, `git-worktree.nvim`, John Lindquist `worktree`) plus freshly
surfaced tools (`agent-automation-kit` `wt-finish.sh`, `wtsweep`, `git-harvest`, synaptic-canvas
`sc-git-worktree-cleanup`, Spellbook `finish-branch-cleanup`). They all converge on one shape:

- Cleanup is non-destructive by default; force is opt-in and only after explicit confirmation.
- `git worktree remove <path>` (no `--force`) + `git branch -d` (safe delete, refuses unmerged).
- Integration (merge or PR) is a distinct step that precedes cleanup.
- Protected branches / dirty / unmerged work are never force-deleted without consent.
- `rm -rf` is the anti-pattern: it leaves stale admin files that only `prune` fixes.

### Exa current best practices

- Paul Schick, "How to Use Git Worktrees" (2026): remove with `git worktree remove`; `--force` only
  to discard uncommitted changes; `rm -rf` leaves stale `.git/worktrees/` metadata.
- `git-harvest` README: the safe default deletes only the "merged" stage; committed/unmerged work
  requires an explicit opt-in flag and dirty work is never touched without consent.
- `wtsweep` classifies work as `safe` / `review` / `unsafe` and refuses `unsafe` removal unless the
  user explicitly accepts losing work.

## Affected Areas

| Area | Impact | Why |
|------|--------|-----|
| `pkgs/nixos-scripts/cmd/code-work/main.go` | **Modified** | `cmdDone` → non-destructive guidance (exit 0, no git mutation, no `--force` remove, no `-D`); remove now-unused `hasUpstream`; update `usageTemplate` `--done` line and `cmdCreate` post-create hints |
| `pkgs/nixos-scripts/cmd/code-work/main_test.go` | **Modified** | Add `--done` dispatch to the test helper; assert worktree + branch survive `--done` with no mutation; optionally assert `--abort` still discards |
| `linux/home/shell.nix` | **Modified (minimal)** | Split `--done|--abort` case so only `--abort` keeps the cd-back-to-main-root dance (`--done` no longer removes the worktree, so cd-back would be wrong); keep `code-work <task>` + `opencode` launch intact |

Explicitly out of scope (do not touch): `managed.go`, `internal/managedworktree/`,
`shared/opencode/agents.nix`, `shared/opencode/local-agent-overlays.json`,
`docs/managed-agent-worktrees.md`, `openspec/specs/managed-agent-worktrees/spec.md`. No new
subcommands, state files, permission grants, agent profiles, wrappers, or lifecycle automation.

Doc surface: no standalone file documents legacy `--done`/`--abort` (grep of `docs/` returns no
matches); the inline `usageTemplate` text in `main.go` is the only documentation, so updating it is
sufficient. The legacy surface is not covered by any main spec (`managed-agent-worktrees` scopes the
managed surface and the agent permission boundary only), so no delta spec is required.

## Approaches

1. **Non-destructive `--done` guidance (the fixed correction)** — rewrite `cmdDone` to verify it is
   inside a worktree, warn (non-fatal) on uncommitted changes, print the concise guidance
   (integrate first; then `git worktree remove <path>` and `git branch -d <branch>`; `--abort` for
   discard; `--list`/`--prune` for status), and exit 0 with zero git mutation. Remove `hasUpstream`.
   - Pros: exactly matches the fixed correction; zero data-loss surface; native-command guidance;
    `--abort` remains the explicit discard path; minimal diff confined to one function + usage text.
   - Cons: users who relied on `--done` auto-cleanup must now run two native commands.
   - Effort: Low.

2. **Auto-cleanup with tightened gates (current `--done`, "fixed" to a real ahead/behind check)** —
   keep one-command finish but replace `hasUpstream` with `git rev-list --count @{u}..HEAD` and swap
   `-D`→`-d`, `--force`→plain `remove`.
   - Pros: preserves one-command muscle memory.
   - Cons: still couples "done" with "destroy + delete"; violates the fixed correction (must never
     force-remove/force-delete); diverges from community practice.
   - Effort: Low–Medium. **Rejected** — contradicts the fixed correction.

3. **Converge on the managed lifecycle** (`merge` → `clean`/`abandon`) — retire the legacy surface.
   - Pros: already community-aligned and in-repo.
   - Cons: adds lifecycle automation / surface unification, which the correction explicitly forbids.
   - Effort: Medium. **Rejected** — out of scope per the correction.

## Recommendation

Adopt **Approach 1** verbatim. The fix is a single-function change to `cmdDone` (plus removal of
`hasUpstream`, an update to `usageTemplate`/create hints, a test-helper dispatch + non-destructive
assertion, and a minimal wrapper-case split). `--abort` stays destructive; `code-work <task>`,
`--list`, and `--prune` stay unchanged; nothing new is added.

## Risks

- **Muscle-memory loss for `--done`** — users who used `--done` for cleanup must now integrate,
  then run `git worktree remove <path>` and `git branch -d <branch>`; mitigated by the guidance text
  and by `--abort` remaining the discard path.
- **Wrapper cd-back misbehavior** — the current `--done|--abort` case `cd`s to the main root after
  both; if `--done` is made non-destructive but the wrapper still `cd`s back, the user is yanked out
  of a still-existing worktree. The wrapper case must be split (`--abort` only).
- **Dead code** — `hasUpstream` becomes unused after the rewrite and must be removed or it lingers
  as drift.
- **Test gap** — `cmdDone`/`cmdAbort` have no existing tests; new coverage must prove `--done` is a
  no-op (worktree + branch survive, exit 0) and `--abort` still discards.
- **Regression risk on `--abort`** — must remain byte-behaviorally destructive; the split of the
  wrapper case must not accidentally route `--abort` past the cd-back dance.

## Ready for Proposal

Yes. Propose a change that (a) rewrites `cmdDone` to be non-destructive and print the concise
integrate-then-`git worktree remove`/`git branch -d` guidance, (b) removes `hasUpstream`, (c) leaves
`--abort`/`--list`/`--prune`/`code-work <task>` unchanged, (d) splits the wrapper `--done`/`--abort`
case, and (e) adds test coverage for the non-destructive path. Do not add state, commands,
permissions, profiles, wrappers, or lifecycle automation.
