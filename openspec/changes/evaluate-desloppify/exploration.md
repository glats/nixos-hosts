## Exploration: evaluate-desloppify

### Current State

This is a declaratively deployed, multi-host OpenCode and Claude Code harness. `shared/ai-assets.nix` supplies one ordered skill union to both clients, and their activation code copies it into each mutable runtime directory. Gentle AI owns SDD phases and review policy; Ponytail supplies an explicitly minimal/YAGNI cleanup lens; Cavecrew is an optional delegation/context-saving lens; and RTK only filters shell output, with telemetry disabled and local SQLite measurements. The checkout is currently on `master` and diverged from `origin/master` (ahead 6, behind 5), with unrelated OpenSpec work present, so a tool that insists on a dedicated cleanup branch is incompatible with the current direct-master worktree unless isolated first.

Desloppify v1.0 is a Python 3.11+ stateful code-health CLI and agent harness, not a Nix tool or a passive linter. It scans source and records state under `.desloppify/`; it can run external analyzers and Git/OpenCode/agent subprocesses; its `autofix` command can change source after a dry-run preview. Its bundled workflow takes over the agent loop (`scan → plan → execute → rescan`), requires a dedicated Git branch, directs large refactors, and can install an agent skill. The OpenCode runner can spawn parallel `opencode run --format json` review processes or attach to an `opencode serve` server. Go is a full-depth language plugin, but Nix is not listed as a supported full or generic language.

`desloppify update-skill` is expressly out of bounds: source shows it downloads the current skill and optional overlay from the upstream `main` branch over HTTPS, then writes or replaces a marked section in the project agent file. That mutable, unpinned instruction overlay would conflict with this repository's Nix-owned skill union and with Gentle AI's SDD authority. `setup` is also unsuitable because it installs global skill files. A source search found no product telemetry client, but absence of telemetry code is not a complete egress guarantee: `update-skill` downloads upstream content, OpenCode/Claude runners transmit reviewed code through those configured agents, and scanners invoke installed local tools. No self-update mechanism was found beyond explicit package installation and `update-skill`.

The supplied gist is an unrelated, third-party Go cleanup checklist, not an official Desloppify asset, fork, or wrapper. Its useful boundary-validation, concrete-type, and anti-abstraction guidance overlaps strongly with Ponytail. Its imperative wording (“aggressively simplify”) and many heuristic removal suggestions are not safe as standing instructions: nil checks, error handling, interfaces, pointers, and abstraction layers require repository-specific evidence. It MUST NOT be copied into `AGENTS.md` or a globally activated skill.

Upstream is active and has a v1.0 release (2026-05-13), CI with lint/type/architecture/test/package-smoke jobs, and a reported 6,836 tests. However, open v1.0 issues demonstrate material false-positive/state risks: excluded paths can reach Bandit and retain scored findings (#748); import graph failures can create extensive orphan/coverage backlogs (#665, #705, #715); and strict-score state handling can penalize scanner-confirmed fixes (#627). Independent Exa research returned primarily official repository/docs rather than independent experience reports, so it provides no independent security or maturity validation.

Nix package searches returned no `desloppify` attribute in nixpkgs/NixHub and no NixHub version history. The MCP cannot query this repository's exact pinned `nixos-26.05`, so a future derivation would require an explicit source pin, fixed dependency hashes, and Linux plus x86_64-darwin builds; no package availability is inferred.

### Affected Areas

- `shared/ai-assets.nix` — canonical ordered union for declarative shared skills; the upstream mutable overlay conflicts with it.
- `shared/opencode/runtime-config.nix` — deploys skill files and already manages OpenCode runtime/plugin lifecycle; Desloppify's parallel runner would create nested OpenCode processes outside this ownership model.
- `shared/claude-code.nix` — deploys the same union to Claude Code; upstream global/project skill installation would bypass it.
- `shared/opencode-profile.nix`, `shared/opencode/plugins.nix` — current Gentle AI, Engram, and RTK plugins define the managed OpenCode harness boundary.
- `docs/rtk-pilot.md`, `openspec/specs/harness-token-efficiency/spec.md` — RTK is a private, fail-open shell-output filter, not a code-quality or agent-workflow controller.
- `pkgs/local-ai-assets/default.nix`, `pkgs/archify-skill/default.nix` — established pattern for a reviewed, source-pinned, cross-platform asset; no comparable Desloppify package exists yet.
- `pkgs/nixos-scripts/` — coherent Go-only operational module and the only plausible future narrow scan target; no Bash wrapper is permissible.

### Approaches

1. **Manual, read-only sandbox trial on one coherent Go module** — with explicit user approval, use a disposable worktree or copy of `pkgs/nixos-scripts`, a version-pinned isolated Python environment, and only a scoped scan/report. Predefine excludes for generated/vendor/worktree/state paths; do not run `update-skill`, `setup`, `review --run-batches`, `plan triage --run-stages`, `next`, `resolve`, or `autofix`.
   - Pros: tests real Go detector signal and local-state behavior without changing source, global agent instructions, Nix configuration, or the direct-master checkout.
   - Cons: requires a separately pinned packaging experiment; scan can still read every in-scope source file and create disposable `.desloppify` state; results need manual false-positive triage.
   - Effort: Low.

2. **Declarative package plus opt-in, local review skill** — package a pinned upstream revision for Linux and x86_64-darwin and author a local, minimal skill that only permits scoped scans and human-approved findings; do not ship upstream's `update-skill` content or automated runners.
   - Pros: reproducible supply chain and rollback; preserves Nix as deployment authority; can complement SDD by producing advisory evidence before a proposed change.
   - Cons: substantial packaging/platform validation; scanner state and false-positive risks remain; overlaps Ponytail's qualitative cleanup role and Go/Nix checks; introduces another competing review protocol.
   - Effort: High.

3. **CI gate or automatic OpenCode/Claude runner** — use `--profile ci` or native batch review as a quality threshold/gate.
   - Pros: upstream supports full-codebase CI snapshots and OpenCode batch reviews.
   - Cons: unsuitable now: full-repository scans mix Nix, Go, assets, and generated/runtime paths; Nix has no listed language support; upstream explicitly lacks diff-only scanning; subjective runner processes add cost, code egress, and nested-agent authority; score/state defects make a blocking threshold unsafe.
   - Effort: High.

4. **Reject all integration and retain existing lenses** — use Ponytail for intentional simplification, SDD/review gates for evidence-backed changes, Go tests plus Nix evaluation for correctness, and RTK for output efficiency.
   - Pros: no new mutable instructions, package supply chain, state directory, agent subprocesses, or competing workflow.
   - Cons: forgoes a structured Go mechanical-debt inventory and Desloppify's tracking UI.
   - Effort: Low.

### Recommendation

**Verdict: defer.** The highest-value integration class, if evidence later justifies it, is an **on-demand CLI limited to a manually approved sandbox trial**, not a shared skill, CI gate, user package, background service, or OpenCode/Claude runner. Its mechanical Go scan may complement Ponytail's subjective YAGNI lens, but its workflow/skill/triage layers duplicate or conflict with Gentle AI SDD and its automated agent runner conflicts with the harness's controlled delegation and RTK measurement boundaries.

Proposal work requires explicit approval to perform the narrow trial and to select a pinned upstream revision. Approval must also accept the trial's scoped source read and local `.desloppify` state, confirm a disposable worktree is acceptable, and require a written outcome gate: retain only findings independently verified against Go tests and repository policy; discard the state and defer adoption if exclusions leak, false positives dominate, any unapproved network/agent subprocess occurs, or Linux/x86_64-darwin packaging cannot be proven. No upstream installer, initializer, global setup, or generated skill may run.

### Risks

- The imported upstream skill explicitly tells agents to follow its queue instead of their own analysis, create a cleanup branch, make broad refactors, and push changes; this conflicts with SDD phase authority, current direct-master work, and Nix-managed assets.
- `update-skill` fetches mutable content from upstream `main` and writes agent instructions, defeating pinned/reviewed ownership; `setup` similarly bypasses declarative deployment.
- Scanning is not read-only in aggregate because it persists `.desloppify` state, can invoke external analyzers, and its optional runners can spawn nested OpenCode/Claude processes that expose scoped source to configured model providers.
- Upstream's open false-positive, exclusion, and strict-score issues make cleanup, deletion, threshold enforcement, and automatic resolution unsafe without dry-run review, narrow paths, explicit exclusions, rollback, and independent verification.
- Nix coverage is absent, no package candidate was found, and the exact pinned 26.05 availability was not queryable; a multi-host declarative rollout is unproven.
- The gist's blanket cleanup heuristics can erase intentional Go boundary validation or abstractions if treated as a global instruction rather than a review checklist.

### Ready for Proposal

No. Ask the user first to approve only the minimum viable sandbox trial described above, including the explicit pin, target (`pkgs/nixos-scripts` or another single coherent Go project), exclusion list, no-network/no-runner policy beyond installation from the approved pin, and discard/rollback criteria. A declarative integration proposal is appropriate only after that trial demonstrates useful, independently verified findings with no scope leak or workflow conflict.

## Key Learnings:

1. Desloppify is a stateful Python agent harness with both scanning and source-mutating autofix capabilities.
2. Its generated agent skill would conflict with this repository's declarative shared skill ownership and SDD authority.
3. The supplied Go gist is unrelated third-party guidance that substantially overlaps the existing Ponytail simplification lens.
4. Open upstream issues show that exclusion handling, dependency graphs, and score state can produce unsafe cleanup signals.
5. A manually approved, pinned, scoped Go sandbox is the only viable next experiment before any declarative adoption.
