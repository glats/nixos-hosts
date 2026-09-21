## Exploration: rebuild-agent-context (focused surface-area audit)

## Decision Resolution: Does Claude Code read AGENTS.md? — NO (primary-source verified)

### Verified answer

**No.** Current Claude Code does **not** automatically read `AGENTS.md` — not natively, not as a fallback. Official Anthropic documentation (code.claude.com/docs/en/memory, "AGENTS.md" section) states verbatim: *"Claude Code reads `CLAUDE.md`, not `AGENTS.md`."* Instruction-file discovery loads only `CLAUDE.md` / `CLAUDE.local.md` (user `~/.claude/CLAUDE.md`, project `./CLAUDE.md` / `./.claude/CLAUDE.md`, ancestor directories at launch; subdirectory files on demand) plus `.claude/rules/*.md`. `AGENTS.md` is absent from every load path.

Native support has **never shipped**. `anthropics/claude-code#6235` ("Support AGENTS.md", 5,168 👍, opened 2025-08-21) was closed `completed` on **2026-08-17** — but closed by documenting interop tooling, not by changing discovery: the `@AGENTS.md` import line at the top of a `CLAUDE.md`, a `ln -s AGENTS.md CLAUDE.md` symlink, and the `/import` command (v2.1.213+). The literal native-support ask `#34235` ("support AGENTS.md as a native context file alongside CLAUDE.md", opened 2026-03-14) remains **open**. `#78977` (2026-07-19) states flatly "Claude Code still does not natively read AGENTS.md." The `/init` (with `CLAUDE_CODE_NEW_INIT=1`) and `/import` paths read `AGENTS.md` only as a one-time generation/copy step, not as session loading.

**"Gen5" is irrelevant here.** Instruction-file discovery is a Claude Code *CLI loader* feature, independent of the model generation driving the session (Sonnet/Opus/Gen5). No model generation changes which files the loader reads.

### Decisive recommendation

Claude should receive a **generated `~/.claude/CLAUDE.md`** — not the root `AGENTS.md` directly (Claude never auto-reads it), not both (duplication), not neither (violates the confirmed requirement). The root `<repo>/AGENTS.md` stays the single Nix-repo-factual source of truth; Claude reaches it through the existing generation pipeline in `shared/claude-code.nix` (activation concatenates `config.home.ai-assets.agentsMdSources` → `~/.claude/CLAUDE.md`).

**New critical finding.** Claude Code today receives **zero** repo-factual context: `~/.claude/CLAUDE.md` is built solely from the foreign gentle-ai skills index + `explore-mcp.md` + `output-format.md`. The 185-line NixOS `AGENTS.md` (commands, critical rules, Go-only policy, sops, Omarchy) never reaches Claude. The confirmed requirement ("Claude Code must receive minimal repository context") is therefore **currently unmet**, and the fix is to repoint `agentsMdSources` at the repo facts.

### Exact files that must change

- `shared/ai-assets.nix` — **REQUIRED.** Repoint `agentsMdSources` from `[${pkgs.gentle-ai-assets}/.../AGENTS.md, ./rules/explore-mcp.md, ./rules/output-format.md]` to `[ ../AGENTS.md ]` (the trimmed root, relative to `shared/`). This single change routes the repo facts into `~/.claude/CLAUDE.md`.
- `<repo>/AGENTS.md` — **REQUIRED** (already in scope). Trim to the ~85-line repo-factual document; it is the shared source of truth for both tools.
- `shared/opencode/runtime-config.nix` — **REQUIRED** (anti-duplication). The `ag_md` loop (L249–255) must stop emitting the root `AGENTS.md` into `~/.config/opencode/AGENTS.md`, because OpenCode already auto-reads `<repo>/AGENTS.md` as its project file; leaving both would double-load the same facts for OpenCode. Empty the generated global file (drop the loop or its sources).
- `shared/claude-code.nix` — **VERIFY-ONLY, no edit.** Already concatenates `agentsMdSources` → `~/.claude/CLAUDE.md` (L306–312); the repoint propagates automatically.
- `shared/opencode/agents.nix` — **REQUIRED** (already in scope, independent of this decision). Repoint `basePrompt` and `neutral` away from store-path `builtins.readFile`.

Variant (same effect, more explicit): keep `agentsMdSources` empty for OpenCode and add a dedicated `claudeMdSources` option read by `claude-code.nix`. Rejected as unnecessary — the existing option description already reads "Ordered AGENTS.md/CLAUDE.md fragments to concatenate" and the `claude-code.nix` comment already declares `agentsMdSources` as its CLAUDE.md source; a second option adds a lever without reducing coupling.

### Constraint preservation

Nix-repo-factual context only: the root `AGENTS.md` is already pure NixOS facts. The foreign skills index, the `explore-mcp.md`/`output-format.md` rule fragments, and the persona prompt are all dropped from the always-on surfaces; the two rule fragments remain owned by the frozen `instructionOverlays`, the sole injectors for OpenCode agents.

### Current State

OpenCode's always-on agent context is assembled from two auto-loaded instruction files plus per-agent prompt strings, and the same fragment sources additionally feed Claude Code. This audit enumerates every repository file that can (a) be auto-read by an agent, (b) be injected into prompts/configuration, (c) be surfaced as a skill/command/plugin/rule, or (d) otherwise materially affect agent context — then classifies each against the compact repo-factual goal.

**Two auto-loaded instruction files** (OpenCode V2 combines them; it recognizes `AGENTS.md` only, not `CLAUDE.md`, and does not resolve conflicts between global and project files — opencode.ai/v2/docs/instructions):

1. **Project file `<repo>/AGENTS.md`** — 185 lines, repo-owned and committed. The genuinely NixOS-grounded rules file (hosts, commands, critical rules, Go-only-scripts policy, sops policy). Scattered Omarchy references (Overview L5, Critical Rule L161, Owned Repos L185) but no dedicated section.
2. **Global file `~/.config/opencode/AGENTS.md`** — generated by the `ag_md` concatenation loop in `shared/opencode/runtime-config.nix`, sourcing `config.home.ai-assets.agentsMdSources` (defined in `shared/ai-assets.nix`). Today its content is NOT repo-owned: the upstream **"Gentle AI — Agent Skills Index"** (`${pkgs.gentle-ai-assets}/share/gentle-ai/AGENTS.md`, with paths relative to the `gentle-ai` repo that do not resolve here) + `shared/rules/explore-mcp.md` + `shared/rules/output-format.md`.

**Per-agent prompt strings** (`shared/opencode/agents.nix`), emitted into the generated `~/.config/opencode/opencode.json`:

- `gentle-orchestrator` prompt = `basePrompt` (`builtins.readFile` of the upstream gentle-ai `AGENTS.md` skills index) + `instructionOverlays.gentle-orchestrator` (`explore-mcp.md` + `output-format.md`).
- `neutral` (primary) prompt = upstream `persona-gentleman.md` ("Senior Architect mentor") — not a NixOS fact. `neutral` receives NO `instructionOverlay`.
- every `subagent` prompt = upstream prompt + `instructionOverlays.subagent` (`output-format.md`).
- `managed-writing-task` — a repo-owned primary agent whose prompt is inline in `agents.nix`.

**Net duplication** (verified against the materialized layers): the gentle-ai skills index is injected **twice** (global file + orchestrator `basePrompt`); `output-format.md` **three times** (global file + orchestrator overlay + subagent overlay); `explore-mcp.md` **twice** (global file + orchestrator overlay). `shared/opencode/runtime-config.nix` emits `instructions = [ ]` into `opencode.json`, which is inert in OpenCode V2 (accepted but not resolved), so the only always-on surfaces are the two AGENTS.md files and the `agent.*.prompt` strings.

**Cross-tool consumption (new finding).** `agentsMdSources` is consumed by TWO tools, not one. `shared/claude-code.nix` (enabled via `shared/claude-code-profile.nix`, imported on every Linux and Darwin host) builds `~/.claude/CLAUDE.md` from the **same** `config.home.ai-assets.agentsMdSources` (comment at `shared/claude-code.nix:113`: "Custom rules are injected via CLAUDE.md (agentsMdSources in ai-assets.nix)"). The same list also drives `~/.claude/skills/` and `~/.claude/output-styles/`. Any edit to `agentsMdSources` therefore changes both `~/.config/opencode/AGENTS.md` and `~/.claude/CLAUDE.md` — the change is not OpenCode-only, and the proposal currently names only OpenCode surfaces.

**Rule-fragment orphan (new finding).** `shared/rules/review-gate.md` ("SDD Review Gate") is a rule fragment that is NOT wired anywhere: it is not in `agentsMdSources`, not in any `instructionOverlays` entry, and referenced by no Nix file (grep confirms only `docs/oh-my-openagent.md` and archive reports mention the string). It is inert today and neither injects nor should inject anything.

**Skills (on-demand, advertised to the model).** Two repo-owned skill sources exist: `shared/skills/rom-downloader/SKILL.md` (deployed directly to `~/.config/opencode/skills`, `~/.claude/skills`, and `~/.agents/skills` via `shared/skills.nix` — a "legacy direct deployment exception") and `shared/assets/skills/{git-feature-flow,model-fit,nix-verify,opencode-session-recovery,tool-adoption}/SKILL.md` (packaged by `pkgs/local-ai-assets` from `src = ./../../shared/assets/skills`, then unioned into the same three skill dirs via the `skillSources` loop). These are advertised (ID + name + description) but loaded on demand; they are not always-on context. Upstream skill sources (`gentle-ai-assets`, `caveman-assets`, `ponytail-assets`) plus the same `skillSources` list also feed `~/.claude/skills/`.

**Commands.** `~/.config/opencode/commands/` is assembled in `runtime-config.nix` from `opencodeCommandSources` — all upstream (`gentle-ai`, `caveman`, `ponytail`). There is no repo-owned commands directory.

**Plugins.** Repo-owned `shared/opencode/rtk.ts` (RTK shell-output rewriting) is one of six managed plugins copied into `~/.config/opencode/plugins/` by `runtime-config.nix`; the other five (model-variants, opencode-review-transport, sdd-task-result-artifacts, skill-registry, engram) come from upstream asset packages. `shared/opencode/plugins.nix` also lists `npmPlugins = [ opencode-claude-auth, opencode-multimodal, opencode-warden ]`.

**MCP servers.** `shared/opencode/mcps-base.nix` defines seven (github-personal, github-work, nixos, context7, engram, browsermcp, exa); `darwin/home/opencode/mcps-extra.nix` adds six macOS-only (drawio, playwright, gcloud, atlassian, chrome-devtools, mcp-xlsx). Tool schemas are injected into every model request — a large token surface, but not instruction text.

**Providers.** `shared/opencode/providers-base.nix` maps SDD phase → model strings per routing profile; `shared/opencode/providers.nix` resolves the active profile from `home.opencode.activeProviderName` (overridden per host in `hosts/*/home/default.nix` and `hosts/macm5/default.nix`). Its extensive Spanish comments are Nix comments, never read into any prompt.

### Affected Areas

- `shared/ai-assets.nix` — `agentsMdSources` default; the single lever for the generated global `AGENTS.md` **and** `~/.claude/CLAUDE.md`. PROPOSED.
- `<repo>/AGENTS.md` (185 lines) — repo-owned always-on context to trim, with a new concise Omarchy section. PROPOSED.
- `shared/opencode/agents.nix` — `basePrompt` (orchestrator), `neutral` prompt, and the inline `managed-writing-task` prompt. PROPOSED.
- `shared/opencode/runtime-config.nix` — the `ag_md` loop, skills union, commands union, plugin copy. Mechanics unchanged; consumes the updated `agentsMdSources`.
- `shared/rules/{explore-mcp,output-format}.md` — the two wired rule fragments; ownership changes but content does not.
- `shared/rules/review-gate.md` — unwired orphan fragment; neither injects nor is touched.
- `shared/opencode/local-agent-overlays.json` — `instructionOverlays`; per the proposal it remains the sole injector of the two fragments (NOT edited).
- `shared/claude-code.nix` — second consumer of `agentsMdSources`; behaviour changes as a direct consequence.
- `hosts/t14/omarchy-config.nix`, `hosts/t14/home/omarchy.nix`, `linux/home/shared-modules.nix`, `flake.nix` — read-only sources for the Omarchy facts that must survive the trim.

Out of scope (per the clarified goal): skills and `skillSources` (`shared/skills.nix`, `shared/assets/skills/*`, `pkgs/local-ai-assets/default.nix`), commands (`opencodeCommandSources`), plugins (`shared/opencode/plugins.nix`, `shared/opencode/rtk.ts`), the SDD agent graph (`sdd-overlay-single.json` upstream), MCP wiring (`mcps-base.nix`, `mcps.nix`, `darwin/home/opencode/mcps-extra.nix`), provider routing (`providers.nix`, `providers-base.nix`), permissions (`permissions.nix`), and Nix overlays (`overlays/`).

### Approaches

1. **Narrow content rebuild (repo-owned context only)** — Edit three text surfaces: (a) `agentsMdSources` → repo-only (drop the upstream skills index and the two rule fragments, which the frozen overlays already inject); (b) `<repo>/AGENTS.md` → ~85 lines of NixOS facts + a dedicated Omarchy section; (c) orchestrator `basePrompt` and `neutral` prompt → repo-grounded strings (with `neutral` carrying the formatting contract one-liner, since `neutral` has no overlay). No skill/plugin/MCP/overlay restructuring.
   - Pros: directly satisfies the clarified goal; kills the foreign skills index injected twice; bounded and reversible.
   - Cons: `agentsMdSources → []` also empties `~/.claude/CLAUDE.md` (Claude Code loses its rule injection — it has no overlay mechanism); verification must cover both tools; the `neutral` formatting contract must be re-established in its prompt.
   - Effort: Low–Medium.

2. **Broader prune (skills + MCP + overlays)** — The prior exploration's Approach 3 (drop caveman/ponytail/rom-downloader skills, trim `mcps-base.nix`, change overlays). Out of scope; rejected per the clarified instruction.

### Recommendation

Approach 1 — **narrow content rebuild** — because the clarified goal is exclusively about the always-on context *text*. The external evidence is unambiguous: the ETH Zurich "Evaluating AGENTS.md" study (Gloaguen et al.) found auto-generated context files *reduce* task success (~3%) while adding ~20% inference cost, and broad architectural/structure sections hurt rather than help; the highest-signal content is commands, constraints, and non-standard patterns. The QoderAI review sets a concrete budget: a root instruction file ≤80 lines is healthy, >180 is overloaded. The 185-line `AGENTS.md` and the 80-line global file (of which ~40 lines are a dead skills index for a different repo) both overshoot.

**Exact minimal repository-owned context content** (the deliverable) — reduce `<repo>/AGENTS.md` to ≈85 lines: Overview (hosts/users/stack/symlink); Commands (build/deploy, tiered verification, formatting, Go scripts); Critical Rules (flat imports, Go-only scripts, sops, hardware-configuration, pin 26.05, overlays imported not modules, formatter); a concise factual Omarchy Nix section (pinned fork `github:glats/omarchy-nix`; only t14 runs it via `extraModules`; `hosts/t14/home/omarchy.nix` imports the HM default; `btop` HM module is shared on all Linux hosts; `hosts/t14/omarchy-config.nix` option values; `t14QuattroOverlay` exposes `omarchy-runtime`/`quickshell` only to t14); and the language contract folded once. Cut: the ~10-line RTK prose (compress to ~2 lines), the full `Project Structure` tree (keep only non-obvious bits), the `When Blocked` table, and any formatting prose duplicated from `output-format.md`.

**Assembly changes** (text only): `agentsMdSources` drops the upstream skills-index store path and the two rule fragments; `agents.nix` re-points `basePrompt` and `neutral` from store-path `builtins.readFile` to repo-grounded strings. The frozen `instructionOverlays` remain the sole injectors of `explore-mcp.md` (orchestrator) and `output-format.md` (orchestrator + subagents).

### Risks

- **Cross-tool blast radius (resolved).** `agentsMdSources` must NOT be emptied: it is the sole channel by which Claude Code receives any instruction content (Claude Code reads `CLAUDE.md`, not `AGENTS.md`, so it has no overlay path). The resolution is to repoint `agentsMdSources` to the root `AGENTS.md` so `~/.claude/CLAUDE.md` carries the repo facts, and to empty OpenCode's generated global `AGENTS.md` in `runtime-config.nix` (OpenCode already auto-reads the root `AGENTS.md`, so re-emitting it would double-load). `output-format.md`/`explore-mcp.md` stay owned by the overlays, never re-entering `agentsMdSources`.
- **`neutral` formatting-contract gap.** `neutral` has no `instructionOverlay`; dropping `output-format.md` from `agentsMdSources` removes the contract from `neutral` unless its repo-grounded prompt carries the one-liner (proposal mitigates, but it must be verified in the materialized `opencode.json`).
- **`instructionOverlays` boundary** — `local-agent-overlays.json` must NOT change; confirm the "one injection per fragment" invariant holds with overlays as sole injectors.
- **Orchestrator prompt regression** — dropping the orchestrator `basePrompt` skills index is safe only if SDD behaviour does not depend on that prose (skills load on demand from `~/.config/opencode/skills/`, not the index text).
- **`review-gate.md` orphan** — currently unwired; neither a risk nor a target for this change, but if a future change wires it, it reintroduces an SDD reference into context. Flag, do not act.
- **Omarchy staleness** — the section cites a pinned commit and per-host option values; keep it short and factual.
- **Verification cost** — a host build is required to inspect the materialized `opencode.json` `agent.*.prompt`, the generated `AGENTS.md`, and `~/.claude/CLAUDE.md`; `nix flake check --no-build` alone will not reveal prompt duplication.

### Ready for Proposal

Yes. Proceed with Approach 1. Both previously-open decisions are now **resolved** by the primary-source verification above: (1) the `~/.claude/CLAUDE.md` side-effect must be an **intentional, populated** repo-factual file — Claude Code does not read `AGENTS.md`, so emptying `agentsMdSources` would starve Claude of the required minimal repo context; therefore (2) `output-format.md` is dropped from `agentsMdSources` (the overlays own it exclusively), and `agentsMdSources` is repointed to the root `AGENTS.md` so `~/.claude/CLAUDE.md` carries the repo facts.

### Additional files to update

Beyond the three proposed files (`AGENTS.md`, `shared/ai-assets.nix`, `shared/opencode/agents.nix`), the repository files that can materially affect agent context are classified as follows. "Required" means the compact repo-factual change is incomplete without it; "Verify-only" means no edit is needed but the change's correctness depends on confirming its behaviour; "Out of scope" means it surfaces context but the change intentionally leaves it untouched.

**Required**

- The four files named in "Decision Resolution → Exact files that must change": `<repo>/AGENTS.md` (trim), `shared/ai-assets.nix` (`agentsMdSources` → `[ ../AGENTS.md ]`), `shared/opencode/runtime-config.nix` (empty the generated global `AGENTS.md` so OpenCode does not double-load the root file it auto-reads), and `shared/opencode/agents.nix` (`basePrompt` + `neutral` repo-grounded).

**Verify-only** (no edit; must be confirmed during apply/verify)

- `shared/claude-code.nix` — second consumer of `agentsMdSources`; builds `~/.claude/CLAUDE.md` and `~/.claude/skills/`. No edit; confirm the repointed `agentsMdSources` propagates the repo facts into `~/.claude/CLAUDE.md` and that the spec names Claude Code explicitly.
- `shared/opencode/local-agent-overlays.json` — must remain unchanged; confirm overlays are the sole injectors of `explore-mcp.md` (orchestrator) and `output-format.md` (orchestrator + subagents) and that `neutral`'s formatting contract comes from its prompt.
- `shared/rules/output-format.md` — content unchanged; confirm exactly one owner per agent after the drop.
- `shared/rules/explore-mcp.md` — content unchanged; confirm it reaches only the orchestrator.
- `shared/rules/review-gate.md` — unwired orphan; confirm it stays unwired and is not accidentally surfaced (do not edit).
- `docs/rtk-pilot.md`, `docs/sops-new-host.md`, `docs/multi-github-identity.md`, `docs/wg-peer.md` — referenced by the current `AGENTS.md`; only relevant if the trimmed `AGENTS.md` keeps their references (on-demand reads, never auto-loaded).
- Generated files (not in repo): `~/.config/opencode/{opencode.json,AGENTS.md,skills,commands,plugins}`, `~/.claude/{CLAUDE.md,skills,agents,commands,output-styles,settings.json}` — verification targets for the materialized `agent.*.prompt` strings and both global instruction files.

**Out of scope** (surfaces context, intentionally untouched)

- `shared/skills.nix` and `shared/skills/rom-downloader/SKILL.md` — repo-owned skill deployed to opencode/claude/agents skill dirs; advertised on demand.
- `shared/assets/skills/{git-feature-flow,model-fit,nix-verify,opencode-session-recovery,tool-adoption}/SKILL.md` and `pkgs/local-ai-assets/default.nix` — repo-owned skills packaged via `local-ai-assets`.
- `shared/opencode/plugins.nix` and `shared/opencode/rtk.ts` — plugin enable flags + the repo-owned RTK plugin.
- `shared/opencode/mcps-base.nix`, `shared/opencode/mcps.nix`, `darwin/home/opencode/mcps-extra.nix` — MCP tool-schema injection.
- `shared/opencode/providers-base.nix`, `shared/opencode/providers.nix` — model routing; comments are Nix-only, never injected.
- `shared/opencode/permissions.nix` — default bash/read/external_directory permission rules.
- `shared/opencode.nix`, `shared/opencode-profile.nix`, `shared/claude-code-profile.nix` — module wiring (enable flags, `disabledTools`, `compaction`, `activeProviderName`).
- `hosts/*/home/default.nix`, `hosts/macm5/default.nix` — per-host `home.opencode.activeProviderName` overrides.
- `flake.nix`, `lib/packages.nix`, `pkgs/gentle-ai-assets`, `pkgs/caveman-assets`, `pkgs/ponytail-assets`, `pkgs/engram-assets`, `pkgs/opencode-npm-packages` — upstream asset sources (the origin of the foreign content being dropped).

Sources: Context7 — quota exceeded this run (unavailable; official OpenCode docs used instead). **Claude Code / AGENTS.md decision (primary):** Anthropic official docs `code.claude.com/docs/en/memory` ("AGENTS.md" section — *"Claude Code reads `CLAUDE.md`, not `AGENTS.md`"*; load-order table: user `~/.claude/CLAUDE.md`, project `./CLAUDE.md`/`./.claude/CLAUDE.md`, `CLAUDE.local.md`, `.claude/rules/*.md`; `@AGENTS.md` import + symlink interop; `/init` with `CLAUDE_CODE_NEW_INIT=1` reads AGENTS.md only at generation time). GitHub MCP `get_me`=glats; `anthropics/claude-code#6235` (closed `completed` 2026-08-17 via import/`/import` tooling, not native discovery), `#34235` (native support, still open), `#78977` ("still does not natively read AGENTS.md"). OpenCode V2 docs `opencode.ai/v2/docs/instructions`, `opencode.ai/v2/docs/skills`, `opencode.ai/v2/docs/agents` (AGENTS.md-only, global+project combined, `instructions` array unresolved) and `opencode.ai/docs/rules`. Prior art `anomalyco/opencode#6316`. Gloaguen et al. "Evaluating AGENTS.md" (ETH Zurich) (−3% success/+20% cost). QoderAI `agents-md-review.md` (root ≤80 healthy, >180 overloaded). `henrysipp/omarchy-nix` (800★, DHH's Omarchy).
