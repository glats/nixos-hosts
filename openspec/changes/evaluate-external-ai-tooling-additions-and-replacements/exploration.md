# Exploration: evaluate-external-ai-tooling-additions-and-replacements

## Research limitation (recorded)

Context7 was attempted first and returned **"Monthly quota exceeded"**
(identical to the prior `integrate-jev-opencode-harness` exploration), so no
Context7 library lookups could be completed. Every canonical-source / license /
platform claim below is instead backed by **GitHub** (search + file contents),
**Exa** (web search), and the repo's own configuration. No other provider was
unavailable.

## Current State (repository evidence)

The repo already runs a mature, declaratively-generated AI-tooling stack on all
four hosts, driven by Home Manager modules under `shared/`:

- **Coding harnesses (already installed):** OpenCode (`shared/opencode.nix` +
  `shared/opencode/*`, active provider `opencode-go-full` on Linux /
  `anthropic-opencode-free` on macm5) and Claude Code (`flake.nix`
  `claude-code-nix` input → `shared/claude-code.nix`). Codex is **already
  present as a binary** on Linux dev hosts (`linux/system/base/profiles/dev.nix:36`,
  alongside `opencode` and `openfang`) but is not wired into any profile/keys/MCP.
- **MCP framework:** `home.ai-assets.mcps` (base, `shared/opencode/mcps-base.nix`)
  merged with `home.ai-assets.extraMcps` (platform extras). Base MCPs on every
  host: `github-personal`, `github-work`, `nixos`, `context7`, `engram`,
  `browsermcp`, `exa`. Darwin-only extras (`darwin/home/opencode/mcps-extra.nix`):
  `drawio`, `playwright` (`@playwright/mcp`), `gcloud`, `atlassian`
  (official Rovo `https://mcp.atlassian.com/v2/mcp`), `chrome-devtools`,
  `mcp-xlsx`. The **same merged set feeds both OpenCode and Claude Code**
  (`shared/claude-code.nix:22` — no per-tool split).
- **Assistant / agent services (already present):** `shell-gpt` (`sgpt`, nvidia
  NIM nemotron-3-ultra) in `shared/shell-gpt.nix`; **OpenFang**
  (`linux/home/openfang.nix`) — an always-on Telegram-connected coding agent
  with a systemd user service + `opencode-go-proxy` + command allowlist.
- **Terminal multiplexer:** `shared/tmux.nix` (TPM with `tmux-resurrect` +
  `tmux-continuum` + `vim-tmux-navigator`), plus a `tmux-resume` shell alias.
- **Memory:** Engram (MCP + local plugin) — persistent memory for agents.
- **Research:** `exa` (web search) + `context7` (docs) MCPs.
- **Diagrams:** `drawio` MCP (darwin) + drawio desktop (homebrew) +
  `vscode-drawio`, plus the `archify` skill (`adopt-archify-skill` change).
- **Secrets:** sops keys exported at zsh init (`shared/opencode.nix`,
  `shared/sops.nix`): nvidia, groq, cerebras, opencode_go, openrouter, mistral,
  cohere, gemini, cloudflare, huggingface, kilo, aihubmix. **No** perplexity /
  notion / linear / higgsfield keys exist.

Integration classes available in this repo (how a new tool would land):
1. Package in a profile list (`linux/system/base/profiles/*.nix`,
   `darwin/home/packages.nix`) — e.g. `codex`, `opencode`, `openfang`.
2. Flake input + overlay + package — e.g. `claude-code-nix`.
3. MCP entry in `mcps-base.nix` (all hosts) or `mcps-extra.nix` (darwin) —
   `type = "local"` (npx/command array) or `type = "remote"` (url).
4. sops secret + zsh init export — for a new API key.
5. Home Manager module (`shared/<tool>.nix`) with options.
6. systemd user service — for always-on agents (openfang pattern).
7. Go operational binary under `pkgs/nixos-scripts/` — for "custom CLI tasks".

## Per-tool assessment

### 1. Herdr (orchestration) — `herdrdev/herdr`
- **Source/license:** GitHub `herdrdev/herdr`, **Apache-2.0** (verified via repo
  LICENSE). One Rust binary, no Electron.
- **Platform:** macOS (incl. arm64), Linux, Windows — Rust static binary.
- **What it is:** an agent-aware terminal multiplexer + background server that
  detects coding-agent lifecycle (`idle/working/blocked/done`) and exposes a
  socket API so agents can drive panes; SSH remote attach; session persistence.
- **State/network/security:** persistent local session state; SSH remote attach
  is a network ingress surface; agents run as the invoking user; the background
  server owns terminals.
- **Overlap:** tmux (+continuum/resurrect) already gives persistent agent
  sessions; OpenFang already gives an always-on agent. Herdr's differentiator is
  agent-lifecycle detection across multiple harnesses.
- **Replacement vs addition:** Addition (no true equivalent), but partially
  redundant with tmux + openfang.
- **Decision:** **Defer.** Only worth adopting if the user wants multi-agent
  orchestration across opencode/claude/codex on `rog`. Not an MCP; would be a
  new package (Rust, `buildFromGitHub`) or overlay, scoped to Linux.

### 2. Claude Code — Anthropic
- **Source/license:** `@anthropic-ai/claude-code` (npm); **proprietary**
  (Anthropic Commercial Terms), not open source.
- **Platform:** macOS (incl. arm64), Linux, WSL.
- **State/network/security:** `~/.claude` state; cloud API + OAuth/subscription;
  already managed declaratively here (settings.json, `.mcp.json` merge, hooks).
- **Overlap:** OpenCode (primary harness here) + Codex.
- **Replacement vs addition:** **Already integrated** — addition already done.
- **Decision:** **Keep as-is.** No action.

### 3. Codex — OpenAI
- **Source/license:** `openai/codex`, **Apache-2.0** repo; npm `@openai/codex`.
  Binary: `codex-aarch64-apple-darwin.tar.gz` / `codex-aarch64-unknown-linux-musl`.
- **Platform:** macOS 12+, Linux x86_64 + arm64, WSL2 only (no native Windows).
  macOS uses Seatbelt sandbox; Linux has **no default sandbox** (Docker recommended).
- **State/network/security:** `~/.codex`; ChatGPT sign-in; cloud API. Sandbox
  gap on Linux is the notable risk.
- **Overlap:** OpenCode (primary) + Claude Code.
- **Replacement vs addition:** **Binary already present** on Linux dev hosts;
  not integrated (no key export / profile / MCP).
- **Decision:** **Already added as a binary; leave unintegrated** unless the
  user wants a Codex-specific harness profile. No action now.

### 4. OpenCode — sst/opencode
- **Source/license:** open source (MIT), Go, terminal coding agent.
- **Platform:** all (Go). Already the repo's primary harness.
- **Replacement vs addition:** **Already the primary harness.**
- **Decision:** **Keep.** V1→V2 migration already planned under
  `migrate-opencode-v1-to-v2`; any new plugin/MCP must be planned against that.

### 5. Hermes CLI/Desktop — Nous Research
- **Source/license:** `hermes-agent.nousresearch.com`; **MIT**, open source
  (CLI + TUI + Electron desktop + messaging gateway).
- **Platform:** Linux, macOS (incl. arm64), WSL2, Android/Termux. Electron desktop
  for macOS/Windows; CLI/TUI cross-platform.
- **State/network/security:** `~/.hermes` (config, keys, sessions); messaging
  gateway ingests Telegram/Discord/Slack/20+ platforms (large network surface);
  OAuth to Nous Portal; command approval + docker isolation + egress control
  available but must be configured.
- **Overlap:** OpenFang (Telegram agent), shell-gpt (shell assistant), Engram
  (memory), OpenCode/Claude (harness). High overlap with the existing assistant
  layer.
- **Replacement vs addition:** **Replacement candidate** for openfang + shell-gpt
  (consolidates assistant, gateway, memory, skills, MCP) or a new standalone
  assistant.
- **Decision:** **Defer (high-effort consolidation).** If adopted, it should be
  framed as an OpenFang/shell-gpt replacement with an explicit migration of the
  Telegram bot + allowlist policy, not a silent fourth assistant. Large surface
  to secure (gateway ingress, OAuth).

### 6. Perplexity (research) — Perplexity
- **Source/license:** `@perplexity-ai/mcp-server` (npm), **MIT**; official MCP
  (`https://api.perplexity.ai/mcp` remote, or local stdio). Tools:
  `perplexity_search`, `perplexity_ask`, `perplexity_research` (sonar-deep-research).
- **Platform:** any MCP client (Node) — Linux + arm64-darwin.
- **State/network/security:** cloud API; needs `PERPLEXITY_API_KEY`; always-on
  network; research runs can take minutes.
- **Overlap:** `exa` (web search) + `context7` (docs) already present.
- **Replacement vs addition:** **Addition** (deep research beyond exa's search).
- **Decision:** **Optional low-risk add** as a remote MCP in `mcps-base.nix`
  (or darwin extras) + a new `perplexity_api_key` sops secret — only if
  deep-research is valued over the existing exa/context7.

### 7. Playwright CLI testing — Microsoft
- **Source/license:** `playwright` / `@playwright/test`, **Apache-2.0**.
- **Platform:** Linux + macOS (incl. arm64) + Windows; Node.
- **State/network/security:** local browser automation; downloads browser
  binaries (large local state); local-only (no cloud).
- **Overlap:** `@playwright/mcp` **already in darwin extras**; `browsermcp` in
  base (all hosts) covers live-browser automation.
- **Replacement vs addition:** The **MCP is already present** (macm5). If the
  intent is the `@playwright/test` **test runner** (authoring/running browser
  tests), that is a **new addition** (no test-runner package in the repo today).
- **Decision:** **Addition (test runner only), if browser E2E tests are wanted.**
  No new MCP needed — promote/confirm the existing `@playwright/mcp` entry to
  Linux if cross-host automation is desired.

### 8. Notion MCP — Notion
- **Source/license:** `makenotion/notion-mcp-server`, **MIT** — but the local
  repo is **deprecated** in favor of **Remote Notion MCP** (OAuth, hosted,
  markdown page editing).
- **Platform:** any MCP client (remote OAuth) — Linux + arm64-darwin.
- **State/network/security:** remote hosted server; OAuth authorization; grants
  agent read/write to the Notion workspace.
- **Overlap:** none (atlassian MCP on darwin is Jira/Confluence, not Notion).
- **Replacement vs addition:** **Addition.**
- **Decision:** **Add only if the user actively uses Notion** (no evidence they
  do — the repo leans Atlassian/Linear tooling). Requires OAuth, no sops secret.

### 9. Linear MCP — Linear
- **Source/license:** official **remote** MCP at `https://mcp.linear.app/mcp`
  (Streamable HTTP + OAuth 2.1, centrally hosted); read-only endpoint
  `/mcp/readonly` available. Community local servers exist (MIT) but are
  third-party.
- **Platform:** any MCP client (remote OAuth) — Linux + arm64-darwin; SSE
  fallback for WSL.
- **State/network/security:** remote hosted; OAuth scopes (read vs read-write);
  workspace-scoped.
- **Overlap:** none.
- **Replacement vs addition:** **Addition.**
- **Decision:** **Add only if the user uses Linear**; prefer the official remote
  OAuth server (no sops secret, scoped read-only option). Otherwise skip.

### 10. Higgsfield CLI (image/video) — Higgsfield AI
- **Source/license:** npm `@higgsfield/cli` (`higgsfield-ai/cli`); **proprietary
  SaaS** (no OSS license); 40+ cloud image/video/3D models via credits.
- **Platform:** Node/npm → Linux + macOS (incl. arm64).
- **State/network/security:** `higgsfield auth login` token; cloud generation
  (uploads prompts/media); credit-based billing; always-on network.
- **Overlap:** none (no media generation in the repo).
- **Replacement vs addition:** **Addition** (creative media, out of scope for
  config management).
- **Decision:** **Defer / skip** — orthogonal to this repository's purpose.
  Only adopt if the user wants agent-driven media generation.

### 11. Excalidraw MCP (diagrams) — excalidraw
- **Source/license:** `excalidraw/excalidraw-mcp`, **MIT**; remote
  `https://mcp.excalidraw.com` or local node server.
- **Platform:** any MCP client (Node) — Linux + arm64-darwin.
- **State/network/security:** remote host optional; minimal local state.
- **Overlap:** `drawio` MCP (already on darwin) + drawio desktop +
  `vscode-drawio` + the `archify` skill. Diagramming is already well covered.
- **Replacement vs addition:** **Redundant addition** (would duplicate drawio).
- **Decision:** **Skip** — drawio MCP + archify already satisfy diagrams;
  Excalidraw MCP adds no material capability. Only reconsider if the user
  specifically wants Excalidraw's hand-drawn style.

### "Custom CLI tasks"
Any new operational CLI (research fetch, task orchestration, media download)
should follow the existing **Go under `pkgs/nixos-scripts/`** convention, not a
new external tool, per AGENTS.md ("Operational command-line tools are Go, not
shell scripts").

## Affected Areas (if any of the "add" decisions proceed)

- `shared/opencode/mcps-base.nix` — single insertion point for a base MCP
  (perplexity / notion / linear / excalidraw). Flows to all hosts AND to Claude
  Code (shared `mcps` option — name this side effect explicitly).
- `darwin/home/opencode/mcps-extra.nix` — insertion point for a darwin-only MCP
  (playwright already here).
- `shared/sops.nix` + `.sops.yaml` + `secrets/` — new sops secret for
  `perplexity_api_key` (perplexity) if chosen; none for remote-OAuth servers
  (notion/linear) or Herdr/Hermes installs (unless direct-model auth).
- `shared/opencode.nix` — zsh init export for any new API key.
- `linux/system/base/profiles/dev.nix` / `darwin/home/packages.nix` — package
  for a new binary (Herdr, Hermes CLI) or flake-input+overlay (`overlays/*.nix`,
  `flake.nix`) for pinned/non-nixpkgs tools.
- `linux/home/openfang.nix` + `shared/shell-gpt.nix` — affected only if Hermes
  is chosen as a replacement (migration surface).
- `pkgs/nixos-scripts/` — for any new "custom CLI task" (Go).

## Approaches (integration strategy, not per-tool)

1. **MCP-only additions (lowest friction, V2-immune).** Add remote/local MCP
   entries for research/collaboration tools (perplexity, notion, linear). Reuses
   the existing mechanism; immune to the OpenCode V1→V2 plugin-SDK break.
   - Pros: one-file change per tool; universal across OpenCode + Claude Code;
     matches existing `mcps-base.nix` / `mcps-extra.nix` patterns.
   - Cons: shared `mcps` option surfaces each into both harnesses; OAuth/API-key
     secrets; no pre-execution gating.
   - Effort: Low.

2. **Package/overlay additions.** Herdr (Rust), Hermes CLI (Node/Electron) as
   new packages or flake inputs.
   - Pros: real binaries, reproducible if pinned.
   - Cons: non-trivial packaging (Electron Hermes especially); adds a network/
     state surface; overlaps tmux/openfang.
   - Effort: Medium–High.

3. **Assistant consolidation (Hermes as OpenFang/shell-gpt replacement).**
   - Pros: collapses three assistants into one MIT, self-improving agent.
   - Cons: large security surface (gateway ingress, OAuth); migration of Telegram
     bot + allowlist policy; high effort; risk of regression in an already-working
     OpenFang.
   - Effort: High.

4. **Go operational CLI (custom tasks).** Any bespoke research/orchestration
   task as a Go binary under `pkgs/nixos-scripts/`.
   - Pros: repo convention; testable (`go test ./...`); no external dependency.
   - Cons: only appropriate for deterministic tasks, not interactive agents.
   - Effort: Medium.

## Recommendation

Treat this as a **filter, not a build-out**. The repo already covers the
harness (OpenCode + Claude Code + Codex binary), the assistant layer
(shell-gpt + OpenFang), memory (Engram), research (exa/context7), browser
automation (browsermcp + playwright MCP on darwin), and diagrams (drawio +
archify). Only three of the eleven proposals are net-new capabilities with
clear value and low risk:

- **Perplexity** (deep research) — optional remote MCP + one sops secret.
- **Notion MCP** / **Linear MCP** — remote OAuth additions, gated on the user
  actually using those products (no current evidence).
- **Playwright `@playwright/test`** — only as a test runner if browser E2E
  testing is wanted (the MCP already exists on macm5).

**Reject or defer:** Herdr (redundant with tmux+openfang), Hermes (only as an
explicit OpenFang/shell-gpt replacement, high effort), Higgsfield (out of
scope), Excalidraw (redundant with drawio/archify), Claude Code / Codex /
OpenCode (already present — no action).

Each approved tool should be a **separate independent change** (mirroring the
existing one-change-per-tool convention: `browser-mcp-opencode`,
`integrate-jev-opencode-harness`), each with its own proposal/spec/design/tasks.

## Risks

- **Shared MCP side effect:** any base-MCP addition also registers in Claude
  Code (`shared/claude-code.nix:22`) — must be named and accepted per change.
- **OpenCode V1→V2 migration:** new plugins/MCPs must be planned against
  `migrate-opencode-v1-to-v2` (plugin SDK `@opencode-ai/plugin` →
  `@opencode/plugin`); MCP-only additions are immune, plugins are not.
- **Secret hygiene:** perplexity needs a sops key (specific `.sops.yaml` rule
  before generic host rules); remote-OAuth servers (notion/linear) need browser
  OAuth but no stored secret.
- **Network/state surface:** Hermes gateway (20+ messaging platforms) and
  Herdr SSH attach materially widen ingress; OpenFang already exposes a
  Telegram bot — consolidation must preserve its allowlist/approval policy.
- **Codex Linux sandbox gap:** Codex has no default sandbox on Linux
  (Seatbelt only on macOS); if it ever becomes an integrated harness, sandboxing
  must be added (Docker/iptables) per the Codex docs.
- **SaaS/proprietary lock-in:** Higgsfield (credits, cloud-only) and Claude Code
  (proprietary) are not reproducible in the Nix store; they are acceptable only
  as opt-in user tools, not load-bearing dependencies.

## Ready for Proposal

**Partially.** This is a portfolio evaluation, not a single change. The
orchestrator should tell the user:

1. Three of the eleven proposals are already present (Claude Code, Codex
   binary, OpenCode) — no work.
2. Four are redundant or out of scope (Herdr, Higgsfield, Excalidraw, and —
   unless replacing OpenFang — Hermes) — recommend no action.
3. Four are genuine low-risk additions gated on intent: **Perplexity** (research),
   **Notion MCP**, **Linear MCP** (only if those products are used), and
   **Playwright test runner** (only if browser E2E testing is wanted; the MCP
   already exists on macm5).
4. For each approved tool, open a **separate SDD change** (proposal → spec →
   design → tasks) rather than one monolithic change.
