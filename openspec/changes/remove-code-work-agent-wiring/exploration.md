# Exploration: remove-code-work-agent-wiring

## Purpose

Decouple the OpenCode agent configuration from the `code-work` CLI by removing only the `code-work` references from the `managed-writing-task` agent profile (one prompt instruction and two Bash allowlist entries) and the three `wt-*` zsh aliases — while preserving the `code-work` binary, its shell wrapper, docs, worktrees, locks, Go code, and all unrelated behavior. This follows the user's correction that agent permissions must not be inferred without approval: **no replacement permission is introduced and no new agent profile is required.**

## Current State

`code-work` is a Go command (`pkgs/nixos-scripts/cmd/code-work/`) with two surfaces: the legacy lifecycle (`<name>`, `--done`, `--abort`, `--list`, `--prune`) and the managed namespace just simplified by `simplify-worktree-cli` into top-level verbs (`new/check/ready/status/merge/clean/abandon/recover-lock`). The `simplify-worktree-cli` change (commit `807e5ed`, verified, still active and un-archived) also re-wired three agent-facing touch points so the agent stays consistent with the renamed surface. Those are exactly the touch points this change removes:

1. `shared/opencode/agents.nix:159` — the inline `managedWritingAgent` prompt contains the instruction `and use `code-work check` for fmt, eval, flake-check, or scoped build.`
2. `shared/opencode/local-agent-overlays.json:70-71` — the `permissionOverlays.named.managed-writing-task.bash` allowlist contains `"code-work check *": "allow"` and `"code-work managed check *": "allow"` under an otherwise default-deny Bash map.
3. `linux/home/shell.nix:45-47` — three zsh aliases `wt-done`/`wt-abort`/`wt-list` that forward to `code-work --done/--abort/--list`.

The `managed-writing-task` profile itself is defined in `agents.nix` (`managedWritingAgent`, lines 153-164) and consumed in two places: `agents.nix:163` (its `permission` key) and `agents.nix:168` (injection into `defaultAgents`), plus `pkgs/nixos-scripts/cmd/code-work/managed.go:216` which launches it via `opencode --agent managed-writing-task <path>`. The profile remains in use after decoupling.

The static default permission layer `shared/opencode/permissions.nix` has **no** `code-work` reference — the `code-work` Bash grants live solely in `local-agent-overlays.json`. `darwin/home/shell.nix` has no `code-work` or `wt-*` reference; the aliases and wrapper are Linux-only.

## Research (external evidence)

- **Context7**: monthly quota exceeded; OpenCode doc lookup unavailable this session. Findings below rest on GitHub code search and Exa instead, consistent with how `simplify-worktree-cli` handled the same outage.
- **GitHub** (`get_me` → `glats` / Juan Cuzmar, id `4707766`; then code search across public repos): OpenCode's current permission model is `permission: { bash|read|edit|webfetch|...: allow|ask|deny }` with pattern-scoped Bash rules and `deny > ask > allow` precedence; the `tools` field is deprecated in favor of `permission`. This matches the repo's own prior art — `shared/opencode/agents.nix` already strips deprecated `tools`, and the archived `2026-09-17-managed-agent-worktrees` change established the default-deny `managed-writing-task` boundary as the canonical pattern for a scoped writing agent.
- **Exa** (least-privilege guidance — Okta "least privilege for AI agents", Safeguard.sh "least-privilege tool scoping", agentpatterns.tech "tool permissions", TanStack sandbox policy): the consistent recommendation is deny-by-default with explicit allowlists, "prompts do not enforce permissions; code does", and — most relevant to this change — **do not infer or silently widen grants; a well-intentioned loosened `Bash` pattern widens blast radius**. Removing an unused grant is the safe direction; adding a replacement grant requires explicit approval. This directly supports the user's correction.

## Affected Areas

- `shared/opencode/agents.nix` — the `managedWritingAgent` prompt (line 159) is the only `code-work` instruction; reword to drop the check sentence. The profile definition and its injection into `defaultAgents` stay untouched.
- `shared/opencode/local-agent-overlays.json` — remove the two `code-work` Bash allowlist entries (lines 70-71) from `managed-writing-task`; the remaining `git status/diff/add/commit` and `go test` / `go -C test` entries stay. The trailing comma after `"go -C * test *": "allow"` must be removed.
- `linux/home/shell.nix` — remove the three `wt-*` aliases (lines 45-47). The `code-work()` wrapper (`initContent`, lines 69-100) is **preserved** per instruction.
- `pkgs/nixos-scripts/**` (Go code), `docs/managed-agent-worktrees.md`, `shared/opencode/permissions.nix` — **untouched** (preserved).

Host scope: `shared/opencode/*` is Home-Manager wiring on all four hosts (rog, thinkcentre, t14, macm5); `linux/home/shell.nix` is Linux-only (imported by `linux/home/shared-modules.nix`, consumed by rog, thinkcentre, t14).

## Approaches

### Decision: Is a new agent profile required? — No.

The `managed-writing-task` profile already exists and is not removed. Decoupling only deletes the two `code-work`-specific elements *inside* that existing profile (one prompt line + two Bash allowlist entries). After the change the profile still edits, commits branch-local Git state, and runs Go tests, and `code-work new` still launches it. No new profile is created and no profile is deleted.

1. **Pure decoupling (recommended)** — remove the three listed items and nothing else.
   - Pros: exactly the user's minimal scope; no inferred permissions; profile stays; `code-work` binary/wrapper/docs/Go stay; trivially reversible.
   - Cons: the agent loses its only `code-work check` path, so its "named check" capability (fmt/eval/flake-check/build) disappears until a follow-up re-grants it *with explicit approval* (see Risks).
   - Effort: Low.

2. **Decoupling + re-grant checks via direct `nix` allowlist** (e.g. `nix fmt *`, `nix flake check *`, …) — rejected.
   - Pros: preserves the agent's check capability without `code-work`.
   - Cons: this *infers* new agent Bash permissions, which the user's correction explicitly forbids; expands scope beyond the three named files.
   - Effort: Medium.

3. **Remove the `managed-writing-task` agent entirely and add a new generic profile** — rejected.
   - Pros: removes all worktree coupling at once.
   - Cons: contradicts "minimal decoupling only"; would orphan `code-work`'s `opencode --agent managed-writing-task` launch and require a new agent profile, which the user expects is unnecessary.
   - Effort: High.

## Recommendation

Adopt **Approach 1 (pure decoupling)**. Delete only: the `code-work check` sentence in `agents.nix`; the two `code-work` Bash allowlist entries in `local-agent-overlays.json`; and the three `wt-*` aliases in `shell.nix`. No new agent profile is required — the existing `managed-writing-task` profile is retained, minus its `code-work` coupling. Do **not** introduce any replacement Bash grant; a re-grant is a separate, explicitly-approved decision, not part of this change.

## Risks

- **Spec consistency (highest).** `openspec/specs/managed-agent-worktrees/spec.md` "Managed Agent Capability Boundary" requires the managed writing agent to allow "the named `fmt`, `eval`, `flake-check`, and scoped `build` checks", and `openspec/specs/gentle-ai-declarative-runtime/spec.md` "Managed Writing-Agent Profile" requires "allowlisted local checks". After decoupling the agent cannot run those checks, so both requirements become unsatisfied by the generated config. The active `simplify-worktree-cli` delta spec (`specs/managed-agent-worktrees/spec.md:59`) even binds the checks "via the canonical `code-work check` command". A follow-up spec delta (MODIFIED/REMOVED of the check-binding clause) is likely required — surface for the proposal/spec phase, not resolved here.
- **Inter-change ordering.** `simplify-worktree-cli` is still un-archived; if it is archived before a spec reconciliation, its delta would merge a "code-work check via agent" requirement that no longer holds. Sequence or reconcile explicitly.
- **Trailing-comma/JSON validity.** Removing the last two entries of the `managed-writing-task.bash` map leaves a trailing comma after `"go -C * test *": "allow"`; malformed JSON fails at `builtins.fromJSON` in `agents.nix`, which `nix flake check` will catch.
- **Agent capability regression.** The agent keeps edit/git/test but loses fmt/eval/flake-check/build. This is intended by the decoupling but should be acknowledged explicitly in the proposal so it is not mistaken for an accident.
- **Docs drift (low).** `docs/managed-agent-worktrees.md:13` still describes the agent's "four scoped checks"; it is out of scope for this change but will drift from the decoupled reality.

## Exact Verification

1. `nix fmt -- shared/opencode/agents.nix linux/home/shell.nix` (JSON is not Nix-formatted; validate separately below).
2. `nix flake check --no-build` — shared change; also proves `local-agent-overlays.json` still parses via `builtins.fromJSON`.
3. `nix eval .#homeConfigurations.rog.activationPackage.drvPath` — Home Manager wiring (agents.nix + local-agent-overlays.json).
4. `nix eval .#homeConfigurations.t14.activationPackage.drvPath` and `.#homeConfigurations.thinkcentre.activationPackage.drvPath` — Linux Home Manager hosts (shell.nix aliases).
5. `nix eval .#darwinConfigurations.macm5.config.system.build.toplevel.drvPath` — Darwin Home Manager wiring for the shared files.
6. `nix eval --json .#homeConfigurations.rog.config.home.opencode.agents.managed-writing-task.permission` — assert the profile still exists, `bash` has **no** `code-work` key, and `git status*` / `go test *` entries remain.
7. `nix eval --json .#homeConfigurations.rog.config.home.opencode.agents.managed-writing-task.prompt` — assert the string contains no `code-work`.
8. Grep gates: `code-work` absent from `shared/opencode/agents.nix` and `shared/opencode/local-agent-overlays.json`; `wt-done|wt-abort|wt-list` absent from `linux/home/shell.nix`; `code-work()` wrapper still present in `linux/home/shell.nix`.
9. No Go change ⇒ `go -C pkgs/nixos-scripts test ./...` is **not** required (optional no-op sanity check only).

## Ready for Proposal

Yes. Propose a single minimal decoupling across three files (`shared/opencode/agents.nix`, `shared/opencode/local-agent-overlays.json`, `linux/home/shell.nix`) with no new agent profile and no replacement permission. The proposal must explicitly state the accepted consequence — the `managed-writing-task` agent loses its `code-work check` capability — and record the spec-reconciliation question (`managed-agent-worktrees` + `gentle-ai-declarative-runtime` "allowlisted local checks" requirements) as a follow-up delta, not a silent gap.
