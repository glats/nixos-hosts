## Exploration: port-gentle-ai-sdd-to-opencode-v2

> **Re-exploration (2026-09-25) — perspective pivot.** This file replaces the
> prior exploration, which framed the work as a *mechanical V1-plugin port*
> ("rewrite 6 local + 3 npm + 2 TUI plugins against the V2 plugin API"). The
> user confirmed V1/V2 must remain **parallel and isolated**, and directed a
> different lens: **adopt V2-native capabilities first** (native agents,
> permissions, MCP, skills, commands, media, subagents, policies) and write
> **only minimal V2 adapter plugins for the genuine gaps**, not one rewrite per
> V1 plugin. Evidence: live OpenCode V2 docs (`opencode.ai/v2/docs/*`), GitHub
> source (`anomalyco/opencode`), the pinned upstream asset repos
> (`gentle-ai@v2.5.0`, `engram@main`), and the V1 plugin sources in this repo.

### Current State

The repo runs OpenCode V1 and V2 as two isolated, side-by-side runtimes
generated from one Nix module (`shared/opencode.nix` →
`shared/opencode/runtime-config.nix`). The base change `migrate-opencode-v1-to-v2`
established this coexistence and deferred the V2 feature port.

- **V1** = `anomalyco/opencode` v1.18.32 (GitHub release binary), plugin SDK
  `@opencode-ai/sdk`/`@opencode-ai/plugin` v1.18.32. Emits a full declarative
  `opencode.json` (`agent`, `provider`, `mcp`, `permission`, `plugin`,
  `disabled_providers`, `tools`, `compaction`) plus a heavy activation that
  unions skills/commands from Nix store sources, copies plugin `.ts` files,
  installs node_modules + TUI plugins, and patches an `sdd-apply`/`sdd-verify`
  frontmatter marker.
- **V2** = `@opencode/cli` v2.0.14 (npm platform tarball), a different major
  codebase (GA). Today it emits only `{ "update": "disable" }` plus (via the
  sibling `port-opencode-v2-provider-allowlist` change) an
  `experimental.policies` provider allowlist. No agents, MCPs, skills, commands,
  plugins, Engram, SDD, or reviewer transport are emitted. V2 uses a native
  shared background server (`opencode2 service restart`), version-scoped XDG
  roots (`~/.config/opencode-v2` + `~/.local/opencode-v2`), and
  `OPENCODE_DISABLE_PROJECT_CONFIG=1`.

The load-bearing **V1 plugin set** is what the prior exploration over-rotated on.
Its actual contents (read from source this session):

| V1 plugin | What it actually does | File |
|---|---|---|
| `model-variants.ts` | Fetches provider list, writes a variant cache to `~/.gentle-ai/cache/model-variants.json` for the `gentle-ai` CLI effort picker. **Not a runtime feature.** | `pkgs/gentle-ai-assets` (upstream) |
| `opencode-review-transport.ts` | Reviewer relay: hooks the `task` tool for the 6 `review-*` agents, spawns `gentle-ai review opencode-transport`, materializes the Go prompt, strips the child system prompt, captures the result. Uses `tool.execute.before/after` + `experimental.chat.system.transform` + `event` — **not** `permission.ask`. | `pkgs/gentle-ai-assets` (upstream) |
| `sdd-task-result-artifacts.ts` | Hooks the `task` tool for the 10 SDD phase agents, validates the `<task_result>` envelope, throws typed `GENTLE_AI_SDD_FAILURE` on empty/malformed. | `pkgs/gentle-ai-assets` (upstream) |
| `skill-registry.ts` | Fire-and-forget `gentle-ai skill-registry refresh` at startup (worktree-root guard). | `pkgs/gentle-ai-assets` + local override |
| `engram.ts` | Spawns/connects the engram HTTP server; session lifecycle; user-prompt capture; injects `session_id` into `mem_*` calls; injects the memory protocol into the system prompt; compaction context injection; save-nudge. | `pkgs/engram-assets` (upstream + `ENGRAM_BIN` sub) |
| `rtk.ts` | Rewrites bash/shell commands via `rtk rewrite`. | `shared/opencode/rtk.ts` |

npm plugins (V1 auto-install): `opencode-claude-auth@latest`,
`opencode-multimodal@latest`, `opencode-warden@1.2.0` (the latter is load-bearing —
`shared/opencode.nix:181` emits its audit config). TUI plugins:
`opencode-subagent-statusline`, `opencode-sdd-engram-manage`.

### V1 Component Inventory → V2-native / adapter / blocker mapping

Classification key: **NATIVE** = V2 config feature, zero plugin code; **COPY** =
asset drop-in (Markdown), zero code; **REMAP** = Nix emits a different JSON
shape, zero plugin code; **ADAPTER** = a *minimal* V2 `Plugin.define` where V2
has no native equivalent; **DISPOSITION** = no V2 release or needs a user
decision.

| # | V1 component | V2 disposition | Detail |
|---|---|---|---|
| 1 | Skills (sdd-*, caveman, ponytail, nix-verify, archify, judgment-day, …) | **COPY** (native skill discovery) | V2 discovers `~/.config/opencode-v2/skills` natively. `SKILL.md` unchanged. Verify whether the line-1 `<!-- section:model-capable -->` marker patch is still needed (V2 parses frontmatter natively → likely drop for V2). |
| 2 | Commands (sdd-*, skill-creator/registry) | **COPY + REMAP** | V2 discovers `commands/` natively; only rename `subtask`→`subagent`. |
| 3 | Agents (10 SDD + 3 JD + 6 review + orchestrator/neutral/managed) | **REMAP** | `agent`→`agents`, `prompt`→`system`, `disable`→`disabled`, `maxSteps`→`steps`, `mode` map→`mode: primary/subagent/all`, model `#variant` joins. Nix-side routing unchanged. |
| 4 | Permissions (`bash`/`read`/`external_directory` + per-agent overlays) | **REMAP** | `permission`→`permissions` ordered `{action,resource,effect}`; `bash`→`shell`, `task`→`subagent`, `write`/`patch`→`edit`; `disabledTools`→MCP `_`-normalized deny rules. |
| 5 | MCP servers (github-personal/work, nixos, context7, engram, browsermcp, exa) | **REMAP** | `mcp`→`mcp.servers`, `enabled`→inverse `disabled`, remote OAuth snake_case, `oauth:false` for API-key servers; preserve proxy-scrub env. |
| 6 | Engram `mem_*` tools | **NATIVE** (`mcp.servers`) | `engram mcp --tools=agent` is a version-agnostic MCP server — declare it natively. **No plugin needed for the memory tools.** |
| 7 | `model-variants.ts` | **DEPRECATE (native)** | V2 models are catalog-driven with native `#variant`. The plugin only writes a cache for the *external* `gentle-ai` CLI picker — not a runtime feature. Deprecate; if the picker still needs the cache, move generation into `gentle-ai` Go CLI or a catalog read, not a runtime plugin. |
| 8 | `rtk.ts` | **ADAPTER** (minimal) | No native shell-rewrite feature. `ctx.tool.hook("execute.before")` on bash/shell; thin delegator, same `rtk rewrite` source of truth. |
| 9 | `sdd-task-result-artifacts.ts` | **ADAPTER** (minimal) | V2 subagent tool is native, but the envelope validation + typed failures are custom. Hook the **subagent** tool (`ctx.tool.hook`) for SDD phase agents. |
| 10 | `opencode-review-transport.ts` | **ADAPTER** (minimal) | The `gentle-ai.provider-transport/v1` relay is custom and Go-owned. Port the hook registration to `ctx.tool.hook("execute.before/after")` on the subagent tool + `ctx.session.hook("context")` for system-prompt isolation + `ctx.event.subscribe` for session lifecycle. **(Corrects the prior design, which wrongly mapped this to `permission.ask`→`ctx.permission.hook("evaluate")` — the V1 plugin never used `permission.ask`.)** |
| 11 | `skill-registry.ts` | **ADAPTER** (trivial) | V2 has no native startup command. Run `gentle-ai skill-registry refresh` inside `setup(ctx)`. |
| 12 | `engram.ts` (session lifecycle, prompt capture, system-prompt injection, compaction, nudge) | **NATIVE + ADAPTER** | `mem_*` tools native (#6). Static memory protocol → native global `AGENTS.md` (V2 instruction discovery; note V2's `instructions` config is accepted-but-inert per docs, so use `AGENTS.md`). Remaining gaps (session attribution, prompt capture, compaction context, save-nudge) → one minimal adapter. **Verify at apply:** V2 passes `sessionID` on MCP `CallTool` per docs, which may let the engram MCP resolve sessions natively and shrink the adapter further. |
| 13 | `opencode-multimodal` (npm) | **NATIVE → DROP** | V2 has native `media` config + built-in image read/attachment (PNG/JPEG/GIF/WebP). |
| 14 | `opencode-claude-auth` (npm) | **DISPOSITION (decision)** | V2 Anthropic integration offers native API-key auth (already used via sops). The community V2 fork `opencode-claude-auth-v2` targets the beta namespace (`@opencode-ai/cli@next`), **not** stable `@opencode/cli@2.0.14`. Decide: native API keys (recommended, zero plugin) vs. adopting a fork with no stable-2.0.14 release. |
| 15 | `opencode-warden` (npm) | **DISPOSITION (decision)** | Load-bearing audit (`opencode-warden.json`). No `@opencode/plugin`-based release. Native `experimental.policies` `permission` statements cover *deny*, not audit-logging/prompt-scanning. Decide: drop (native policies for deny) vs. re-implement audit as a minimal V2 adapter. |
| 16 | `opencode-subagent-statusline` (TUI) | **DISPOSITION (verify)** | V2 has native subagent progress (foreground/background). Verify whether native TUI status suffices; else drop or a minimal `cli.json` plugin. |
| 17 | `opencode-sdd-engram-manage` (TUI) | **DISPOSITION (decision)** | Custom TUI commands. V2 uses one global `cli.json` + `@opencode/plugin/tui`. Drop or reimplement; low value, likely drop. |

**Net result of the pivot:** the plugin surface collapses from **11 rewrites**
(6 local + 3 npm + 2 TUI) to **5 minimal local V2 adapters** (rtk,
sdd-task-result, review-transport, engram-attribution, skill-registry) plus **1
native drop** (multimodal) and **3 dispositions** (claude-auth, warden, TUI). The
npm SDK surface shrinks from `@opencode/sdk`+`@opencode/client`+`@opencode/plugin`
to just `@opencode/plugin` (the `ctx` object embeds the client).

### Affected Areas

- `shared/opencode/runtime-config.nix` — the single generator; the V2 branch
  gains native config emission (agents/permissions/MCP/`cli.json`) and a slim
  V2 adapter-plugin deployment. V1 branch untouched.
- `shared/opencode.nix` — V2 activation gains asset copy + adapter deployment
  (analogous to, but much smaller than, V1's activation).
- `shared/opencode/{agents,permissions,plugins,mcps-base,mcps}.nix` — V2-shaped
  emitters for agents/permissions/MCP; `plugins.nix` V2 toggles shrink to the 5
  adapters.
- `shared/opencode/rtk.ts` — V1 file byte-preserved; a new `rtk-v2.ts` is the
  V2 adapter (or the adapter is version-gated in one file).
- `pkgs/opencode-npm-packages-v2/` (new) — V2 npm variant now only needs
  `@opencode/plugin` (+ optionally `@opencode/plugin/tui` if a TUI adapter is
  kept). Prior P0 planned `@opencode/sdk`/`@opencode/client` — no longer needed.
- `pkgs/{gentle-ai,engram,caveman,ponytail,local}-assets/` — reuse store paths;
  add `opencode-v2/plugins/` adapters beside the V1 `opencode/plugins/`.
- `shared/shell-aliases.nix`, `pkgs/opencode-v2/` — unchanged (runtime scaffold
  and wrappers are owned by the base/sibling changes).

### Dependencies

- `migrate-opencode-v1-to-v2` (parent) — supplies V2 runtime/isolation; untouched.
- `port-opencode-v2-provider-allowlist` (sibling) — owns `providers` +
  `experimental.policies`; this change consumes, never re-owns.
- `gentle-ai` Go CLI — `sdd-status`/`review opencode-transport`/`skill-registry
  refresh` are V2-agnostic. The model-variants cache (if kept) becomes a
  `gentle-ai` CLI concern, not a plugin.
- `engram` Go CLI + MCP — version-agnostic; MCP declared natively in V2.
- npm: `@opencode/plugin` (2.0.14) only; pinned `@opencode/cli` binary unchanged.

### Approaches

1. **Native-first adoption with minimal adapters (recommended).** Emit the full
   V2 native config (agents, permissions, MCP incl. engram, skills, commands,
   `media`, `cli.json`) from the existing Nix sources; write only the 5 minimal
   adapters for genuine gaps; deprecate model-variants; disposition the npm/TUI
   plugins. V1 stays byte-identical and default throughout.
   - Pros: matches the user's "native first, minimal adapter" directive; plugin
     code drops ~70% vs. the old plan; every native piece is deterministic and
     eval-gated; risk concentrates in only 5 small adapters; V1 fallback intact.
   - Cons: three open dispositions (claude-auth, warden, TUI) need a user call;
     the engram adapter's scope depends on a to-verify MCP-sessionID behavior.
   - Effort: **Medium** (was High under the old plan).

2. **Mechanical V1-plugin port (rejected — the prior plan).** Rewrite all 6 local
   + 3 npm + 2 TUI plugins against the V2 API.
   - Pros: none over approach 1.
   - Cons: re-implements behavior V2 already provides natively (media, model
     variants, engram MCP); preserves V1-only npm/TUI dependencies that have no
     stable V2 release; ~2× the code. Rejected as the end state.

3. **V1-compat-first (rejected).** Emit V1-shaped config and rely on V2
   warn-and-normalize.
   - Pros: smallest Nix diff.
   - Cons: leaves deprecated fields + mixed-format warnings; never reaches the
     native V2 shape the user asked for. Rejected (acceptable only as a
     temporary bridge inside approach 1).

### Recommendation

**Approach 1.** Order by risk: (P1) COPY skills/commands + native `media`;
(P2) REMAP agents/permissions/MCP (incl. native engram MCP) + `cli.json`;
(P3) the 5 minimal adapters, ordered rtk → sdd-task-result → skill-registry →
review-transport → engram-attribution; (P4) dispositions (deprecate
model-variants; decide claude-auth/warden/TUI). Keep V1 byte-identical and
default; flip the default only after a full SDD + reviewer round-trip passes on
V2 across all four hosts.

### Risks

- **Three open dispositions are user decisions, not technical.** `opencode-claude-auth`
  (beta-only V2 fork), `opencode-warden` (no V2 release; load-bearing audit), and
  the two TUI plugins need drop/reimplement/keep-V1-only verdicts before apply.
- **Pinned 2.0.14 vs current docs drift.** Docs describe a newer API
  (`ctx.catalog.transform`); the pinned 2.0.14 exposes `ctx.model.transform` and
  no `ctx.catalog` (recorded in apply-progress). Irrelevant to model-variants
  (now deprecated), but every adapter's hook domain must be re-verified against
  2.0.14 at apply.
- **Engram attribution scope.** Whether V2's native MCP `sessionID` forwarding
  removes the need for the adapter's `tool.execute.before` session-injection is
  unverified; if absent, the engram adapter carries more of V1's session logic.
- **V2 `instructions` is accepted-but-inert.** The docs state V2 accepts an
  `instructions` array but does not load it; the memory protocol must go through
  native `AGENTS.md` (global) or a `ctx.session.hook("context")` adapter — not
  the `instructions` field.
- **Permission remap is semantic, not a rename.** `bash`→`shell`, `task`→`subagent`,
  `write`/`patch`→`edit`, and bare tool grants have no 1:1 V2 map; a per-agent
  deny-smoke is mandatory.
- **V1 byte-identity must be proven per slice** (`diff -r` on `opencode.json` +
  asset tree), since the pivot touches the same generator the V1 branch lives in.

### P0 Artifact Reset Assessment

The pivot invalidates the plugin-facing portion of the current P0 artifacts.
They must be **reset/replanned** (not edited piecemeal) before apply:

- `proposal.md` — "Rewrite 6 local plugins … npm/TUI replacement" → replace with
  "5 minimal adapters + deprecate model-variants + 3 dispositions." **Reset.**
- `spec.md` — the "Plugin Rewrite and Test Gates" requirement and the
  "model-variants Disposition" requirement reference the mechanical port and a
  nonexistent `ctx.catalog` proof. **Reset the plugin requirement.**
- `design.md` — P3 "rewrite six local plugins" + the `ctx.catalog.transform`
  model-variants decision are both wrong now. **Reset P3.**
- `tasks.md` — Phase 4 (plugin rewrites) and task 1.4's npm scope
  (`@opencode/sdk`/`@opencode/client`) **replan**; task 4.8's `ctx.catalog`
  blocker is **moot** (deprecate). The accepted `size:exception`/`exception-ok`
  delivery decision should be re-forecast — the scope shrink likely drops the
  400-line risk from High to Medium/Low.
- `apply-progress.md` — the recorded `ctx.model.transform` API-drift finding is
  retained as an apply-time verification note; the "blocked on model-variants"
  status is resolved by deprecation.

### Ready for Proposal

**Yes**, with three user decisions to surface (not blockers — resolvable at
proposal): (1) `opencode-claude-auth` — native API-key auth (recommended) vs.
adopt the beta-only V2 fork; (2) `opencode-warden` — drop to native policies vs.
re-implement audit as a minimal V2 adapter; (3) the two TUI plugins — drop vs.
reimplement. The orchestrator should also confirm the P0 reset (proposal/spec/
design/tasks) and re-forecast the delivery strategy now that the plugin surface
has shrunk.

---

## BrowserMCP singleton transport — definitive fix (re-exploration 2026-09-28)

### Current State (post-R10–R13 implementation)

BrowserMCP is already pinned (`pkgs/browsermcp-v2`, `@browsermcp/mcp` 0.1.3 +
`@modelcontextprotocol/sdk` 1.8.0), patched to stop advertising the incomplete
`resources` capability, and emitted exactly once into the V2 **global**
`mcp.servers` map as `type: "local"; command = [ "<pkg>/bin/mcp-server-browsermcp" ]`
(`shared/opencode/runtime-config.nix` `v2McpsWithBrowser`, gated by
`home.opencode.v2.browserMcp.enable`). `OPENCODE_DISABLE_PROJECT_CONFIG=1` keeps
it out of project/workspace maps. **This does not fix the timeout.** The user
still reports "works for one V2 location, times out for a second."

### Root cause (confirmed from upstream source and issues)

1. `@browsermcp/mcp` 0.1.3 has a **hard-coded, non-configurable WebSocket on
   port 9009** for the Chromium extension, and its startup runs
   `killProcessOnPort(9009)` = `lsof -ti:9009 | xargs kill -9` (BrowserMCP
   issues #14, #113, #151; `@nbiish/betterbrowsermcp` README documents the same
   behavior verbatim). There is no `PORT`/`WS_PORT` env in 0.1.3.
2. OpenCode V2 spawns **one `type: "local"` stdio process per session/project**,
   with no deduplication or sharing (upstream issues #29939 "1 project = 8+
   instances, 2+ projects = crash", #31554, #26714, #30123). A maintainer note
   in #29939 states the structural fix is "a broker owning one long-lived process
   per server config … http+sse sidesteps it entirely because connection and
   process are already separate."
3. Therefore a second V2 workspace launches a second BrowserMCP process, which
   kills the first via `killProcessOnPort(9009)` → the first location's browser
   tools break; the race also produces the observed `Request timed out`.
   Emitting the entry once globally is orthogonal to per-session spawning and
   cannot prevent this.

Secondary defect: on a clean first boot (port 9009 free), `lsof -ti:9009 | xargs
kill -9` emits "kill: not enough arguments" and can crash the server before it
binds (issue #14/#151) — so even a singleton must neutralize the kill-on-port.

### Research findings (mandatory current research, 2026-09-28)

Upstream source, GitHub issues, and MCP docs were re-checked this session. The
supergateway blocker is confirmed and is **irreversible** — no supergateway flag
produces one shared stdio child:

1. **BrowserMCP has no native HTTP transport.** `@browsermcp/mcp` 0.1.3
   (`BrowserMCP/mcp`, package.json `bin: mcp-server-browsermcp`, deps
   `@modelcontextprotocol/sdk ^1.8.0` + `ws`) speaks **stdio** to its MCP client
   and a **hard-coded WebSocket on 9009** to the extension. The kill-on-port
   (`lsof -ti:9009 | xargs kill -9` / Windows `taskkill`) is still unfixed
   upstream (issues #14, #57, #70, #113, #151, #180; #192 shows the extension
   service worker still polls `ws://localhost:9009`). Issue #48 (SSE/Streamable
   HTTP) closed as unsupported. The newer `browsermcp.dev` product
   (`@agent360/browser-mcp`, ports 9876–9895, 20 concurrent sessions) is a
   different, rebranded line — not the pinned package.
2. **OpenCode V2 spawns one local stdio MCP child per session** and its
   `type: "remote"` (Streamable HTTP) client opens **one MCP session per OpenCode
   session** (docs: `_meta.sessionID` per call; each session gets its own
   `StreamableHTTPClientTransport`). The maintainer's own diagnosis of #29939:
   "the structural fix is a broker owning one long-lived process per server
   config and multiplexing sessions over it with refcounted shutdown. http+sse
   sidesteps it entirely because connection and process are already separate."
   There is **no config-only singleton** — also confirmed by #13041, #26336,
   #26714, #30123, #42190, #43845, #50363.
3. **supergateway cannot be the broker.** Its stdio→Streamable HTTP is stateless
   (child per request) or `--stateful` (child per MCP session — one `initialize`
   per session, `stdioToStatefulStreamableHttp.ts` spawns a new child per
   session). Two workspaces = two HTTP sessions = two BrowserMCP children = two
   9009 owners. The v3.3 concurrency pool was rolled back (#105); single-child
   multiplexing is still a live, unsolved upstream issue (#18, #35). So the
   original "pinned supergateway" plan (R14/R17) cannot hold the singleton.
4. **Off-the-shelf multiplexers exist but do not fit.** `mcp-mux`
   (`thebtf/mcp-mux`) is purpose-built ("share one upstream across N sessions",
   `shared` mode caches initialize/tools/list and keeps one child) but is a
   1-star, March-2026, single-maintainer tool with a ~30-version engine and a
   process-tree handoff protocol, is Claude-Code-centric (cwd-token handshake),
   and — decisively — its auto-classifier puts tools whose names match
   *browser / navigate / page / tab* into **`isolated`** mode (one child per
   session, i.e. the exact bug). Forcing `shared` requires patching BrowserMCP's
   initialize with `x-mux: {sharing:"shared", persistent:true}` and trusting a
   brand-new engine. Aggregator gateways (aiMCPGate, mcplex, mcpmu, agentgateway,
   mcp-gateway-pro) are multi-server tool-aggregators (meta-tool indirection /
   tool namespacing) — heavier than a single-server need and they change the tool
   surface.
5. **"Native HTTP singleton + extension pairing" servers exist but are different
   products.** `thezzisu/openbrowsermcp` (Streamable HTTP :3500 + WS :3500/ws),
   `rtf6x/browser-control-mcp` (HTTP :18790 + WS :18789, "HTTP transport for
   OpenCode"), `notoriouslab/browser-mcp-lite` (4 tools), `@iflow-mcp/
   browsermcp-mcp-enhanced` (HTTP daemon + single WS daemon 8765) all pair with
   their **own** extension and expose a **different** tool set. None preserves
   BrowserMCP's exact 12 tools + the already-paired extension, so all violate
   "preserves browser tools."

### Approaches

1. **Minimal custom Go stdio-multiplexing broker (recommended).** A ~300-line
   long-lived Go binary (`browsermcp-broker`, under `pkgs/nixos-scripts/cmd/`
   + `internal/`, built by the existing `nixos-scripts` Go derivation) that
   spawns **one** patched BrowserMCP stdio child, performs a synthetic
   `initialize` + `tools/list` once, and fronts it as a loopback Streamable HTTP
   endpoint (`http://127.0.0.1:9008/mcp`). Each HTTP session gets its own
   `StreamableHTTPServerTransport` with replayed/cached `initialize`+`tools/list`,
   but **every `tools/call` forwards to the single child** with broker-assigned
   JSON-RPC IDs correlated back to the right session (the exact "broker owning
   one long-lived process per server config" the maintainer prescribes). OpenCode
   emits the already-designed `type: "remote"` entry; the supervised systemd/
   launchd unit runs the broker, not supergateway.
   - Pros: preserves the exact 12 tools + already-paired extension; one port-9009
     owner; matches the maintainer's structural fix verbatim; loopback-only,
     auditable, ~300 lines vs. a 30-version third-party engine; reuses the repo's
     Go operational-binary convention and the existing supervised-unit/remote-
     emission design (only the bridge binary swaps).
   - Cons: it is bespoke code (the one genuine cost); must implement JSON-RPC ID
     correlation + child lifecycle/refcount, and rides OpenCode's `type: "remote"`
     client (which has session-recovery quirks, #25137/#38891 — mitigated by a
     stable loopback child and a long session timeout).
   - Effort: **Medium**.

2. **Off-the-shelf mcp-mux `shared` mode.** Pin `mcp-mux` as the shim command in a
   `type: "local"` entry and force `shared` via an `x-mux` patch to BrowserMCP.
   - Pros: zero bespoke broker code.
   - Cons: 1-star new tool, Claude-Code-centric token/cwd handshake, ~30-version
     engine + handoff protocol far beyond the need, and the default classifier
     would isolate browser tools unless overridden — a larger trust/maintenance
     surface than 300 lines of our own Go. Rejected as the primary, retained as a
     fallback if the user forbids bespoke code.
   - Effort: Medium (but high dependency risk).

3. **Switch to a native-HTTP browser server.** Adopt openbrowsermcp /
   browser-control-mcp / enhanced-browsermcp and pair its extension.
   - Pros: zero bridge; OpenCode `type: "remote"` points straight at the server.
   - Cons: **loses BrowserMCP's 12 tools and the already-paired extension** —
     a capability regression that violates "preserves browser tools." Rejected.
   - Effort: Medium (with a tool-surface regression).

### Recommendation

**Approach 1 — a minimal custom Go stdio-multiplexing broker.** It is the only
option that simultaneously preserves the exact BrowserMCP tool + extension
surface, holds the singleton contract, matches the OpenCode maintainer's
prescribed structural fix, and fits the repo's Go operational-binary convention
while staying small enough to audit. Approach 2 (mcp-mux) is "less code we
write" but more trust surface and a wrong default; Approach 3 drops browser
tools. The previously-rejected "custom broker" now wins because supergateway is
disqualified and the only off-the-shelf multiplexer is immature and
browser-hostile by default.

### Risks

- **Bespoke broker correctness** — JSON-RPC ID correlation across concurrent
  `tools/call` on one child is the hard part; prove it with the R17 two-workspace
  gate before any remote emission ships.
- **OpenCode remote-client fragility** — `type: "remote"` session handling has
  open bugs (#25137, #38891, #32809); mitigate with a stable loopback child,
  long session timeout, and graceful broker-side session invalidation.
- A second independent browser-automation tool sharing port 9009 would still
  collide; keep BrowserMCP V2-only as it already is.
- The broker adds a localhost HTTP endpoint; bind `127.0.0.1` only, never
  `0.0.0.0`, and fail rather than double-bind an occupied 9008.
- Supervisor restart must not require re-pairing the extension (the extension
  reconnects to the same 9009 server; verify on Linux and Darwin).

### Ready for Proposal

**Yes.** The orchestrator should tell the user: supergateway cannot share one
stdio child across concurrent HTTP clients (stateless = per request, stateful =
per session), and BrowserMCP itself has no HTTP transport, so the definitive
singleton must be a **minimal custom Go stdio-multiplexing broker** — the only
architecture that keeps the exact 12 tools and the already-paired extension
while collapsing all workspaces onto one process. The alternative (adopt the
1-star, browser-hostile-by-default `mcp-mux`) trades 300 lines of our own Go for
a much larger third-party trust surface. One non-blocking decision to confirm at
proposal: authorize the small bespoke Go broker (recommended) versus forbid
bespoke code and accept mcp-mux's risk.
