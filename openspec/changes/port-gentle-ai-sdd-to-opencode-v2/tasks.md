# Tasks: Port Gentle AI SDD to OpenCode v2 (native-first reset)

> Native-first V2 plan; rewrite list retired; completed 1.3/1.6 kept as 1.1/1.2.

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: size-exception
400-line budget risk: High

## Workload Forecast

- Estimate: 1.3k to 1.7k lines.
- Delivery: exception-ok; one direct-to-main commit approved; apply never commits.

### Suggested work units

- Each slice independently revertible; V1 byte-identical throughout.
- Shared slice gate: `nix flake check --no-build` plus per-host evals plus V1 diff clean.

## Phase 1: P0 — v2 npm

- [x] 1.1 Pinned plugin/client/sdk 2.0.14 + SRI hashes recorded.
- [x] 1.2 `Plugin.define` + hooks verified vs pinned `.d.ts` (read-only).
- [x] 1.3 Create `pkgs/opencode-npm-packages-v2/` for `@opencode/plugin` 2.0.14 only; register in `lib/packages.nix`.
- [ ] 1.4 RED eval: V2 config lacks agents, permissions, and mcp keys; tree lacks plugins.
- [ ] 1.5 Confirm pinned 2.0.14 config schema; record keys to skip.
- [x] 1.6 Extend V2 branch of `runtime-config.nix` plus `shared/opencode.nix`.
- [ ] 1.7 Gate: flake check plus host evals plus V1 baseline clean.

## Phase 2: P1 — Portable assets

- [x] 2.1 V2 activation block in `runtime-config.nix`: copy skill sources and three command roots into V2 tree; cmp gate.
- [x] 2.2 V2-only `subtask` to `subagent` remap over copied bodies; V1 sources untouched.
- [x] 2.3 Native media only; no multimodal emission; record rationale comment.
- [ ] 2.4 Gate: `opencode2` lists every skill family and command; delegation targets `subagent`; V1 diff clean.

## Phase 3: P2 — Remaps

- [ ] 3.1 RED eval: sops, sudo, nixos-build denies hold; push ask/deny kept for tracking, first-push, refspec.
- [x] 3.2 Create `shared/opencode/v2-agents.nix`: overlay graph to V2 agents; remap prompt, disable, maxSteps, modes, `#variant` joins.
- [x] 3.3 Create `shared/opencode/v2-permissions.nix`: ordered `{action,resource,effect}`; map bash, task, grants, MCP denies; deny-first.
- [x] 3.4 Create `shared/opencode/v2-mcps.nix`: 7 servers under `mcp.servers`; inverse `disabled`; snake_case OAuth; local proxy scrub.
- [x] 3.5 Emit AGENTS.md context and `cli.json` in the V2 root.
- [x] 3.6 Wire emitters into the V2 generator branch.
- [ ] 3.7 Gate: rog smoke — agent inventory lists 10 SDD, 3 JD, 6 review and orchestrator/neutral/managed; `/mcps` shows 7 connected, no proxy leak.

## Phase 4: P3 — Adapters

- [ ] 4.1 Per-adapter gate: type-check each hook against pinned 2.0.14; drift blocks that adapter only.
- [ ] 4.2 RED: reject relative and outside-worktree git selectors before any subprocess.
- [ ] 4.3 RED: no staging or commit in empty, staged and -a states; fail closed.
- [ ] 4.4 RED: composed `gentle-ai review` pass-through; explicit `--head` and env prefix forwarded unmodified.
- [x] 4.5 Create `shared/opencode/rtk-v2.ts`: process probe, execute-before rewrite; pass-through on failure; V1 `rtk.ts` (read-only).
- [x] 4.6 Emit sdd-task-result and skill-registry adapters under `share/gentle-ai/opencode-v2/plugins/` via `pkgs/gentle-ai-assets`; worktree-root semantics.
- [x] 4.7 Create V2 `opencode-review-transport.ts` there; hooks; 6 review agents ride 3.2.
- [x] 4.8 Modify `pkgs/engram-assets/{default.nix,vanilla.nix}`: emit V2 `engram.ts`; keep `ENGRAM_BIN` substitution.
- [x] 4.9 Wire managed-plugin map and the activation deployment of adapters and node_modules.
- [ ] 4.10 Gate: five adapters register; rtk fires on bash; engram mem_save and mem_search succeed; 4.2 to 4.4 green; V1 diff clean.

## Phase 5: P4 — Drops plus cutover

- [x] 5.1 Record drop reasons: claude-auth, warden, TUI pair, model-variants, multimodal; assert no emission.
- [x] 5.2 Create `docs/opencode-v2-final-cutover.md`: migrate isolated V2 roots to default XDG paths; keep config, sessions, credentials.
- [ ] 5.3 `nix fmt` touched Nix files; Go suite (no changes expected).
- [ ] 5.4 Full matrix: flake check and host evals plus macm5 standalone HM.
- [ ] 5.5 Deny and proxy smoke on rog; dropped plugins absent.
- [ ] 5.6 Full SDD cycle plus review round-trip on 4 hosts; gate before default flip; V1 default; `opencode2` opt-in.
- [ ] 5.7 Final V1 diff clean; stale-comment sweep.

## Focused Remediation

- [x] R1 Register `opencode-npm-packages-v2` in both platform overlays so the
  V2 runtime can resolve `pkgs.opencode-npm-packages-v2`.
- [x] R2 Keep V2 asset staging in the V2 activation only; preserve the V1
  mutable-copy workflow without V2 remapping.
- [x] R3 Restore V1 activation ordering: remove the competing Home Manager
  skill link, copy `rom-downloader` through the V1 source list, and make the
  V1 skill tree writable before `linkGeneration` and before its `sed` mutation.
- [x] R4 Recreate the V2 command tree as a writable user-owned directory and
  copy without preserving read-only store directory modes before remapping.
