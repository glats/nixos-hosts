# Exploration: simplify-worktree-cli

## Purpose

The just-shipped `managed-agent-worktrees` CLI forces the operator to repeat the task identifier and a verbose verb on every call (`code-work managed start <id>`, `managed check <id> <check> [target]`, `managed ready <id>`, `managed integrate <id> --validate …`, `managed cleanup <id>`). The goal is a leaner surface where cwd carries the task context inside the worktree and the human main-checkout operations address a task by ID.

## Current State

`code-work` is a Go command with two surfaces:

- **Legacy lifecycle** (unchanged by this work): `code-work <name>` (create), `--done`, `--abort`, `--list`, `--prune`.
- **Managed namespace** (shipped 2026-09-17, archived + verified PASS): `managed start|ready|check|integrate|inspect|cleanup|abandon|recover-lock`.

Managed state lives under the Git common directory as `.git/managed-worktrees/<id>.json` (`managedworktree.Record`), guarded by a portable `mkdir` lock (`AcquireLock`) and a `git worktree lock` on active worktrees. The state machine is `active → ready-for-integration → integrated`, or `active|ready-for-integration → abandoned` (`Transition`). Task identity is `[a-z0-9][a-z0-9-]{0,62}` mapping to branch `managed/<id>` and path `.worktrees/managed/<id>` (`ValidTaskID`, `BranchFor`, `PathFor`).

Safety-critical behavior that must be preserved:

- `managed check` admit only `fmt`, `eval <target>`, `flake-check`, `build <target>`; reject options and `switch`/`home-manager`/arbitrary Nix (`validateManagedCheckArgs`).
- `managed integrate` is the sole host-mutation gate: clean attached main checkout only (`validateManagedSelector` + `managedClean`), `ready` state + branch match, non-fast-forward merge, non-activating validation/build, rollback via `git reset --merge ORIG_HEAD` on failure, optional explicit `--activate system|home`.
- The `managed-writing-task` agent is default-deny for Bash and external directories; its Bash allowlist contains exactly `"code-work managed check *": "allow"` (`shared/opencode/local-agent-overlays.json:70`) and its prompt says "use `code-work managed check`" (`shared/opencode/agents.nix:159`).

The Linux shell wrapper `code-work()` (`linux/home/shell.nix:69-100`) routes `managed` verbatim but otherwise treats the first argument as a legacy worktree **name to create**. Darwin has no wrapper (no `darwin/` code-work references); the Go binary is cross-platform.

## Research (external evidence)

- **Context7**: monthly quota exceeded; OpenCode doc lookup fell back to web/Exa/GitHub. Confirmed from `opencode.ai/docs/cli/`: `opencode --agent <name> [dir]` launches an agent in a directory; the current `launchManagedAgent` (`opencode --agent managed-writing-task <path>`) is already the correct invocation and needs no change.
- **Prior art, cwd inference**: `workon` (Rust) classifies a CLI reference as `Cwd | Path | Token` with `None ⇒ cwd`; `git-wt` (k1LoW) accepts `<branch|worktree|path>`; `wos` and `cline` use a `--cwd` global flag before the subcommand. The cwd-inference model is well established.
- **Prior art, rename vs alias**: `gh-aw` "breaking-cli-rules" classifies command renaming as breaking and mandates "add an alias instead of renaming" + a stderr deprecation warning for ≥1 minor release; `rsigma` ships renamed commands as *hidden* aliases with a stderr hint then removes them; `pm-cli` distinguishes "permanent hot-path aliases" from "deprecated hidden compatibility shims"; `gwm-cli` documents a full SemVer deprecation process; `git-worktree-tools` refactors four legacy binaries into one `wt` entry point with deprecated aliases (`newpr`→`wt new`, etc.).

## Affected Areas

- `pkgs/nixos-scripts/cmd/code-work/main.go` — top-level dispatch (`main`) and `usageTemplate`; must route the new verbs and update help.
- `pkgs/nixos-scripts/cmd/code-work/managed.go` — `managedCommand` switch holds every verb; rename `start→new`, `integrate→merge`, `cleanup→clean`, `inspect→status`; make `check`/`ready`/`status` infer `<id>` from cwd; add a cwd→task-id resolver.
- `pkgs/nixos-scripts/internal/managedworktree/managedworktree.go` — add `ResolveTaskID(root, cwd)` (record-path match) if not kept in the cmd package; `PathFor`/`Record` are the source of truth.
- `pkgs/nixos-scripts/cmd/code-work/main_test.go` — every managed test calls the old verbs; rewrite for the new surface and add cwd-inference coverage.
- `shared/opencode/local-agent-overlays.json` — Bash allowlist `"code-work managed check *": "allow"` must become `"code-work check *"` (keep both only during a shim window) or the agent loses its only check path under default-deny Bash.
- `shared/opencode/agents.nix` — prompt text `code-work managed check` must match the new surface.
- `linux/home/shell.nix` — the `code-work()` wrapper's `*)` branch treats any unknown first token as a legacy create-name; `code-work new foo` would currently try to create a worktree named `new`. Must whitelist the new verbs.
- `docs/managed-agent-worktrees.md` — command contract; must reflect the new verbs.
- `openspec/specs/managed-agent-worktrees/spec.md` — capability-level (no literal verbs in requirements); likely no delta required, but verify scenario wording still maps.

## Approaches

### 1. Backward-compatible aliases

Keep `code-work managed start|check|ready|integrate|cleanup|inspect` working as **hidden** shims that forward to the new top-level verbs and emit one stderr deprecation hint; add canonical `new`, `check`, `ready`, `status`, `merge`, `clean`.

- Pros: zero breakage for anything already invoking `managed …`; matches the "alias instead of rename + stderr warning" consensus; shim is nearly free because `managedCommand` already centralizes dispatch.
- Cons: leaves a second surface to document, test, and later remove; the "repeats too many arguments" pain is only solved if callers migrate, so the shim does not itself reduce noise.
- Effort: Low-Medium.

### 2. Clean rename

Remove the `managed` namespace entirely and ship only the top-level verbs.

- Pros: single canonical surface; help text and agent prompt are unambiguous; no dead compatibility code; the change shipped ~6 days ago with exactly one internal consumer (the agent prompt/permission), so there is effectively no external automation to break.
- Cons: any muscle memory or hand-written `managed …` invocations (and the archived docs) stop working immediately; a large delta in one commit.
- Effort: Low (the verb count is small and collocated).

### 3. (Sub-decision) cwd→task-id resolution mechanism

- **Record-path match (recommended):** iterate `.json` records in the common dir and return the id whose `record.Path` equals cwd (or is a path ancestor if subdir support is desired). Reuses the exact path the record already asserts, so it cannot misclassify a legacy worktree named `managed`/`managed-*`.
- **String-prefix match (rejected):** `gitutil.InWorktrees(cwd, <root>/.worktrees/managed)` + split on `/` inherits the loose plain-prefix behavior of the bash original and would misclassify any legacy worktree whose name starts with `managed`.

## Recommendation

Adopt **Approach 2 (clean rename) with a short, hidden `managed` forwarding shim** kept for at most one release — effectively Approach 1's shim bolted onto the clean surface. Rationale: the essential win is **cwd inference**, which is orthogonal to naming; the verb rename is cosmetic but desired, and because the feature shipped days ago with a single internal consumer, the compatibility surface is trivially small. A hidden shim (stderr hint, absent from `--help`) costs little and removes any doubt, and it can be deleted in the follow-up change. Resolve the task id by **record-path match**, never by string prefix.

Concrete target surface:

```
code-work new <task> [--base <branch>]          # clean main checkout; create + launch agent
code-work check [fmt|flake-check|eval <t>|build <t>]   # worktree cwd; infer task
code-work ready                                  # worktree cwd; infer task
code-work status                                  # worktree cwd = own task; main checkout = all tasks
code-work merge <task> [--validate <check|build>] [--activate <system|home>]   # main checkout, by ID
code-work clean <task>                            # main checkout, by ID (integrated|abandoned only)
code-work abandon <task> | recover-lock           # unchanged semantics, by ID
```

`check`/`ready`/`status` MUST error with "not inside a managed worktree" when run from the main checkout or a legacy worktree (no silent no-op). `status` is a read-only enrichment of `inspect` (state, branch, path, base, dirty flag; no lock required).

Mandatory same-change wiring (otherwise the feature silently regresses or breaks the agent):

1. `local-agent-overlays.json` allowlist → `"code-work check *": "allow"` (keep the `managed` form only while the shim exists).
2. `agents.nix` prompt → reference `code-work check`.
3. `linux/home/shell.nix` wrapper → whitelist `new|check|ready|status|merge|clean|abandon|recover-lock` (and `managed` during the shim) to `command code-work "$@"`, so they bypass the legacy `*)` create branch.
4. Preserve the lifecycle lock, `git worktree lock`, allowlist, state machine, and integration gate exactly as-is; only the arg surface changes.

## Compatibility / Migration Risks

- **Shell wrapper shadow bug (highest):** with the current `*)` branch, `code-work new foo` creates a legacy worktree named `new` and ignores `foo`. The wrapper must be updated in the same commit as the Go change.
- **Agent permission drift:** default-deny Bash + a stale `"code-work managed check *"` pattern means the renamed verb is denied outright — the agent's only allowlisted check stops working.
- **cwd-inference ambiguity:** a legacy worktree named `managed` or `managed-*` under `.worktrees/` must not resolve as a managed task; record-path matching prevents this, string prefix does not.
- **Subdirectory invocation:** `code-work ready` from a subdir of the worktree is ambiguous unless resolution allows ancestor paths. Recommend exact `record.Path == cwd` first (matches today's `managed ready`), and treat subdir support as an explicit follow-up.
- **Legacy name collision at top level:** `code-work check` could shadow a legacy worktree literally named `check`; document the new verbs as reserved.
- **Doc/help drift:** `usageTemplate`, `docs/managed-agent-worktrees.md`, and the archived change docs must not contradict the shipped surface; the archived artifacts stay as audit trail.
- **Exit codes:** keep `0`/`1`/`2` semantics (`2` for usage) so any automation keying off them is stable.

## Exact Tests

**Keep (unchanged behavior, rewritten invocations):**
- `managedworktree_test.go` — `TestTaskIDAndPaths`, `TestMetadataTransitionsAndPersistence`, `TestPortableLockSerializesAndReleases`, `TestConcurrentLockEventuallyAllowsOneAtATime` (identity/state/lock logic is untouched).
- `main_test.go` `TestManagedSelectorAdmission` (`validateManagedCheckArgs`), `TestManagedRepositorySelector` (`validateManagedSelector`), `TestManagedCommitState` — unchanged.
- `main_test.go` `TestCodeWorkCommandHelperProcess` — extend the helper switch to the new verbs and to cwd-inference.

**Update to new surface:**
- `TestManagedCommandDispatchAndConflicts` — `new alpha` / `new beta`, reuse, conflict.
- `TestManagedCommandCheckAllowlistAndDenial` — `check switch` denied before execution; `check eval .#test` admitted, both run from the worktree cwd with no `<id>`.
- `TestManagedCommandReadyIntegrationAndFailureRetention` — `ready` (cwd, no id) → `merge success --validate check` → state `integrated`; failed validation retains `ready` + worktree.
- `TestManagedCommandRejectsDirtyNonReadyAndBranchMismatch` — `merge` on dirty main, non-ready, and branch-mismatch rejected.
- `TestLegacyPruneUsesManagedLifecycleLock` — `ready` (cwd) + `prune` contend on the shared lock.

**New:**
- `TestResolveTaskIDFromCwd` — exact worktree cwd resolves the id; main checkout and legacy worktree (including one named `managed`/`managed-foo`) do not.
- `TestNewRequiresCleanAttachedMain` — `new` rejects dirty/detached main checkout (reuse `managedClean`/`validateManagedSelector`).
- `TestStatusReadOnly` — `status` from worktree prints own task; from main prints all tasks; acquires no lock.
- `TestDeprecatedManagedShim` (if shim kept) — `managed start x` forwards, prints a stderr hint, exits `0`.
- `TestShellWrapperRoutesNewVerbs` (Nix-side) — `code-work new|check|ready|status|merge|clean` do not fall into the legacy create branch.

## Ready for Proposal

Yes. Propose a single cross-platform change: (a) top-level verbs `new/check/ready/status/merge/clean` with cwd inference inside the worktree and by-ID from main, (b) an optional short hidden `managed` forwarding shim, (c) the three mandatory wiring edits (permission pattern, agent prompt, shell wrapper), all preserving the lifecycle lock, worktree lock, allowlist, state machine, and the human integration/activation gate. Host scope is all four hosts for the Go/permission/prompt change and Linux-only for the shell wrapper.
