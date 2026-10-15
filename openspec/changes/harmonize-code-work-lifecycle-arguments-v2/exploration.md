# Exploration: harmonize-code-work-lifecycle-arguments-v2

## Purpose

Harmonize the legacy `code-work` lifecycle argument surface so the two target-specific verbs
`--done` and `--abort` take a **mandatory task name**, matching the already-harmonized managed
verbs (`merge <task>`, `clean <task>`, `abandon <task>`) and `code-work <task>` itself. Today the
legacy `--done`/`--abort` infer their target from the caller's working directory; this change
removes that cwd inference and makes the target explicit, while keeping `--done` non-destructive
and `--abort` the single explicit destructive discard path that never deletes the caller's own
directory.

This is a fresh, evidence-only exploration. It does not rely on or modify the prior
`harmonize-code-work-lifecycle-arguments` / `harmonize-code-work-lifecycle-arguments-v2` attempts;
all code facts and the research below were independently re-verified. No source code is modified.

## Correction (fixed — non-negotiable)

1. `code-work <task>` — create/enter a worktree (unchanged).
2. `--list` and `--prune` — global, main-checkout operations (unchanged).
3. `--done <task>` — **required** task name; guidance-only; non-destructive (zero Git mutation).
4. `--abort <task>` — **required** task name; destroys that named target from a stable main
   checkout; never depends on or infers the caller's cwd.
5. No optional IDs, no cwd inference, no agent wiring, no permission grants, no new state files,
   no new lifecycle layers or commands.

The change is an *argument-shape* alignment: `--done`/`--abort` become name-addressed exactly as
`code-work <task>` and the managed verbs already are, leaving no command that infers its target
worktree from cwd.

## Current State (verified against HEAD `64c7092`)

`code-work` is a Go command (`pkgs/nixos-scripts/cmd/code-work/main.go`, module
`github.com/glats/nixos-scripts`, Go 1.24, git 2.54.0 runtime). Two surfaces coexist:

- **Legacy** (this change's subject): `code-work <task>` (`cmdCreate`), `--done` (`cmdDone`),
  `--abort` (`cmdAbort`), `--list` (`cmdList`), `--prune` (`cmdPrune`).
- **Managed** (`managed.go` + `internal/managedworktree`): `new|check|ready|status|merge|clean|
  abandon|recover-lock`. Out of scope.

Verified current behavior:

- `main()` dispatch (`main.go:229-248`) routes `--done` → `cmdDone(pwd, repoRoot, worktreesDir)`
  and `--abort` → `cmdAbort(pwd, repoRoot, worktreesDir)`. Both receive the **cwd** (`pwd`) and
  derive the worktree from it via `gitutil.InWorktrees(pwd, worktreesDir)`. There is no argument
  parsing for `--done`/`--abort`; the task name is never read from the CLI.
- `cmdDone` (`main.go:318-352`) is already non-destructive (guidance-only, zero Git mutation) since
  `make-code-work-cleanup-safe-v2`, but requires the caller to be **inside** the worktree and
  accepts no task-name argument.
- `cmdAbort` (`main.go:356-393`) requires the caller inside the worktree, reads the branch from the
  worktree HEAD, then `os.Chdir(repoRoot)` to escape before `git worktree remove <path> --force`
  (fallback `rm -rf`), `git branch -D <branch>`, and `prune`. The `Chdir` exists only because the
  old shape deletes the caller's own directory.
- `cmdList` (`main.go:396-405`) lists worktrees and prints a `(current worktree: …)` hint from cwd
  (informational). `cmdPrune` (`main.go:408-423`) prunes stale refs and acquires the managed
  lifecycle lock (`managedworktree.AcquireLock` + `managedCommonDir`).
- `cmdCreate` (`main.go:251-313`) creates `.worktrees/<name>` on branch `<name>`, writes
  `.worktree-base`, warns on missing `.gitignore`, and prints post-create hints that advertise
  `--done`/`--abort` **without** a name (`main.go:309-311`).
- Wrapper `linux/home/shell.nix` `code-work()` (`:66-100`): `--done` is a pass-through; `--abort`
  saves the main root, runs the command, then `cd`s back (`:74-79`); `*` creates, `cd`s in, launches
  a plain `opencode` session, then prints `--done`/`--abort` hints (`:95-96`).
- Tests (`main_test.go`): `TestCodeWorkCommandHelperProcess` (`:48-105`) dispatches `--done`/
  `--abort` using `pwd` with no name argument; `TestLegacyDoneDoesNotDeleteAndAbortDiscards`
  (`:396-445`) runs both from inside the worktree with no name.

### Prior-attempt correction — the `~` path-abbreviation claim does not hold

The prior attempt's central "critical discovery" — that `git worktree list --porcelain` emits a
home-abbreviated `~/.nixos` and therefore `resolveRepoRoot()` returns a non-absolute path — is a
**false positive**. Independently re-verified in this repo (git 2.54.0):

- `git worktree list --porcelain` (run directly, `env git …`) emits `worktree /home/glats/.nixos`
  — a fully **absolute** path. The `~` abbreviation appears only in the human-readable
  `git worktree list` (non-porcelain) format.
- The shipped binary resolves correctly: `pkgs/nixos-scripts/code-work --list` prints
  `/home/glats/.nixos …` (absolute) for every entry.
- Root cause of the false discovery: the `rtk` wrapper rewrites `git worktree list --porcelain` to
  plain `git worktree list` (human format), which abbreviates `$HOME` to `~`. The Go binary calls
  `exec.Command("git", "worktree", "list", "--porcelain")` directly and never goes through that
  wrapper, so it receives the real porcelain format.

Consequence: **no root-resolution fix is required**. `resolveRepoRoot()` (via `gitutil.MainWorktree`,
first porcelain entry = main worktree) already returns an absolute, cwd-independent main root, and
`--list` already works. The change is purely the argument-shape harmonization; the false `~` fix
must **not** be carried into the proposal.

## Evidence (research, pre-repo)

### Git worktree docs (Context7 + primary source)

Context7 returned `Monthly quota exceeded` this session, so the authoritative primary source —
`git-worktree(1)` (git-scm.com / kernel.org, 2.54.0) — was read directly (the same source Context7
indexes). Key facts:

- `git worktree remove` removes a worktree; it **refuses** when the worktree has untracked/modified
  files or submodules unless `--force`, and refuses twice for a locked worktree. It **never deletes
  the branch**.
- `git worktree prune` removes `$GIT_DIR/worktrees` admin records for already-missing directories;
  it deletes no files and no branches. Stale records are otherwise reclaimed by `git gc` per
  `gc.worktreePruneExpire`.
- The canonical safe finish is `git worktree remove <path>` (no `--force`) followed by a separate,
  merge-aware `git branch -d <branch>`; `git branch -D` force-orphans commits.
- `git worktree list --porcelain` is the stable, scriptable format; worktrees are identified by
  **path**, and the first entry is always the main worktree.

### GitHub identity + wrapper prior art

`get_me` → login `glats` (Juan Cuzmar, id `4707766`). Current name-addressed wrapper CLIs (Exa +
GitHub repo search, 2026) all converge on one shape — lifecycle commands address the worktree by
name/path, and destructive cleanup is launched from a stable checkout so the caller's cwd survives:

- **`kioku/wt-core`** — `wt remove feature/auth`, `wt prune --execute`; "The main worktree is
  sacred. You can never remove, merge, or prune the main worktree"; "The direct `wt-core` CLI never
  changes its caller's cwd … normal `remove`/`merge` return to the repository root when cleanup
  removes the current worktree."
- **`nils-git-cli`** — `worktree remove <slug>`: "refusing the primary checkout and the current
  worktree" (explicit cwd-survival guard); resolves slugs against the primary worktree "identically
  whether run from the primary checkout or from inside any linked worktree."
- **`sotarok/gw`** — `gw end 123`, `gw clean`: name-addressed removal with three pre-removal safety
  checks (uncommitted, unpushed, unmerged).
- **`tdhopper/wt`** — `wt rm my-feature --yes --delete-branch`, `wt prune-merged`: removal always
  names the worktree; branch deletion is a separate opt-in flag.
- **`shutootaki/gwm`** — `gwm remove fix-bug`; **`tobiase/worktree-utils`** — `wt rm feature-branch`,
  `wt integrate feature-branch`; **`lu0/git-worktree-wrapper`** — deleting a branch deletes its
  worktree and "if you are cd'd into the worktree/branch you are deleting, the script will cd you
  into the root directory."

Prior explorations already catalogued the same shape (`worktrunk`, `workmux`, `treehouse`,
`git-worktree-runner`, `dmux`, `git-worktree.nvim`, John Lindquist `worktree`, `kwt`, `wtree`,
`mwt`, `gwtt`, `wtp`, `nanasess/git-worktree-manager`): explicit-name targeting, main-checkout
launch point for destructive ops, branch deletion separate from worktree removal.

### Exa current community practice

- `git-scm.com` `git-worktree` man page: `remove`/`prune` semantics as above; worktrees are
  identified by path.
- `continuumcode.ai` "Git worktrees explained" (Aug 2026): clean up with `git worktree remove`;
  run `git worktree prune` after hand-deleting; "deleting a worktree does not delete its branch, so
  follow with `git branch -d`."
- `alvinunreal/oh-my-opencode-slim` worktrees skill: cleanup is an explicit, named step
  (`git worktree remove .slim/worktrees/<slug>`) performed from the main checkout after user
  approval; destructive commands are gated on explicit confirmation.
- `tonyreviewsthings.com` "Git worktrees for agents" (Aug 2026): "Clean up with Git, not with
  `rm -rf`"; removal is a distinct, audited step after evidence is complete.

Community consensus: name the worktree in destructive/read commands; never infer the target from
the process cwd; keep the main checkout as the launch point for destructive cleanup so the shell's
own directory survives; keep branch deletion separate from worktree removal.

## Affected Areas

| Area | Impact | Why |
|------|--------|-----|
| `pkgs/nixos-scripts/cmd/code-work/main.go` | **Modified** | `main` dispatch: `--done <task>` / `--abort <task>` require exactly one following name (usage error on missing/extra); rewrite `cmdDone`/`cmdAbort` to resolve `.worktrees/<task>` by name instead of `pwd`; drop `InWorktrees` guards; remove `os.Chdir` from abort; update `usageTemplate` and `cmdCreate` hints to the `<task>` form. |
| `pkgs/nixos-scripts/cmd/code-work/main_test.go` | **Modified** | Extend helper dispatch to `--done <task>` / `--abort <task>`; add tests for missing-name usage error, name-addressed `--done` no-op, name-addressed `--abort` discard from the main checkout, unknown-target, and invalid-name rejection. |
| `linux/home/shell.nix` | **Modified (minimal)** | Collapse the `--done`/`--abort` cases to a pass-through (the `--abort` save-root + `cd`-back dance is obsolete once abort is name-addressed); update the `*` post-opencode hints to name the task. No new wrapper logic. |
| `pkgs/nixos-scripts/internal/gitutil/gitutil.go` | **Unchanged** (possibly prune dead code) | `InWorktrees`/`WorktreeName` may become unused once cwd inference is removed; `MainWorktree`, `ValidName`, `NameRe` remain used. |

Explicitly out of scope (do not touch): `managed.go`, `internal/managedworktree/`,
`shared/opencode/agents.nix`, `shared/opencode/local-agent-overlays.json`,
`docs/managed-agent-worktrees.md`, `openspec/specs/managed-agent-worktrees/spec.md`. No new
subcommands, state files, permission grants, agent profiles, wrappers, or lifecycle automation.
The legacy surface has no main spec (only the managed surface is specced) and no standalone doc
(the inline `usageTemplate` is the only documentation), so no delta spec is required.

## Exact source changes

### `pkgs/nixos-scripts/cmd/code-work/main.go`

1. `main()` dispatch (`:234-237`): require exactly one argument for both verbs.

   ```go
   case "--done":
       if len(args) != 2 {
           usage(scriptName, "--done requires a worktree name")
       }
       cmdDone(repoRoot, worktreesDir, args[1])
   case "--abort":
       if len(args) != 2 {
           usage(scriptName, "--abort requires a worktree name")
       }
       cmdAbort(repoRoot, worktreesDir, args[1])
   ```

2. `cmdDone` (`:318-352`): change signature to `cmdDone(repoRoot, worktreesDir, name string)`;
   drop the `pwd` parameter and the `gitutil.InWorktrees`/`WorktreeName` derivation; validate the
   name and resolve the path by name; keep the guidance body verbatim (read marker, warn on
   uncommitted changes, print targeted integrate-then-remove-then-`-d` guidance), still zero Git
   mutation and no chdir.

   ```go
   func cmdDone(repoRoot, worktreesDir, name string) {
       if repoRoot == "" {
           die("Not inside a git repository")
       }
       if !gitutil.ValidName(name) {
           dieCode(fmt.Sprintf("Invalid worktree name '%s'.", name), 2)
       }
       wtPath := filepath.Join(worktreesDir, name)
       if fi, err := os.Stat(wtPath); err != nil || !fi.IsDir() {
           die(fmt.Sprintf("Worktree '%s' not found at %s", name, wtPath))
       }
       baseBranch := readMarker(wtPath, repoRoot, worktreesDir)
       // ... unchanged uncommitted-changes warning ...
       currentBranch := gitCapture("-C", wtPath, "rev-parse", "--abbrev-ref", "HEAD")
       // ... unchanged targeted guidance, now parameterized by name/wtPath ...
   }
   ```

3. `cmdAbort` (`:356-393`): change signature to `cmdAbort(repoRoot, worktreesDir, name string)`;
   drop the `pwd` parameter, the `gitutil.InWorktrees`/`WorktreeName` derivation, and the
   `os.Chdir(repoRoot)` call; validate the name and resolve the path by name; resolve the branch
   from the named worktree's own HEAD; then force-remove, force-delete, prune. The caller remains
   in the main checkout, so no chdir is required and the caller's cwd is never deleted.

   ```go
   func cmdAbort(repoRoot, worktreesDir, name string) {
       if repoRoot == "" {
           die("Not inside a git repository")
       }
       if !gitutil.ValidName(name) {
           dieCode(fmt.Sprintf("Invalid worktree name '%s'.", name), 2)
       }
       wtPath := filepath.Join(worktreesDir, name)
       if fi, err := os.Stat(wtPath); err != nil || !fi.IsDir() {
           die(fmt.Sprintf("Worktree '%s' not found at %s", name, wtPath))
       }
       // Optional hardening: refuse when the caller is standing inside the target
       // (closes the only remaining "caller cwd disappears" hole).
       if cwd, err := os.Getwd(); err == nil && filepath.Clean(cwd) == filepath.Clean(wtPath) {
           die(fmt.Sprintf("Refusing to discard worktree '%s': you are inside it. Run from the main checkout.", name))
       }
       currentBranch := gitCapture("-C", wtPath, "rev-parse", "--abbrev-ref", "HEAD")
       fmt.Printf("> Discarding worktree '%s'...\n", name)
       remove := exec.Command("git", "worktree", "remove", wtPath, "--force")
       remove.Stderr = io.Discard
       if err := remove.Run(); err != nil {
           if err := os.RemoveAll(wtPath); err != nil {
               fmt.Fprintln(os.Stderr, err)
               os.Exit(1)
           }
       }
       branch := exec.Command("git", "branch", "-D", currentBranch)
       branch.Stderr = io.Discard
       _ = branch.Run()
       cmdPrune(repoRoot)
       fmt.Printf("> Worktree '%s' discarded.\n", name)
   }
   ```

4. `usageTemplate` (`:26-43`): update the `--done`/`--abort` lines and examples to the `<task>`
   forms (`%[1]s --done <task>  Finish worktree <task> and show safe cleanup guidance`;
   `%[1]s --abort <task>  Discard worktree <task> (destructive: force remove)`; matching examples).

5. `cmdCreate` post-create hints (`:309-311`): print the name:

   ```go
   fmt.Printf("  code-work --done %s    # show safe native cleanup guidance\n", name)
   fmt.Printf("  code-work --abort %s   # discard everything (destructive)\n", name)
   ```

### `linux/home/shell.nix`

Collapse the `--done`/`--abort` cases to a pass-through and update the `*` hints:

```zsh
--done|--abort|--list|--prune|--help|-h)
    command code-work "$@"
    ;;
# * case (unchanged except hints):
    echo "> Run 'code-work --done $wt_name' to save and cleanup"
    echo "> Run 'code-work --abort $wt_name' to discard everything"
```

The `--abort` save-root + `cd`-back dance (`:74-79`) is removed: abort is now name-addressed and
run from the main checkout, so it never deletes the caller's directory.

## Target validation (for `--abort <task>`)

`--abort <task>` is the single explicit destructive escape hatch. Because the target is now a
caller-supplied name (not a verified cwd), it MUST validate before any `rm -rf`/`-D`:

1. **Name validity** — `gitutil.ValidName(name)` (`^[a-zA-Z0-9][a-zA-Z0-9._/-]*$`, no leading
   slash) rejects `..`, leading `/`, and traversal before any path is constructed.
2. **Path containment** — `wtPath = filepath.Join(worktreesDir, name)` where
   `worktreesDir = repoRoot/.worktrees`, structurally confining the target under `.worktrees/` and
   making the main checkout or any arbitrary path unreachable.
3. **Existence and directory check** — `os.Stat(wtPath)` must succeed and be a directory;
   otherwise error and do **not** fall back to `rm -rf` on a path that is not a known worktree
   (the current `rm -rf` fallback is only safe because the path was derived from a verified cwd).
4. **Main-worktree protection** — the main repo lives at `repoRoot`, not under `.worktrees/`, so it
   is never a valid target; this mirrors git's "the main worktree cannot be removed" guarantee.
5. **Branch deletion derives from the worktree's own HEAD** — resolve the branch via
   `git -C wtPath rev-parse --abbrev-ref HEAD` and delete only that branch, never an arbitrary
   caller-supplied branch.
6. **No chdir / cwd independence** — the target is resolved purely by name and the main root via
   `git worktree list --porcelain` (first entry, absolute, cwd-independent); the optional
   "caller-inside-target" refusal is a safety *check*, not cwd *inference* of the target.

## Compatibility migration

- Zero-arg `--done` / `--abort` (and any multi-arg form) become a **hard usage error** (exit 2,
  `usage(scriptName, "--done requires a worktree name")`), matching `clean <id>` / `abandon <id>`
  already do. A cwd fallback is **not** an option — the correction forbids both optional IDs and
  cwd inference.
- No shim or deprecation window is required: `--done` is already non-destructive (the safe-done
  change shipped first, commit `64c7092`), so a misremembered zero-arg `--done` costs only a usage
  error, never data loss. The only muscle-memory cost is for `--abort`, which was already
  destructive-by-intent.
- The corrected forms are surfaced everywhere the old forms were advertised: `usageTemplate`,
  `cmdCreate` post-create hints, and the wrapper's post-opencode hints.

## Tests

Update `TestCodeWorkCommandHelperProcess` (`main_test.go:87-95`) to pass `args[1]` as the name for
`--done`/`--abort`. Then:

- Rewrite `TestLegacyDoneDoesNotDeleteAndAbortDiscards` (`:396-445`) subtests to run from the
  **main checkout** with an explicit `<task>`: assert `--done <task>` prints targeted guidance
  (correct name + path), exits 0, and leaves worktree + branch intact; assert `--abort <task>`
  removes the worktree and branch while the main checkout is untouched.
- `TestLegacyDoneRequiresTaskName` — `--done` with zero args (and with two args) exits 2 with a
  usage error; no mutation.
- `TestLegacyAbortRequiresTaskName` — `--abort` with zero args exits 2.
- `TestLegacyDoneUnknownTarget` — `--done <missing>` errors with a "not found" message.
- `TestLegacyAbortUnknownTarget` — `--abort <missing>` errors and does not `rm -rf` anything outside
  `.worktrees/` (no filesystem mutation).
- `TestLegacyAbortRejectsInvalidName` — `--abort ../evil`, `--abort /abs`, `--abort .` rejected by
  `ValidName` with no mutation.
- (Optional) `TestLegacyAbortRefusesCurrentWorktree` — `--abort <task>` run from inside that
  worktree is refused (if the defensive guard is adopted).

Regression gate: `go -C pkgs/nixos-scripts test ./...` (the `cmd/code-work` package exercises the
real dispatch via the helper subprocess against a real `git worktree` fixture).

## Approaches

1. **Mandatory-name harmonization (recommended)** — `--done <task>` / `--abort <task>`, resolved
   purely by name from an already-absolute main root, no chdir, zero-arg = usage error.
   - Pros: matches the managed surface and community pattern (wt-core/nils-git-cli/gw/wt/gwm);
     removes the last cwd-inference divergence; minimal diff (dispatch + two functions + text +
     hints + wrapper simplification); abort validation is structurally safe; the already-correct
     `resolveRepoRoot()` is reused as-is.
   - Cons: breaking change for zero-arg muscle memory (mitigated by usage errors + hints).
   - Effort: Low.

2. **Optional name with cwd fallback** — `--done [task]` / `--abort [task]`, infer from cwd when
   omitted.
   - Pros: non-breaking.
   - Cons: explicitly contradicts the correction ("no optional IDs", "no cwd inference"); keeps two
     resolution modes.
   - Effort: Low. **Rejected** — violates the fixed requirement.

3. **Retire the legacy surface and converge on managed `clean`/`abandon`** — remove `--done`/
   `--abort` entirely.
   - Pros: single surface.
   - Cons: adds lifecycle/state unification, which is out of scope ("no new lifecycle layers");
     loses the simple non-stateful create/enter flow.
   - Effort: Medium. **Rejected** — out of scope.

## Recommendation

Adopt **Approach 1** verbatim. Rewrite `cmdDone`/`cmdAbort` to take a required, validated task
name, resolve `.worktrees/<task>` from the existing absolute main root, drop the `pwd`/chdir
machinery, and reject zero-arg invocations with a usage error. Update `usageTemplate` and
`cmdCreate`/wrapper hints to the new `--done <task>`/`--abort <task>` forms; collapse the wrapper's
`--abort` case to a pass-through. Adopt the cheap defensive "refuse when the caller is inside the
target" guard as the single hardening that closes the "caller cwd disappears" hole, since that is
the only residual way `--abort <task>` could delete the caller's directory. Do **not** carry
forward the prior attempt's `~`-abbreviation root fix — it was a false positive (verified: the
porcelain root is already absolute). No state, permissions, profiles, managed-system coupling, or
lifecycle logic changes.

## Risks

- **Muscle-memory break** — zero-arg `--done`/`--abort` now error; mitigated because `--done` is
  already non-destructive (no data loss from a mistake) and hints name the corrected form.
- **"Caller cwd disappears" hole** — if a user runs `--abort <task>` from *inside* that worktree
  (old habit), remove-by-name still deletes their cwd; the optional defensive guard closes this.
- **`rm -rf` fallback safety** — currently gated only by cwd; with an explicit name it must be
  gated by `ValidName` + path containment + existence check, or a malicious name could `rm -rf` an
  unexpected path.
- **Branch deletion scope** — must delete the worktree's own HEAD branch, not an arbitrary
  caller-supplied branch.
- **Dead code drift** — `gitutil.InWorktrees`/`WorktreeName` may become unused; remove them or the
  change leaves misleading helpers behind.
- **`--prune` managed-lock coupling** — `cmdAbort`'s final `cmdPrune` acquires the managed lifecycle
  lock; pre-existing coupling, out of tight scope but worth flagging if "no managed system" is read
  strictly.
- **Test gap** — the name-addressed paths have no existing coverage; new tests must prove name
  resolution, usage errors, unknown-target, and invalid-name rejection.

## Ready for Proposal

Yes. Propose a change that (a) makes `--done <task>` and `--abort <task>` mandatory-name, (b)
resolves the worktree by name from the existing absolute main root (no root-resolution change
needed), (c) keeps `--done` non-destructive/guidance-only and `--abort` destructive-from-main-
checkout without chdir, (d) leaves `code-work <task>`/`--list`/`--prune` unchanged, (e) collapses
the wrapper's `--abort` case to a pass-through, and (f) adds focused tests for the name-addressed
lifecycle. Do not add state, commands, permissions, profiles, wrappers, managed-system coupling, or
lifecycle automation.
