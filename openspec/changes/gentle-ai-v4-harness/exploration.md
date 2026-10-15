# Exploration: Gentle AI v4 harness integration + repo-wide usage audit

## Scope

Integrate the newly released Gentle AI **v4.0.0** into the OpenCode harness, and
audit every other place Gentle AI is consumed in this NixOS repository. This is
exploration only; no implementation was performed and the dirty tree was
preserved.

## External evidence (verified)

- Canonical upstream: `github:Gentleman-Programming/gentle-ai`. Context7 ID
  `/gentleman-programming/gentle-ai` (6313 snippets, benchmark 75.83).
- Current repo pin: **v2.5.0** — commit `f5dd1a6cf1823371374c7b2bef5b71e4790a146a`
  (`flake.nix` `gentle-ai-src`, `flake.lock` node ref `v2.5.0`).
- Latest stable release: **v4.0.0** — tag `v4.0.0`, commit
  `ff77164d4f56f1665b22fb6fac51c2ccbb769400`, published 2026-10-01 20:19 UTC.
  https://github.com/Gentleman-Programming/gentle-ai/releases/tag/v4.0.0
- The v3 line exists (latest **v3.7.0**); repo has never used it (jumped
  straight to v2.5.0 from earlier v2.x alignment work).
- Provider contract stays byte-frozen at `1.2.0` across v4 (no change).

### v4.0.0 breaking changes (from the release body — all verified against the tag)

1. **Go module path moves to `/v4`** — `github.com/gentleman-programming/gentle-ai/v4`.
   `cmd/gentle-ai` install path becomes `.../v4/cmd/gentle-ai@v4.0.0`.
2. **SDD and OpenSpec are retired.** ODD (Organic Driven Development) is the only
   workflow. Removed subcommands: `sdd-status`, `sdd-continue`, `sdd-attempt`,
   `sdd-archive-compose`, `sdd-task-result`, `sdd-preflight-hook`; removed flags
   `install --sdd-mode`, `sync --sdd-mode`, `sync --sdd-profile-strategy`.
3. **Strict TDD is no longer a separate option**; `sync --strict-tdd` is rejected.
4. **Review-driven prompts are scoped** to runtimes with native review transport
   (claude-code, codex, opencode).
5. **`pi-mcp-adapter` retired** (Pi-only; irrelevant to this repo).
6. **OpenCode V2**: managed plugins built on `@opencode/plugin`; SDK provisioning
   `2.0.4`; `sync` exits non-zero when OpenCode version is undetectable; native
   review admitted on V2 only with exact managed relay (proven only on OpenCode
   2.0.19 macOS + loopback provider).
7. **v3 self-upgrade cannot reach v4** on Go installs (module path); Homebrew
   users unaffected.

### v3.4.0 breaking change (context for the audit)

RTK community-tool integration was retired in v3.4.0. This repo's RTK usage is an
independent `pkgs.rtk` 0.41.0 pilot (see `openspec/specs/harness-token-efficiency`),
**not** the retired gentle-ai community tool — do not conflate the two during the
proposal.

## Current state — how Gentle AI is consumed today

Two independent derivations, both fed by the single `gentle-ai-src` input
(`lib/packages.nix`):

- `pkgs/gentle-ai/default.nix` — Go binary, `subPackages = [ "cmd/gentle-ai" ]`,
  `vendorHash` pinned; `postPatch` overrides `internal/assets/opencode/plugins/skill-registry.ts`
  with the local `skill-registry-worktree-root.ts` fix (`TODO(upstream)`).
- `pkgs/gentle-ai-assets/default.nix` — `stdenvNoCC`, copies `internal/assets/{opencode,skills,claude,cursor,windsurf,gemini,codex,kimi,qwen,kiro}`;
  applies the same skill-registry override; vendors **local V2 plugins** from
  `v2-plugins/` (`sdd-task-result.ts`, `opencode-review-transport.ts`,
  `skill-registry.ts`) because upstream v2.5.0 ships no V2 plugins.

## Affected areas (scope inventory)

| Area | File(s) | How it consumes Gentle AI |
|---|---|---|
| Flake input | `flake.nix` (68-73), `flake.lock` (383-399) | `gentle-ai-src` pinned v2.5.0 |
| Package defs | `lib/packages.nix` (28-37), `pkgs/gentle-ai/default.nix`, `pkgs/gentle-ai-assets/default.nix`, `pkgs/gentle-ai-assets/v2-plugins/*`, `skill-registry-worktree-root.ts`, `*.test.ts` | Go binary + asset tree + local V2 adapters |
| Overlays | `overlays/linux.nix` (11-13), `overlays/darwin.nix` (51-53) | expose `gentle-ai`, `gentle-ai-assets` |
| OpenCode V1 runtime | `shared/opencode.nix` (73,79,219), `shared/opencode/runtime-config.nix` (17,88-100,472), `shared/opencode/agents.nix` (20,130,149), `shared/opencode/plugins.nix`, `shared/opencode-profile.nix` (20-25) | commands, skills, plugins, `sdd-overlay-single.json` agent graph, `AGENTS.md`, `persona-gentleman.md` |
| OpenCode V2 runtime | `shared/opencode/runtime-config.nix` (64-70) | vendored V2 plugins (`sdd-task-result`, `opencode-review-transport`, `skill-registry`) |
| Agent overlays | `shared/opencode/local-agent-overlays.json` | `gentle-orchestrator`, `sdd-research`, `review-*`, `jd-*` grants; `gentle-ai review inspect-candidate` allow |
| Claude Code | `shared/claude-code.nix` (17-18,187,319) | claude agents/commands, persona/output-style assets |
| Shared assets | `shared/ai-assets.nix` (25) | `gentle-ai-assets/share/gentle-ai/skills` in `skillSources` |
| Shell aliases | `shared/shell-aliases.nix` (44-50) | `gsk`, `gsk!`, `gdoc`, `gupd`, `gsdd`→`sdd-status`, `gnext`→`sdd-continue`, `greview` |
| Homebrew (macm5) | `darwin/system/homebrew.nix` (19,24-26) | taps `Gentleman-Programming/tap`, installs `gga` (legacy; superseded by `providers-base.nix`) |
| Docs | `docs/gentle-ai-update.md`, `docs/gentle-ai-omo-workflow.md` | v2.x update runbook; retired SDD+OmO pilot |
| Local skills | `shared/assets/skills/model-fit/SKILL.md` | references `gentle-ai skill-registry refresh` |
| Specs/changes | `openspec/specs/gentle-ai-declarative-runtime/spec.md`, `openspec/changes/archive/2026-09-06-gentle-ai-v2-5-0-alignment/*`, `openspec/changes/port-gentle-ai-sdd-to-opencode-v2/*` | SDD runtime contract history |

## Approaches

### 1. Defer the v4 bump; keep v2.5.0 (no-op)

The repo's whole SDD harness (openspec hybrid store, `sdd-*` skills/agents/
commands/plugins, `sdd-overlay-single.json`, `state.yaml` DAG, `sdd-status`/
`sdd-continue`/`sdd-task-result` CLI) is built on v2.5.0 SDD, which v4 **removes**.

- Pros: zero risk; preserves the live SDD workflow and the in-flight
  V1/V2 parity + launcher work.
- Cons: does not satisfy the user's request to integrate v4.
- Effort: None.

### 2. Full v4 + ODD migration (retire SDD harness)

Bump `gentle-ai-src` to v4.0.0, recompute `vendorHash`, adopt ODD, and delete the
repo's SDD overlay/plugins/aliases/`openspec`-DAG plumbing.

- Pros: single version of truth; tracks upstream direction; removes ~123k lines of
  upstream SDD assets (per release diff).
- Cons: enormous, cross-cutting, irreversible in practice; changes the repository's
  entire artifact workflow; would retire the very mechanism (SDD) currently
  orchestrating this and other in-flight changes; conflicts with "do not modify
  V1/V2 parity/launcher work".
- Effort: High.

### 3. Staged parallel integration (v2.5.0 V1 + v4.0.0 V2)

Add a second flake input (`gentle-ai-v4-src`) and parallel derivations
(`gentle-ai-v4`, `gentle-ai-v4-assets`), wire the **isolated OpenCode V2 runtime**
to v4 assets and v4's native V2 plugins, and leave V1 + Claude + SDD on v2.5.0.
This mirrors the existing `opencode-v2`/`opencode-npm-packages-v2`/`browsermcp-v2`
parallel-package pattern.

- Pros: minimal, reversible (drop the v4 input to roll back), does not touch the
  V1 SDD harness, the parity work, or the launcher; adopts v4's actual OpenCode V2
  value (native review + `@opencode/plugin` assets) without committing to ODD.
- Cons: two `gentle-ai-src` inputs and two asset trees to keep in sync; the
  `sdd-overlay-single.json`/SDD-agent graph is absent from v4 so V2's current
  SDD-agent emission would need a v4-compatible replacement or to be dropped on V2.
- Effort: Medium.

### 4. Defer with re-entry conditions (tool-adoption gate)

Given v4.0.0 released 2026-10-01 (same day) and SDD retirement is a product-level
decision the repo has not made, record concrete re-entry conditions and stop.

- Pros: honest; avoids adopting a same-day major with an unproven V2 review path
  (upstream itself limits V2 review proof to OpenCode 2.0.19 macOS + loopback).
- Cons: does not integrate v4.
- Effort: None.

## Recommendation

Adopt **Approach 3 (staged parallel integration)** as the minimal, reversible path:
pin v4.0.0 in a new `gentle-ai-v4-src` input with its own derivations and route the
isolated OpenCode V2 runtime to v4's native V2 plugins, while the V1 harness,
Claude Code, shell aliases, and the SDD/openspec workflow stay on v2.5.0. This
directly satisfies "integrate v4 into the OpenCode harness" without disrupting the
live SDD machinery or the in-flight parity/launcher work. Treat the wholesale
SDD→ODD retirement as a **separate, explicitly-authorized change** (Approach 2),
gated on a user decision the proposal must surface, because it changes the
repository's development workflow itself.

## Risks

- **SDD retirement is the dominant risk**: `sdd-overlay-single.json`, all `sdd-*`
  skills/commands/plugins, `sdd-status`/`sdd-continue`/`sdd-task-result`, and the
  `gentle-ai sdd-*` CLI surface vanish in v4; the repo is currently *running* on
  them. A naive bump breaks the entire harness.
- **Go module path `/v4`**: `pkgs/gentle-ai/default.nix` `subPackages` and any
  `go install` references must move; `vendorHash` recompute required.
- **Local V2 plugins become redundant**: v4 ships upstream V2 plugins on
  `@opencode/plugin`; the vendored `v2-plugins/*` (pinned against `@opencode/plugin`
  2.0.14) must be reconciled or removed.
- **Shell aliases break**: `gsdd`/`gnext` target removed subcommands.
- **`skill-registry-worktree-root.ts` override**: the upstream `TODO` may or may
  not be resolved in v4; verify before dropping the override.
- **V2 native review is unproven off-macOS**: upstream documents V2 review proof
  only on OpenCode 2.0.19 macOS + a loopback provider; rog/thinkcentre/t14 are
  Linux NixOS hosts.
- **macm5 Homebrew tap** (`Gentleman-Programming/tap`) and the legacy `gga` brew
  are version-managed outside Nix and are unaffected by the Go module-path change,
  but `gga` is already superseded by `providers-base.nix` and is separate cleanup
  scope.

## Ready for Proposal

**Yes — but with a gate.** The proposal must (a) scope to Approach 3 (parallel v4
input + V2 runtime only) to stay minimal and reversible, and (b) explicitly ask the
user whether to also schedule the SDD→ODD retirement (Approach 2) as a separate
change, since that decision cannot be made implicitly by an executor. Recommend
deferring the ODD retirement until V2 native review is validated on a Linux NixOS
host.
