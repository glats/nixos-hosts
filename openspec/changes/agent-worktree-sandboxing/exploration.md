## Exploration: agent-worktree-sandboxing

### Current State
This repository already uses linked worktrees under `<repo>/.worktrees/`: the directory is ignored, `code-work` creates a branch-local worktree and marker, and the zsh wrapper changes into it before starting OpenCode. `nixos-build` and its repository resolver deliberately select `.` when invoked from that directory, so host evaluation and builds use the worktree's flake. The active checkout currently has multiple linked worktrees; Git 2.54.0 and Nix 2.34.8 are installed.

`nix develop -c <command>` is feasible in every worktree: this flake exports a Go-only default dev shell, and Nix evaluates each worktree's flake from its current directory. Concurrent `nix flake check --no-build` evaluations and Nix builds are safe with respect to the shared store/daemon, but they are not currently parallel builds: Linux sets `max-jobs = 1` and `cores = 0`, while Darwin also sets `max-jobs = 1`. That intentionally avoids OOM, so simultaneous agents queue expensive derivations rather than corrupting the store. Nix build sandboxing applies to derivation builders, not to arbitrary processes started by `nix develop -c` or OpenCode.

The current worktree mechanism isolates files and Git indexes, not host access, processes, ports, caches, or agent state. OpenCode permissions allow arbitrary external directories and shell commands except selected sensitive/destructive operations; its user shell also supplies provider credentials. Any command-level sandbox must therefore start with an explicit environment allow-list and only mount the worktree, its required Git metadata, the Nix store/socket, and selected runtime directories. Nix upstream issue #6073 remains open for clean detached worktrees updating flake inputs; do not run `nix flake lock --update-input` concurrently from agent worktrees.

### Affected Areas
- `.gitignore` — already excludes `.worktrees/`, the established disposable-worktree location.
- `.worktree-base` — records the base branch used by the existing lifecycle.
- `pkgs/nixos-scripts/cmd/code-work/main.go` — creates, lists, and destroys named worktrees, but does not establish a development shell or containment boundary.
- `linux/home/shell.nix` — launches OpenCode after entering a created worktree; it is the natural narrow integration point for an agent-worktree command.
- `pkgs/nixos-scripts/internal/reporoot/reporoot.go` and `internal/nixbuild/nixbuild.go` — make rebuild tooling worktree-aware by choosing the local flake path.
- `flake.nix` — provides the default Go `devShell` on Linux and Darwin; no agent sandbox tooling is declared.
- `linux/system/base/nix.nix` and `darwin/system/nix.nix` — bound Nix build concurrency to one job; Linux also has build sandboxing enabled at runtime.
- `shared/opencode.nix` and `shared/opencode/permissions.nix` — OpenCode has broad host command/directory access and a credential-bearing shell, so permission rules alone are not a containment boundary.
- `linux/system/virtualisation/docker.nix` — Docker is available on Linux hosts that import this module, but it is not a portable default and should not be the first worktree solution.

### Approaches
1. **Native worktree plus `nix develop`** — use the existing `code-work` lifecycle, then run checks as `nix develop -c go -C pkgs/nixos-scripts test ./...` or `nix flake check --no-build` from the worktree.
   - Pros: Reuses tested repository behavior, works on Linux and macOS, keeps the shared Nix store/cache efficient, and supports parallel file edits and evaluations immediately.
   - Cons: Does not restrict the agent's host access; expensive builds serialize at `max-jobs = 1`; global ports, user caches, and OpenCode state can still collide.
   - Effort: Low.

2. **Native worktrees with deliberately scoped state** — retain the shared Nix daemon/store, but give each agent a worktree-derived XDG state/cache directory where the invoked tools support it and allocate distinct test ports/runtime paths.
   - Pros: Reduces cross-agent logs, lock files, and runtime-state collisions without duplicating Nix closures; preserves current Linux/Darwin portability.
   - Cons: `NIX_PATH` is unnecessary for this flake-based workflow, and indiscriminate XDG/Nix cache isolation wastes disk or breaks tools that expect shared credentials/state; it is not security containment.
   - Effort: Medium.

3. **Linux command sandbox around a native worktree** — run the agent through Bubblewrap with a minimal mount and environment policy; reserve systemd-nspawn or a Docker/NixOS container for a later high-isolation profile.
   - Pros: Can prevent access to the home directory, decrypted secret paths, other worktrees, and host network/process namespaces while still exposing the assigned worktree and Nix dependencies; Bubblewrap is an unprivileged Nix package.
   - Cons: The linked worktree's `.git` file requires visibility of the main repository's `.git/worktrees` metadata; Nix daemon access, network policy, Git remotes, MCP tools, and credential injection need explicit design. systemd-nspawn/Docker add privileged/container lifecycle complexity and are Linux-only, so neither fits macm5 as a universal baseline.
   - Effort: High.

### Recommendation
Start with Approach 1 as the supported cross-platform baseline and make its command contract explicit: `code-work <branch>`, enter `<repo>/.worktrees/<branch>`, run `nix develop -c <test command>` or cwd-local `nix flake check --no-build`, and prohibit lock-file updates, activation/switch commands, and shared-service mutation from agents. It is feasible now; Nix safely shares the daemon/store, while the configured one-job limit protects host memory at the cost of build parallelism.

Propose Approach 2 only for measured collisions, keeping the Nix store and standard flake resolution shared; do not add `NIX_PATH` isolation. Treat Approach 3 as an opt-in Linux security profile after defining whether agents need network, Git push, MCP access, and credentials. If selected, prefer Bubblewrap over nspawn/Docker and enforce a clean environment so inherited credential variables do not bypass filesystem isolation. Nix's build sandbox is complementary but cannot substitute for that command sandbox.

### Risks
- Parallel worktrees share Git object storage and Nix daemon state; worktree creation/removal, branch deletion, lock-file updates, garbage collection, and activation must remain centrally serialized.
- The current Nix job limit prevents parallel expensive builds; raising it to satisfy agent throughput risks the OOM/laptop-freeze failure mode documented in `linux/system/base/nix.nix`.
- A Bubblewrap policy that hides the main checkout breaks linked-worktree Git metadata; a policy that exposes the whole home directory defeats containment.
- Isolating XDG state can separate agent sessions but may also hide required authentication or duplicate caches; it needs tool-by-tool validation.
- Strong containment is Linux-specific unless a separate macOS design is accepted; Nix build sandboxing does not confine OpenCode or `nix develop` commands.
- Clean detached worktrees have an upstream flake-input update failure (NixOS/nix#6073); keep agent worktrees branch-attached and leave input updates to the main checkout.

### Ready for Proposal
Yes — propose a small cross-platform worktree execution contract built on the existing `code-work` and worktree-aware Nix tooling, with a separate, opt-in Linux Bubblewrap security profile only after an explicit credential, network, and Git-metadata mount policy is approved.
