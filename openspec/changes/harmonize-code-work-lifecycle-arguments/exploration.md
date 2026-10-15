# Exploration: harmonize-code-work-lifecycle-arguments

## Purpose

Harmonize the legacy `code-work` lifecycle argument surface so every target-specific
lifecycle command takes an explicit, required task name and runs from the main checkout,
mirroring the already-harmonized managed surface (`merge <task>`, `clean <task>`,
`abandon <task>`). The legacy `--done` and `--abort` still infer their target from the current
working directory today; this change removes that cwd inference and makes the target explicit.
This is an evidence-only exploration: no source code is modified.

## Current State

`code-work` is a Go command (`pkgs/nixos-scripts/cmd/code-work/main.go`) with two surfaces.
The managed surface was already harmonized by `simplify-worktree-cli` (shipped, commit
`807e5ed`): `new|check|ready|status|merge|clean|abandon|recover-lock` address a task by an
explicit ID (`merge <id>`, `clean <id>`, `abandon <id>`) and require the main checkout via
`validateManagedSelector` (cwd must equal repo root). The legacy surface, after
`make-code-work-cleanup-safe-v2` (shipped, commit `64c7092`), still uses **cwd inference**:

- `cmdDone(pwd, repoRoot, worktreesDir)` (`main.go:318-352`) — non-destructive guidance.
  Derives the worktree name from `pwd` via `gitutil.InWorktrees` + `gitutil.WorktreeName`;
  refuses outside `.worktrees/`. Prints "Integrate your branch … `git worktree remove <path>`
  … `git branch -d <branch>`" with zero git mutation.
- `cmdAbort(pwd, repoRoot, worktreesDir)` (`main.go:356-393`) — destructive. Derives the target
  from `pwd`; `os.Chdir(repoRoot)` then `git worktree remove --force` (falling back to
  `rm -rf`), `git branch -D`, prune.
- `cmdList(pwd, repoRoot, worktreesDir)` (`main.go:396-405`) — lists worktrees and prints a
  "(current worktree: …)" hint from cwd (informational, not target-specific).
- `cmdPrune(repoRoot)` — prunes stale references (not target-specific).
- `cmdCreate(repoRoot, worktreesDir, name)` — creates a worktree named `<name>` on branch
  `<name>`; prints post-create hints advertising `--done`/`--abort` **without** a task name.

Dispatch (`main()` `main.go:234-237`) routes `--done`/`--abort` straight to `cmdDone`/`cmdAbort`
with no argument parsing, so the task name is never read from the CLI.

The zsh wrapper `code-work()` (`linux/home/shell.nix:66-100`): the `--abort` case captures the
main root and `cd`s back after the command (`:74-78`) because `--abort` is run from inside the
worktree it deletes; the `*)` case creates the worktree, `cd`s in, runs `opencode`, then prints
hints (`:86-97`) that advertise `--done`/`--abort` **without** a task name.

Tests (`main_test.go`): `TestCodeWorkCommandHelperProcess` (`:48-105`) dispatches `--done`/
`--abort` using `pwd` (no name argument). `TestLegacyDoneDoesNotDeleteAndAbortDiscards`
(`:396-445`) runs both from inside the worktree with no name.

## Affected Areas

- `pkgs/nixos-scripts/cmd/code-work/main.go` — `main()` dispatch (`--done`/`--abort` must parse
  a required task-name argument), `cmdDone`, `cmdAbort`, `usageTemplate`, and `cmdCreate`
  post-create hints.
- `pkgs/nixos-scripts/cmd/code-work/main_test.go` — helper dispatch must pass the name; new
  tests for explicit-name resolution, missing/unknown target, and invalid-name rejection.
- `linux/home/shell.nix` — remove the `--abort` cd-back dance (no longer needed); update the
  `*)` post-opencode hints to name the task and return the user to the main checkout.
- Reused but unchanged: `gitutil.ValidName` (name validation), `gitutil.WorktreeName`,
  `readMarker`, `resolveRepoRoot`.
- Explicitly out of scope: `managed.go`, `internal/managedworktree/`, `internal/gitutil/`,
  agent configs (`shared/opencode/*`), `docs/managed-agent-worktrees.md`, and the
  `managed-agent-worktrees` spec. No new commands, state files, permission grants, agent
  profiles, wrappers, or lifecycle automation. `--list`'s "(current worktree: …)" hint and
  `--prune` are not target-specific and are left unchanged.

## Evidence (mandatory research, pre-repo)

### Git worktree docs

Context7 returned "monthly quota exceeded" this session; the authoritative `git-worktree` manual
(2.54.0, latest) was read directly from git-scm.com (the same source Context7 indexes):

- `remove`: "Only clean worktrees … can be removed. Unclean worktrees or ones with submodules
  can be removed with `--force`. The main worktree cannot be removed." It **never deletes the
  branch**; branch deletion is a separate, merge-aware operation.
- `--force` on `remove` is reserved for unclean/locked worktrees (twice for locked).
- `prune` removes `$GIT_DIR/worktrees` admin records for worktrees whose working trees are
  missing; it deletes no files and no branches.
- Worktrees are addressed "by path, either relative or absolute" — confirming an explicit
  name/path argument is the native convention, not cwd inference.

### GitHub (identity + community wrappers)

`get_me` returned login `glats` (Juan Cuzmar). Current community wrappers all converge on an
explicit task/worktree-name argument for lifecycle commands, and several make the CLI binary
cwd-neutral:

- **`nanasess/git-worktree-manager`** — `worktree cleanup feature-login --force
  --delete-branches` and `worktree switch feature-login`: the target is an explicit name.
- **`pi2pie/git-worktree-tasks` (gwtt)** — `gwtt create "my-feature"`, `gwtt finish "my-task"`,
  `gwtt cleanup "my-task"`: every lifecycle verb takes the task name; finish/cleanup are separate
  from create; force branch delete is opt-in (`--force-branch`).
- **`WorktreePilot/worktree-pilot` (wtp)** — `wtp start <task>`, `wtp finish <task>
  --remove-worktree --delete-branch`: "Pass task names — no need to type the full branch";
  cleanup requires explicit confirmation; "Never `--force` unless you say to discard."
- **`kioku/wt-core`** — the most directly relevant: "The direct `wt-core` CLI never changes its
  caller's cwd. Each binding wraps the binary and may `cd` in the parent shell … normal
  `remove`/`merge` return to the repository root when cleanup removes the current worktree."
  Also: "The main worktree is sacred. You can never `remove`, `merge`, or `prune` the main
  worktree."
- **`sc-git-worktree` (Claude Code plugin)** — `/sc-git-worktree --cleanup <name>` and
  `--abort <name>`; "Never modify dirty worktrees without explicit approval."

### Exa current best practice

Exa surfaced the same set of repos. The consistent pattern: lifecycle commands are addressed by
an explicit task name, run from the main checkout, and the CLI binary itself does not change the
caller's cwd (the shell wrapper performs any directory navigation). Integration/cleanup remain
separate, human-initiated steps; destructive cleanup (`--force`, `-D`) is opt-in and gated.

## Analysis

The legacy `--done`/`--abort` are the only remaining target-specific lifecycle commands that
infer their target from cwd. The managed surface already demonstrates the target shape this
change adopts: `clean <id>` (non-destructive-gated removal), `abandon <id>` (preserve for
diagnosis), `merge <id>` (integration) all take an explicit ID and run from the main checkout.
Harmonizing `--done <task>`/`--abort <task>` to the same shape removes the last cwd-inference
divergence without touching state, permissions, or lifecycle logic.

### Determination 1 — Minimal exact changes

1. `main()` dispatch: change the `--done`/`--abort` cases to require exactly one following
   argument and pass it as the task name. Zero-arg and multi-arg forms exit with a usage error
   (exit 2) naming the required argument, e.g. `usage(scriptName, "--done requires a worktree name")`.
2. `cmdDone(repoRoot, worktreesDir, name string)`: drop the `pwd` parameter; validate
   `gitutil.ValidName(name)`; derive `wtPath = filepath.Join(worktreesDir, name)`; verify the
   directory exists; keep the non-destructive body verbatim (read marker, warn on uncommitted
   changes, print targeted integrate-then-remove-then-`-d` guidance). No git mutation, no chdir.
3. `cmdAbort(repoRoot, worktreesDir, name string)`: drop the `pwd` parameter and the
   `gitutil.InWorktrees`/`WorktreeName`/`os.Chdir(repoRoot)` logic; validate the name; verify
   the directory exists; then force-remove, force-delete the worktree's own HEAD branch, and
   prune. Since git commands take an absolute path and the caller is already in the main
   checkout, no chdir is required.
4. `usageTemplate` (`main.go:26-43`): change `--done`/`--abort` lines and examples to the
   `--done <task>` / `--abort <task>` forms.
5. `cmdCreate` post-create hints (`main.go:309-311`): print `code-work --done <name>` /
   `code-work --abort <name>` with the created name.

The full diff is confined to `main.go` (dispatch + two functions + usage text + hints), the
test helper + new tests, and the wrapper.

### Determination 2 — Compatibility migration for zero-arg flags

The task explicitly forbids cwd inference and optional task identifiers, so a cwd fallback is
**not** an option. The correct migration is a **hard usage error**: `code-work --done` and
`code-work --abort` with no argument (or more than one) fail with exit 2 and a message naming
the required argument, exactly as `clean`/`abandon`/`merge` already do ("usage: clean <id>",
"usage: abandon <id>"). This is a deliberate breaking change for muscle-memory users of
zero-arg `--done`/`--abort`; the guidance text and post-create hints supply the corrected form.
No shim or deprecation window is required because the cwd-inferred form is the very thing being
removed, and `--done` is already non-destructive (the safe-done change shipped first), so the
only cost of misremembering is a usage error, never data loss.

### Determination 3 — Safety conditions for `--abort <task>` target validation

`--abort <task>` is the single explicit destructive escape hatch. Because the target is now a
caller-supplied name (not a verified cwd), it MUST validate before any `rm -rf`/`-D`:

1. **Name validity** — `gitutil.ValidName(name)` (rejects leading slash, `..`, and other
   traversal) before constructing any path. This is the path-traversal guard.
2. **Path containment** — derive `wtPath = filepath.Join(worktreesDir, name)` where
   `worktreesDir = repoRoot/.worktrees`, so the target is structurally confined under
   `.worktrees/` and can never resolve to the main checkout or an arbitrary path.
3. **Existence and directory check** — `os.Stat(wtPath)` must succeed and be a directory;
   otherwise error and do **not** fall back to `rm -rf` on a path that does not correspond to a
   known worktree. (The current `rm -rf` fallback is only safe because the path was derived from
   a verified cwd; with an explicit name it must be gated by the existence check.)
4. **Main-worktree protection** — the main repo is never a valid target (it lives at
   `repoRoot`, not under `.worktrees/`), matching git's own "the main worktree cannot be removed"
   guarantee; no extra check is strictly needed, but a defensive `wtPath != repoRoot` assertion
   is cheap.
5. **Branch deletion derives from the worktree's own HEAD** — resolve the branch via
   `git -C wtPath rev-parse --abbrev-ref HEAD` and delete only that branch, so abort deletes the
   branch the named worktree actually has checked out, never an arbitrary user-supplied branch.
6. **No chdir** — the command never changes the caller's cwd; "caller remains in main cwd" is
   satisfied structurally (the binary cannot alter the parent shell, and the wrapper's cd-back
   dance is removed).

### Determination 4 — Tests

Update `TestCodeWorkCommandHelperProcess` (`:87-91`) to pass `args[1]` as the name. Then:

- `TestLegacyDoneDoesNotDeleteAndAbortDiscards` — rewrite `done`/`abort` subtests to run from
  the **main checkout** with an explicit `<task>`; assert `--done <task>` prints the targeted
  guidance (with the correct name), exits 0, and leaves worktree + branch intact; assert
  `--abort <task>` removes the worktree and branch while the main checkout is untouched.
- New `TestLegacyDoneRequiresTaskName` — `--done` with zero args (and with two args) exits 2
  with a usage error; does not mutate.
- New `TestLegacyAbortRequiresTaskName` — `--abort` with zero args exits 2.
- New `TestLegacyAbortUnknownTarget` — `--abort <missing>` errors and does not `rm -rf` anything
  outside `.worktrees/` (no filesystem mutation).
- New `TestLegacyAbortRejectsInvalidName` — `--abort ../evil`, `--abort /abs`, `--abort .`
  rejected by `ValidName` with no mutation.
- New `TestLegacyDoneUnknownTarget` — `--done <missing>` errors with a "not found" message.

Regression gate: `go -C pkgs/nixos-scripts test ./...`.

## Approaches

1. **Explicit required task name (recommended)** — `--done <task>` / `--abort <task>`, run from
   the main checkout, no cwd inference, no chdir, zero-arg = usage error.
   - Pros: matches the managed surface and the community pattern (gwtt/wtp/wt-core/nanasess);
     removes the last cwd-inference divergence; minimal diff (dispatch + two functions + text);
     abort validation is structurally safe.
   - Cons: breaking change for zero-arg muscle memory (mitigated by usage errors + hints).
   - Effort: Low.

2. **Optional task name with cwd fallback** — `--done [task]`, infer from cwd when omitted.
   - Pros: non-breaking.
   - Cons: explicitly contradicts the requirement ("no optional task identifiers", "no cwd
     inference"); keeps two resolution modes.
   - Effort: Low. **Rejected** — violates the fixed requirement.

3. **Retire the legacy surface and converge on managed `clean`/`abandon`** — remove `--done`/
   `--abort` entirely.
   - Pros: single surface.
   - Cons: adds lifecycle/state unification, which is out of scope ("no lifecycle additions");
     loses the simple non-stateful create/enter flow.
   - Effort: Medium. **Rejected** — out of scope.

## Recommendation

Adopt **Approach 1** verbatim. Rewrite `cmdDone`/`cmdAbort` to take a required, validated task
name, derive the worktree path from the main-checkout-relative `.worktrees/` directory, drop the
`pwd`/chdir machinery, and reject zero-arg invocations with a usage error. Update `usageTemplate`
and `cmdCreate`/wrapper hints to the new `--done <task>`/`--abort <task>` forms. Remove the
wrapper's `--abort` cd-back dance (the target is named, so the caller never leaves the main
checkout) and have the `*)` branch return the user to the main checkout after `opencode` exits so
the follow-up `--done <task>`/`--abort <task>` run from the right place. No state, permissions,
profiles, or lifecycle logic changes.

## Risks

- **Muscle-memory break** — zero-arg `--done`/`--abort` now error; mitigated because `--done` is
  already non-destructive (no data loss from a mistake) and hints name the corrected form.
- **Wrapper positioning** — after `opencode` exits the user is inside the worktree; if the
  wrapper does not return to the main checkout, the follow-up `--done <task>`/`--abort <task>`
  would be run from the wrong cwd. Must cd back to main in the `*)` branch (the commands resolve
  the target by name, so they would still work, but the "run from main checkout" convention would
  be violated).
- **`rm -rf` fallback safety** — currently gated only by cwd; with an explicit name it must be
  gated by the existence/directory check, or an attacker-supplied name could `rm -rf` an
  unexpected path. `ValidName` + path containment + existence check close this.
- **Branch deletion scope** — must delete the worktree's own HEAD branch, not an arbitrary
  caller-supplied branch.
- **Test gap** — `--done`/`--abort` explicit-name paths have no existing coverage; new tests must
  prove name resolution, usage errors, unknown-target and invalid-name rejection.

## Ready for Proposal

Yes. Propose a change that (a) makes `--done <task>` and `--abort <task>` require an explicit,
validated task name run from the main checkout, (b) removes cwd inference and the wrapper cd-back
dance, (c) rejects zero-arg forms with a usage error, (d) adds abort target validation (name,
containment, existence, HEAD-derived branch), and (e) adds test coverage. No agent, permission,
state, or lifecycle additions.
