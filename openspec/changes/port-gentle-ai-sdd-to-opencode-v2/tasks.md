# Tasks: Port Gentle AI SDD to OpenCode v2 (native-first reset)

> Native-first V2 plan; rewrite list retired; completed 1.3/1.6 kept as 1.1/1.2.
> R14-R24 land the confirmed singleton BrowserMCP bridge: minimal custom Go
> stdio-multiplexing broker (`browsermcp-broker`), patched package (kill-on-port
> neutralized), loopback supervisor systemd+launchd, remote config emission,
> two-workspace concurrency proof. User authorizes apply.

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: size-exception
400-line budget risk: High

## Workload Forecast

- Estimate: 1.6k to 2.0k lines (R14-R24 add the bridge closure).
- Delivery: exception-ok; one direct-to-main commit approved; apply never commits.

### Suggested work units

- Each slice independently revertible; V1 byte-identical throughout.
- Shared slice gate: `nix flake check --no-build` plus per-host evals plus V1 diff clean.
- R14-R24 add the Go broker closure (broker binary, patch, unit, remote
  emission) plus the two-workspace concurrency runtime gate shared below.

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

### Plugin dependency closure (design: Node dependency closure)

- [x] R5 RED eval: a consumer importing only `@opencode/plugin` 2.0.14 fails
  module resolution for its transitive deps — assert
  `pkgs/opencode-npm-packages-v2/node-modules.json` lacks `@opencode/schema`
  and the V2 runtime `node_modules` has no `@opencode/schema` subtree.
- [x] R6 Create `pkgs/browsermcp-v2/`: pin `@browsermcp/mcp` 0.1.3 with SRI
  hash in `versions.json` and `node-modules.json`; stage its production
  dependency closure like the plugin closure, plus the capability-only patch.
- [x] R7 Patch pinned 0.1.3 source: initialize response advertises every
  existing capability EXCEPT `resources` (tools stay; `resources/list`
  remains implemented but the template-negotiation trigger is gone). Assert
  via grep: no `resources` capability flag in the patched initialize.
- [x] R8 Modify `pkgs/opencode-npm-packages-v2/` to fetch the full pinned
  2.0.14 production dependency closure — record `@opencode/schema` 2.0.14
  and every other transitive prod dep (`zod`, etc.) with SRI hashes; stage
  them under `lib/node_modules` with correct nesting/symlink layout.
- [x] R9 Verify `@opencode/plugin` 2.0.14 package.json `peerDependencies`/
  `bundledDependencies` semantics; if schema is a peer dep, record that V2
  runtime staging must place it top-level. Test: `nix eval` the staged tree,
  assert `lib/node_modules/@opencode/schema` exists top-level.

### BrowserMCP compatibility and singleton ownership (design: BrowserMCP rows)

- [x] R10 Define `home.opencode.v2.browserMcp` option in `shared/opencode.nix`
  (submodule: `enable` default true, `package` default
  `pkgs.browsermcp-v2`, `location` — global V2 config only, read-only option
  confirming singleton semantics).
- [x] R11 Remove the floating `browsermcp` entry from
  `shared/opencode/mcps-base.nix` (V1 keeps nothing stubbed; V2 is the only
  consumer of this entry today). `v2-mcps.nix` keeps working for the other
  6 servers.
- [x] R12 Emit BrowserMCP exactly once into the V2 global `mcp.servers` map
  only when `home.opencode.v2.browserMcp.enable = true`, via the V2 generator
  branch in `shared/opencode/runtime-config.nix` merging
  `v2Mcps // lib.optionalAttrs enable { browsermcp = <pinned package command>; }`.
- [x] R13 Gate: `nix flake check --no-build` plus Rog evals
  (`nix eval ... homeConfigurations.rog...`), asserting both: five-adapter
  plugin closure (R8) resolves under the V2 runtime, and V2 `opencode.json`
  contains exactly one `browsermcp` server entry whose command references
  the pinned package (not `npx`), zero in project/workspace maps
  (OPENCODE_DISABLE_PROJECT_CONFIG=1 already enforces project-map absence).
  Superseded by R21/R23: the 0.1.3 per-session stdio spawn multiplies the
  fixed-port process; tasks remain as the recorded pre-bridge history.

### BrowserMCP singleton transport (design: transport/service rows + Runtime Test Plan)

- [x] R14 Implement the `browsermcp-broker` Go command: a long-lived binary under
  `pkgs/nixos-scripts/cmd/browsermcp-broker/` (thin entry) +
  `pkgs/nixos-scripts/internal/browsermcp/` (multiplexing logic). It MUST:
  (a) spawn exactly one patched BrowserMCP stdio child with `crypto/rand`
  JSON-RPC IDs; (b) perform a synthetic `initialize` + `tools/list` once;
  (c) front a loopback-only Streamable HTTP endpoint
  (`http://127.0.0.1:<port>/mcp`) via `net/http` that accepts concurrent
  POST requests; (d) replay cached `initialize`/`tools/list` for each new
  MCP session; (e) multiplex all `tools/call` on the single child with
  ID correlation (broker JSON-RPC ID → HTTP session); (f) refcount child
  lifecycle (start on first session, stop when idle); (g) never inherit
  proxy environment; (h) fail rather than double-bind an occupied port.
  Test: `go -C pkgs/nixos-scripts test ./... && nix build`
   `.#packages.x86_64-linux.nixos-scripts --no-link` exit 0.
- [x] R14a Register the broker command and internal package files in Git so the
  flake source includes the already-authored Go implementation. Gate:
  `go -C pkgs/nixos-scripts test ./...`, `nix build .#nixos-scripts --no-link`,
  and Rog Home Manager activation derivation evaluation all exit 0.
- [x] R15 Extend the `pkgs/browsermcp-v2/` 0.1.3 patch beyond R7: neutralize
  the startup `killProcessOnPort` (`lsof -ti:9009 | xargs kill -9`) so a free
  or occupied 9009 boots cleanly; assert via grep that the patched source no
  longer runs kill-on-port on startup while all 12 tools stay intact and
  initialize keeps the R7 tools-only capability.
- [x] R16 RED eval: V2 global config currently emits `type: "local"` (R12-era
  shape) — assert the pre-bridge shape fails the singleton contract (two
  workspaces each spawning `type:"local"` browsermcp → second kills first),
  so remote emission tasks have a provable target. Update `apply-progress.md`
  with the captured evidence.
- [x] R17 RED: prove the `browsermcp-broker` keeps exactly one stdio child
  across ≥2 concurrent Streamable HTTP clients — if two HTTP sessions ever
  spawn two browsermcp processes, each holds 9009 and the singleton dies; this
  gate must be green before R18-R23 proceed.
- [x] R18 Define `home.opencode.v2.browserMcp.bridgePort` (initial default 9008;
  superseded by R26 to 9010) and
  `bridgePackage` (default `pkgs.nixos-scripts`, providing `browsermcp-broker`)
  in `shared/opencode.nix`, and assert at activation that 9008 is not already
  bound (fail/warn, never double-bind).
- [x] R19 Create the supervised `browsermcp` user unit in `shared/opencode.nix`:
  `systemd` on Linux, `launchd.agent` on Darwin; run
  `browsermcp-broker --child <package>/bin/mcp-server-browsermcp
  --port <bridgePort>` — the broker's BrowserMCP child must NOT inherit proxy
  environment.
- [x] R20 Unit policy: `Restart=on-failure` (systemd) / `KeepAlive.Crashed`
  (launchd).
- [x] R21 Replace the R12-era local emission in `shared/opencode/v2-mcps.nix`
  with `type: "remote"; url = "http://127.0.0.1:${bridgePort}/mcp"` gated by
  `home.opencode.v2.browserMcp.enable`.
- [x] R22 Mirror R21 into the V2 generator branch of
  `shared/opencode/runtime-config.nix` (global map only; zero browsermcp in
  any project/workspace map).
- [x] R23 Gate: `nix flake check --no-build` plus Rog evals — assert exactly
  one `type: "remote"` browsermcp URL (absolute 127.0.0.1 URL) in V2 global
  config, zero `type: "local"`, zero project/workspace map entries.
- [ ] R24 Runtime gate (rog, then each Linux host; Darwin after R19):
  (a) service active; (b) `curl -sS http://127.0.0.1:9010/mcp` handshake
  accepts; (c) `ss -ltnp | grep 9009` shows exactly one listener; (d)
  two-workspace concurrency: two V2 workspaces both list 12 tools, `ps` shows
  one browsermcp, no timeout, no kill-on-port; (e) paired real tool call
  succeeds, unpaired reports unpaired (never fake-healthy); (f)
  `systemctl --user restart browsermcp` recovers and both workspaces
  reconnect without extension re-pair; (g) regression: flake check, per-host
   evals, V1 byte-identity diff, and the 5.6 SDD round-trip still green
   (record in `apply-progress.md`).
- [x] R25 Make generated V2 `cli.json` activation idempotent: force the managed
   file and remove only its stale `.backup` before `linkGeneration`, preserving
   V1 and V2 user state. Gate: Rog activation completes with a pre-existing V2
   `cli.json.backup` and the backup is absent afterward.
- [x] R26 Resolve the deployed bridge ownership collision: code-server owns
    `127.0.0.1:9008` on rog, so the declarative bridge default is `9010`; an
    `EADDRINUSE` broker exit uses status `78`, which systemd excludes from
    restart while leaving the foreign listener untouched.
- [x] R27 Restore the pinned OpenCode 2.0.14 agent schema after the legacy
     regression: emit top-level `agents`, per-agent `system`, `disabled`,
     `steps`, `mode`, and ordered `permissions` arrays. Convert scalar and
     resource-map permissions without relaxing denials; normalize disabled MCP
     tool actions with `_`; allow only Context7 and Exa research actions for
     `sdd-research`. Gate: generated V2 JSON declares `gentle-orchestrator` as
     primary and `sdd-explore` as a subagent with `system` and permissions,
     without V1 fields.
- [ ] R28 Runtime follow-up: complete a native V2 service restart and a
      noninteractive provider query on rog. The schema deployment reached the
      native restart activation, but the command did not return; standalone
      native query reached the provider and was rejected for insufficient funds.
- [x] R29 Repair native V2 lifecycle scoping: retire the stale default-XDG V2
      service that held 49374, retain direct shared-service wrappers, and reload
      the isolated V2 service after generated configuration changes (restart as
      fallback). Gate: rog `opencode2 service status` and a query from another
      workspace both return `http://127.0.0.1:49374`; `opencode2 reload`
      confirms reload and `debug agents` returns the generated registry.
- [x] R30 Make V2 SDD delegation exact: after V2 skill synchronization, append
      an idempotent phase directive to every ten `delegate_only` SDD skill that
      requires the Task call's matching `subagent_type` and prohibits `general`.
      Reload only after this mutation.
      Gate: generated `sdd-explore/SKILL.md` contains
      `subagent_type: "sdd-explore"`; live model invocation remains separately
      blocked by the provider's insufficient-funds response.
