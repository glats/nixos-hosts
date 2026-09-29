# Proposal: Port Gentle AI SDD to OpenCode V2

## Intent

Port the Gentle AI runtime to OpenCode V2 native-first: emit native agents, permissions, MCP/Engram, skills, commands, and AGENTS memory context; write only minimal adapter plugins for genuine gaps; drop unsupported V1-only plugins. V1 stays byte-identical and the default fallback.

BrowserMCP's fixed-port singleton uses a **minimal custom Go stdio-multiplexing broker** (`browsermcp-broker`), replacing the disqualified supergateway plan: one patched BrowserMCP child, loopback Streamable HTTP, JSON-RPC multiplexing, remote V2 MCP emission, systemd/launchd supervision.

## Scope

### In Scope
- Native V2 emission: skills/commands (COPY), agents/permissions/MCP incl. Engram (REMAP), media, AGENTS context.
- 5 minimal adapters: rtk, sdd-task-result, review-transport, skill-registry, engram.
- Drop V1-only plugins: claude-auth, warden, TUI pair, model-variants, multimodal.
- BrowserMCP singleton: broker binary + kill-on-port patch + supervised unit + remote emission.
- `docs/opencode-v2-final-cutover.md` runbook.

### Out of Scope
- V1 runtime scaffold + provider allowlist (sibling changes).
- Flipping V2 to default (deferred until SDD + reviewer round-trip on all 4 hosts).
- Re-implementing dropped plugins; porting `gentle-ai`/`engram`/`rtk` Go binaries.
- supergateway and off-the-shelf multiplexers (mcp-mux) — both rejected.

## Capabilities

### New Capabilities
- `opencode-v2-gentle-ai-runtime`: native V2 emission + 5 adapters + drop set + BrowserMCP singleton broker, V1 byte-identical fallback. sdd-spec MUST correct the `BrowserMCP Singleton Streamable-HTTP Transport` requirement (still names supergateway) to `browsermcp-broker`.

### Modified Capabilities
None.

## Approach

Native-first, ordered by risk: (P1) COPY skills/commands + media; (P2) REMAP agents/permissions/MCP + `cli.json`; (P3) 5 adapters; (P4) drops + cutover doc. BrowserMCP singleton (R14-R24): neutralize kill-on-port, build broker, supervise, emit remote, prove two-workspace concurrency. V1 untouched throughout.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `pkgs/nixos-scripts/cmd/browsermcp-broker/` + `internal/browsermcp/` | New | Go stdio-multiplexing broker |
| `pkgs/browsermcp-v2/` | Modified | Add kill-on-port neutralization |
| `shared/opencode.nix` | Modified | `browserMcp.bridgePort/bridgePackage`; systemd/launchd unit |
| `shared/opencode/v2-mcps.nix`, `runtime-config.nix` | Modified | Emit `type:"remote"` loopback URL; zero local entries |
| `shared/opencode/runtime-config.nix` | Modified | V2 native emission + adapter deployment |
| `shared/opencode/v2-{agents,permissions,mcps}.nix` | New | V2-shaped emitters |
| `shared/opencode/{agents,permissions,mcps-base,plugins}.nix` | Modified | V2 toggles; plugins shrink to 5 adapters |
| `shared/opencode/rtk-v2.ts` | New | V2 adapter (V1 `rtk.ts` byte-preserved) |
| `pkgs/{gentle-ai,engram}-assets/`, `pkgs/opencode-npm-packages-v2/` | Modified/New | V2 adapter sources; `@opencode/plugin` only |
| `docs/opencode-v2-final-cutover.md` | New | Cutover runbook |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Broker JSON-RPC ID correlation wrong | Med | R17 two-workspace gate before remote emission |
| OpenCode `type:"remote"` client fragility (#25137/#38891) | Med | Stable loopback child, long timeout, graceful invalidation |
| Warden audit-logging lost | High | Document gap; accept for V2 |
| Engram session attribution unverified | Med | Native MCP sessionID + AGENTS; shrink adapter |
| V1 byte-identity regression | Low | `diff -r` per slice |

## Rollback Plan

`home.opencode.v2.browserMcp.enable = false` (or `v2.enable = false`) removes the remote entry and unit; `systemctl --user disable --now browsermcp` / launchd unload stops the broker. Revert the generator diff per slice; V1 is untouched (byte-identical) throughout.

## Dependencies

- `migrate-opencode-v1-to-v2` (parent), `port-opencode-v2-provider-allowlist` (consume only).
- `@opencode/plugin` (2.0.14); `@browsermcp/mcp` 0.1.3 (patched); `gentle-ai`/`engram`/`rtk` Go binaries.

## Success Criteria

- [ ] V1 byte-identical; `opencode` launches all features.
- [ ] `opencode2` lists 10 SDD + 3 JD + 6 review + orchestrator/neutral/managed; 7 MCPs connect; skills advertised.
- [ ] 5 adapters load; rtk fires on bash; engram mem ops succeed.
- [ ] One `browsermcp` process + one 9009 listener; two workspaces both resolve 12 tools (no timeout, no kill-on-port).
- [ ] Dropped plugins absent; cutover doc present.
- [ ] `nix flake check --no-build` + per-host evals pass.
