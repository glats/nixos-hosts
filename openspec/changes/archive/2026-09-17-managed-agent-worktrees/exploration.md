## Exploration: managed-agent-worktrees

### Current State

This repository already has the right Git primitive but not a managed agent-dispatch policy. `code-work` creates a branch-attached worktree below `.worktrees/`, records its base branch, and exposes list, abort, done, and prune lifecycle operations. `nixos-build` resolves `.` as the flake when it runs beneath `.worktrees/`, so source evaluation and non-activating builds use the task's checkout. The worktree directory is ignored.

OpenCode now has native Git-worktree support: its worktree service creates an `opencode/<name>` branch under its global data directory, registers that directory as a project sandbox, bootstraps it asynchronously, and can run a configured startup command. That is useful product support, but it does not establish this repository's required branch naming, `.worktrees/` location, task lifecycle, Nix resource policy, or host-mutation denial. Current local OpenCode permissions also allow arbitrary shell commands and external directories, so a prompt or an alias alone cannot reserve deployment operations.

The immutable Nix store is shared safely, but a worktree does not isolate the Nix daemon, generations, profiles, activation side effects, ports, credentials, or the main checkout. Linux currently configures `max-jobs = 1` and `cores = 0`; Darwin configures `max-jobs = 1`. Therefore expensive local derivations queue rather than build concurrently, and a single admitted derivation may use all available cores. Nix documents that `max-jobs` and `cores` are independent and that both accept command-line overrides.

Git's linked worktrees supply independent directories, indexes, and attached branches, while sharing object storage and refs. Git already rejects checking out one branch in two worktrees. Its `lock` feature protects a worktree from pruning/removal; it is not a substitute for serializing lifecycle or integration operations.

### Affected Areas

- `pkgs/nixos-scripts/cmd/code-work/main.go` — existing cross-platform Go lifecycle is the smallest authoritative place to create, identify, list, and retire repository-local task worktrees.
- `pkgs/nixos-scripts/internal/gitutil/` — owns worktree parsing and names; a managed dispatcher needs task-to-branch validation and lifecycle metadata without duplicating Git plumbing.
- `pkgs/nixos-scripts/internal/reporoot/reporoot.go` — already makes Nix commands use the local flake inside `.worktrees/`.
- `pkgs/nixos-scripts/internal/nixbuild/nixbuild.go` — exposes switching, activation, input update, and non-activating build modes in one binary; agents must not receive its mutating modes.
- `shared/opencode/permissions.nix` and `shared/opencode/local-agent-overlays.json` — current broad Bash and external-directory permissions need a role-specific denial policy and dispatch instructions.
- `shared/opencode/agents.nix` — merges role-specific permissions and prompts, making it the declarative OpenCode integration point.
- `linux/system/base/nix.nix` and `darwin/system/nix.nix` — define the current one-build-at-a-time daemon resource posture that the agent policy must respect rather than raise globally.
- `shared/shell-aliases.nix` — current `nix-switch`, `nix-upgrade`, and `hms` conveniences demonstrate commands that must remain available only to the main-checkout integration gate.
- `.gitignore` — already ignores `.worktrees/`; no second worktree root is needed.

### Approaches

1. **Use OpenCode-native worktrees directly** — configure sessions to use OpenCode's worktree service and add permission denials around host mutation.
   - Pros: Uses a maintained OpenCode feature, includes project sandbox registration and startup hooks, and follows community one-writing-task/one-worktree practice.
   - Cons: Stores worktrees outside this repository, uses OpenCode-owned branch names and cleanup semantics, and cannot alone enforce this repository's integration gate or Nix admission policy.
   - Effort: Medium.

2. **Extend `code-work` into the managed dispatch boundary** — retain repository-local branch-attached worktrees and add a narrow OpenCode-facing command that creates or reuses a named task worktree, records task metadata, starts OpenCode with that directory, and applies an agent capability profile.
   - Pros: Reuses tested Go/Git behavior, keeps all source worktrees visible under `.worktrees/`, works on Linux and Darwin, and makes task, branch, lifecycle, and capability policy auditable in one place.
   - Cons: Requires a small integration layer instead of relying solely on upstream UI support; OpenCode-native workspace features remain optional rather than authoritative.
   - Effort: Medium.

3. **Add a Linux container or Bubblewrap boundary first** — run each task worktree through strong OS-level containment before implementing managed dispatch.
   - Pros: Best protection against arbitrary shell escape, home-directory reads, secrets, and shared host services.
   - Cons: Does not provide a portable Darwin baseline, requires deliberate Git metadata, Nix-daemon, network, credential, and MCP mount policy, and delays the already-approved workflow.
   - Effort: High.

### Recommendation

Choose Approach 2 as the default cross-platform change. `code-work` should become the sole task-worktree lifecycle authority, while an OpenCode-facing dispatcher calls it before every newly dispatched concurrent writing task. Each task receives a unique, branch-attached worktree under `.worktrees/managed/<task-id>` from the current approved base commit; planning, exploration, and read-only tasks stay in the main checkout. OpenCode native worktrees should be treated as compatible prior art and an optional future implementation detail, not the policy authority.

Define the following practical capabilities. Level 0 permits reads, edits inside the assigned worktree, Git status/diff/commit on the assigned branch, `nix fmt` scoped to that worktree, unit tests, and non-listening local commands. Level 1 additionally permits `nix eval`, `nix flake check --no-build`, and explicit `nix build` targets rooted in the assigned worktree. It must not invoke a rebuild wrapper whose default is `switch`. The dispatcher should run resource-intensive Nix commands with an agent cap such as `--max-jobs 1 --cores 1`; this is deliberately conservative and does not change host daemon settings. With the current host settings, simultaneous requests may still queue at the shared daemon, which is acceptable: correctness and responsiveness take precedence over throughput.

Level 2 is denied to dispatched agents: NixOS or Darwin rebuild/activation (`switch`, `boot`, `test`, `dry-activate`, `nh os`), Home Manager activation, generation or profile mutation, flake-lock/input updates, garbage collection, daemon configuration, `sudo`, host service control, and worktree deletion/branch cleanup. Denial must be implemented in the OpenCode role permission policy and in the dispatcher command surface, not merely stated in task prompts. A future Linux sandbox may strengthen this boundary but is not required for the portable baseline.

Only an explicit, serialized integration gate in the main checkout may promote completed task branches. That gate obtains a repository-level integration lock, checks the main checkout is clean and on its expected branch, integrates one approved branch at a time, runs the appropriate validation/build, and is the only path allowed to create or activate NixOS, Darwin, or Home Manager generations. It must release the lock on every failure path and leave failed branches/worktrees intact for diagnosis. This is safer than granting agents an activation lock: it prevents an unreviewed agent from mutating the host even when no other agent is active.

Managed worktrees should be created with a unique task ID, recorded base revision and branch, and a lifecycle state of `active`, `ready-for-integration`, `integrated`, or `abandoned`. Creation, transition, cleanup, and `git worktree prune` require a short repository lifecycle lock; use a portable Go-managed lock rather than relying on Linux-only `flock`. A worktree may be Git-locked while active to prevent accidental removal/pruning, then unlocked only by the lifecycle authority. Cleanup occurs after successful serialized integration or explicit abandonment; it never auto-merges, auto-pushes, or force-deletes an unreviewed branch.

### Risks

- Worktrees prevent filesystem collisions but not merge conflicts, shared ports, Nix daemon contention, credentials, or arbitrary host commands; independent tasks and command denials remain necessary.
- `max-jobs = 1` protects host memory but makes concurrent build requests queue, while `cores = 0` lets the admitted build consume all cores; the proposed agent cap needs empirical validation on Linux and Darwin before becoming a performance promise.
- OpenCode's native creation bootstraps asynchronously, so it must not be used as a readiness signal unless the dispatcher observes its ready/failure event; the repository-local command can instead complete Git creation before task launch.
- Existing `code-work --done` expects a pushed branch and deletes it, which conflicts with local serialized integration; the managed lifecycle must be separate from or revise that completion behavior.
- Permission rules reduce accidental execution but do not constitute OS containment against a broadly privileged shell. Bubblewrap or equivalent remains a later opt-in security enhancement.
- A failed or interrupted lifecycle can leave stale metadata; the authority must expose inspect and recovery paths and use `git worktree remove` followed by controlled prune rather than deleting directories directly.

### Ready for Proposal

Yes — propose a cross-platform managed dispatcher built on `code-work`, an agent-specific Level 0/Level 1 permission profile, and a main-checkout-only serialized integration gate. Keep native OpenCode worktrees optional and defer OS-level sandboxing to a separately approved hardening change.
