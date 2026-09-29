# Design: Port Gentle AI SDD to OpenCode V2

## Technical Approach

Keep V1 byte-identical and V2 opt-in. V2 emits native agents, permissions,
MCPs, skills, commands, and AGENTS context, with five minimal adapters.

BrowserMCP 0.1.3 is stdio-only, owns fixed extension port 9009, and OpenCode V2
spawns local MCPs per session. Therefore global `type: "local"` emission still
creates competing children. The confirmed design replaces all residual
supergateway assumptions with `browsermcp-broker`: one supervised Go process
owns one patched BrowserMCP child and exposes loopback Streamable HTTP.

## Architecture Decisions

| Decision | Choice | Rationale |
|---|---|---|
| V2 boundary | Preserve V1 and retain V2 opt-in. | V2 failures cannot affect the fallback. |
| Native-first port | Use native V2 features plus five adapters only. | Avoids recreating dropped V1 plugins. |
| BrowserMCP package | Preserve 12 tools; remove `resources` advertisement and kill-on-port startup behavior. | Avoids V2 resource-template errors and unsafe port ownership. |
| Singleton transport | `browsermcp-broker` owns one child, caches synthetic `initialize`/`tools/list`, and correlates all `tools/call` JSON-RPC IDs across HTTP sessions. | supergateway cannot share one stdio child: stateless mode is per-request and stateful mode per-session. |
| Service boundary | Supervise the broker as `browsermcp` through systemd or launchd. The default bridge port is 9010 because rog's code-server owns 9008. | A durable owner preserves the extension's single 9009 pairing without taking another service's port. |

## Data Flow

```
OpenCode V2 workspaces ── Streamable HTTP ──> browsermcp-broker
                                              └── one stdio child ──> extension :9009
V1 generator ───────────────────────────────────────────────────────> unchanged
```

The broker binds `127.0.0.1:<bridgePort>/mcp`, replays cached discovery to each
client session, and forwards calls only through its single child. The child does
not inherit proxy variables. A bind collision fails; it never kills or replaces
another owner.

## File Changes

| File | Action | Description |
|---|---|---|
| `pkgs/nixos-scripts/cmd/browsermcp-broker/`, `internal/browsermcp/` | Create | Thin command and multiplexing implementation. |
| `pkgs/nixos-scripts/default.nix` | Modify | Build the broker in the existing Go derivation. |
| `shared/opencode.nix` | Modify | Add bridge options and Linux/Darwin supervision. |
| `shared/opencode/{runtime-config,v2-mcps}.nix` | Modify | Emit one remote loopback URL and no local BrowserMCP entry. |
| `pkgs/browsermcp-v2/default.nix` | Retain/verify | Keep capability and kill-on-port patches. |

## Interfaces / Contracts

`home.opencode.v2.browserMcp` SHALL provide `enable`, `package`, `bridgePackage`
(default `pkgs.nixos-scripts`), and `bridgePort` (default `9010`). The V2 global
map MUST contain exactly one `type: "remote"` entry at
`http://127.0.0.1:<bridgePort>/mcp`; project/workspace maps and local entries
MUST contain none. The unit runs `browsermcp-broker --child <package>/bin/mcp-server-browsermcp --port <bridgePort>`. On Linux, an occupied bridge port exits with status 78 and `RestartPreventExitStatus=78` prevents a restart loop; it never kills or replaces the existing listener.

## Testing Strategy

| Layer | What to test | Approach |
|---|---|---|
| Go RED/unit | One child, ID/session correlation, loopback-only bind, collision failure, proxy scrub. | Tests precede broker logic. |
| Evaluation | Options, unit shape, exactly one remote URL and zero local entries. | Linux and Darwin evaluation. |
| Runtime | Two workspaces, 12 tools, one child/9009 listener, paired real call, restart recovery. | R17/R24 gate before release. |
| Regression | V1 identity, adapter load, policy/proxy behavior. | Flake checks and host evaluations. |

## Threat Matrix

| Boundary | Applicability | Design response | Planned RED tests |
|---|---|---|---|
| Documentation-like paths | N/A — no executable-file classification. | None. | None. |
| Git repository selection | Applicable — review transport accepts repository selectors. | Reject relative or outside-worktree selectors before subprocess creation. | Relative and outside-worktree selectors fail closed. |
| Commit state | Applicable — review transport must not mutate Git state. | Never stage or commit. | Empty index, staged, and `commit -a` remain unchanged. |
| Push state | Applicable — review flow may inspect push arguments. | Preserve ask/deny semantics; do not push. | Tracking, first-push, and refspec cases remain denied/asked. |
| PR commands | Applicable — review transport composes `gentle-ai review`. | Preserve explicit `--head` and environment prefixes without ownership changes. | Composed commands forward both forms unchanged. |

The broker also introduces a process/network boundary: loopback only, no proxy
inheritance, one child, and failure on occupied bridge port. RED tests cover
double-bind rejection and concurrent-session singleton preservation.

## Migration / Rollout

No data migration is required. `v2.browserMcp.enable = false` removes the remote
entry and unit; `v2.enable = false` restores the untouched V1 fallback. V2 stays
opt-in until runtime gates pass on rog, thinkcentre, t14, and macm5.

## Open Questions

- [ ] Decide whether idle child shutdown is safe for extension pairing; default to retaining the supervised child until runtime evidence proves otherwise.
- [ ] Define the user-visible diagnostic for an occupied bridge port without weakening fail-closed startup.
