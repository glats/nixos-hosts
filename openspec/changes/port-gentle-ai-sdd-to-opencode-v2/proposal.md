# Proposal: Port Gentle AI SDD to OpenCode V2

## Intent

Port the Gentle AI runtime to OpenCode V2 native-first: emit native agents, permissions, MCP/Engram, skills, commands, and AGENTS memory context, and write only minimal adapter plugins for genuine gaps. Unsupported V1-only plugins are dropped, not ported. V1 stays byte-identical and the default fallback.

## Scope

### In Scope
- Native V2 emission: skills/commands (COPY), agents/permissions/MCP incl. Engram (REMAP), media, and AGENTS-based memory context.
- 5 minimal adapters for genuine gaps: rtk (shell rewrite), sdd-task-result (envelope), review-transport (reviewer relay), skill-registry (startup refresh), engram (session attribution).
- Drop unsupported V1-only plugins: claude-auth, warden, TUI pair, model-variants, multimodal (native media).
- `docs/opencode-v2-final-cutover.md` — final cutover runbook: migrate isolated `~/.config/opencode-v2` + `~/.local/opencode-v2` to natural default XDG roots, preserving config, sessions, credentials.

### Out of Scope
- V1 runtime scaffold + provider allowlist (sibling changes).
- Flipping V2 to default (deferred until full SDD + reviewer round-trip passes on all 4 hosts).
- Re-implementing dropped plugins as V2 adapters.
- Porting `gentle-ai`, `engram`, `rtk` Go binaries (version-agnostic).

## Capabilities

### New Capabilities
- `opencode-v2-gentle-ai-runtime`: native V2 emission + 5 minimal adapters + plugin drop set, V1 byte-identical fallback. Existing spec's "rewrite six plugins" requirement is superseded; sdd-spec MUST reset it.

### Modified Capabilities
None.

## Approach

Native-first (exploration Approach 1), ordered by risk: (P1) COPY skills/commands + native media; (P2) REMAP agents/permissions/MCP + `cli.json`; (P3) 5 minimal adapters (rtk → sdd-task-result → skill-registry → review-transport → engram); (P4) drop dispositions + cutover doc. V1 branch untouched throughout.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `shared/opencode/runtime-config.nix` | Modified | V2 native emission + adapter deployment |
| `shared/opencode.nix` | Modified | V2 asset copy + adapter activation |
| `shared/opencode/v2-{agents,permissions,mcps}.nix` | New | V2-shaped emitters |
| `shared/opencode/{agents,permissions,mcps-base,plugins}.nix` | Modified | V2 toggles; plugins shrink to 5 adapters |
| `shared/opencode/rtk-v2.ts` | New | V2 adapter (V1 `rtk.ts` byte-preserved) |
| `pkgs/{gentle-ai,engram}-assets/` | Modified | V2 adapter sources (`opencode-v2/plugins/`) |
| `pkgs/opencode-npm-packages-v2/` | New | `@opencode/plugin` only (SDK/client dropped) |
| `docs/opencode-v2-final-cutover.md` | New | Final cutover runbook |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Warden audit-logging lost (native policies deny only) | High | Document gap; accept for V2 |
| Pinned 2.0.14 API drift vs docs | Med | Verify hook domains per adapter at apply |
| Engram session attribution scope unverified | Med | Native MCP sessionID + AGENTS; shrink adapter |
| Permission remap loosens coverage | Med | Per-agent deny smoke |
| V1 byte-identity regression | Low | `diff -r` per slice |

## Rollback Plan

Revert the generator diff per slice; V1 is untouched throughout (byte-identical). Disable `home.opencode.v2.enable` to restore the pre-change V2 state independently.

## Dependencies

- `migrate-opencode-v1-to-v2` (parent), `port-opencode-v2-provider-allowlist` (consume only).
- `@opencode/plugin` (2.0.14); `gentle-ai`/`engram`/`rtk` Go binaries (version-agnostic).

## Success Criteria

- [ ] V1 `opencode.json` + assets byte-identical; `opencode` launches all features.
- [ ] `opencode2` lists 10 SDD + 3 JD + 6 review + orchestrator/neutral/managed; 7 MCPs connect; skills advertised.
- [ ] 5 adapters load; rtk fires on bash; engram mem ops succeed.
- [ ] Dropped plugins absent: no claude-auth, warden, TUI, or model-variants emission.
- [ ] Cutover doc exists under `docs/` covering config/sessions/credentials preservation.
- [ ] `nix flake check --no-build` + per-host evals pass.
