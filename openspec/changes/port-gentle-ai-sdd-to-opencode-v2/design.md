# Design: Port Gentle AI SDD to OpenCode V2

## Technical Approach

Keep V1 byte-identical and V2 opt-in. The V2 branch emits native agents,
permissions, MCPs, skills, commands, and AGENTS context; it supplies exactly
five `Plugin.define` adapters for the remaining gaps. This remediation makes
that adapter runtime loadable by staging the full pinned `@opencode/plugin`
production dependency closure, including `@opencode/schema`.

BrowserMCP becomes a pinned, Nix-built 0.1.3 compatibility package. Its minimal
source patch stops advertising `resources`, because that version implements
`resources/list` but not `resources/templates/list`. The package is emitted
once at the canonical V2 global MCP location, avoiding its fixed port-9009
startup conflict across V2 locations. No error is hidden or BrowserMCP tool
removed.

## Architecture Decisions

| Decision | Choice | Rationale |
|---|---|---|
| V2 boundary | Retain `home.opencode.v2.{enable,runtimeRoot,projectConfigCommand}` and V1's independent branch. | V2 defects must not change the default fallback. |
| Native-first port | Use V2 agents, policy rules, MCP shape, native media, copied skills/commands, and AGENTS; retain only rtk, sdd-task-result, review-transport, skill-registry, and engram adapters. | Reuses existing host/provider policy and avoids reimplementing dropped V1 plugins. |
| Node dependency closure | Pin and stage every production dependency required by `@opencode/plugin` 2.0.14, including `@opencode/schema` 2.0.14. | Copying only the direct plugin package causes every local adapter to fail module resolution. |
| BrowserMCP protocol | Package and patch BrowserMCP 0.1.3; retain tool handlers but remove its unsupported `resources` capability. | OpenCode asks for resource templates whenever that capability is advertised, producing the confirmed `Method not found` failure. |
| BrowserMCP lifecycle | Add a V2-only singleton option and inject BrowserMCP once in the global V2 MCP configuration; exclude it from project/workspace locations. | A second 0.1.3 process kills the existing port-9009 listener. |
| TUI health | Define health from successful initialization, tool discovery, and a real tool call when paired; report an unpaired browser distinctly. | A listed plugin or partial MCP connection is not evidence of a healthy runtime. |

## Data Flow

```
Nix pins/hashes ──> V2 node_modules ──> five adapters load
BrowserMCP package+patch ──> one global V2 MCP process ──> 12 browser tools
V1 generator ──> ~/.config/opencode/ (unchanged)
```

V2 maps `prompt`→`system`, `disable`→`disabled`, `maxSteps`→`steps`, V1 modes
to primary/subagent/all, `bash`→`shell`, and `task`→`subagent`; denied tools
remain denied. Local MCP children retain proxy scrubbing. BrowserMCP's patched
initialize response does not trigger OpenCode's invalid template request.

## File Changes

| File | Action | Description |
|---|---|---|
| `shared/opencode/runtime-config.nix` | Modify | Stage the complete V2 Node closure, preserving V1 activation. |
| `shared/opencode.nix`, `shared/opencode/v2-mcps.nix` | Modify | Define the V2 BrowserMCP singleton option and canonical emission. |
| `shared/opencode/mcps-base.nix` | Modify | Remove floating BrowserMCP from the generic V2 MCP map. |
| `pkgs/opencode-npm-packages-v2/{default.nix,versions.json,node-modules.json}` | Modify | Fetch the complete pinned plugin runtime closure. |
| `pkgs/browsermcp-v2/` | Create | Build pinned BrowserMCP 0.1.3 with the capability-only compatibility patch. |
| `lib/packages.nix`, `overlays/{linux,darwin}.nix` | Modify | Expose BrowserMCP V2 on both platforms. |
| `shared/opencode/v2-{agents,permissions,mcps}.nix` | Retain | Continue native remaps without changing their contracts. |

## Interfaces / Contracts

`home.opencode.v2.browserMcp` provides `enable` (default true), `package`, and
`location` (the V2 global configuration only). Its emitter MUST produce exactly
one BrowserMCP entry when enabled and none in project/workspace maps. The
patched package MUST preserve all existing tools, MUST NOT advertise
`resources`, and MUST retain the local-child proxy-scrub environment.

## Testing Strategy

| Layer | What to Test | Approach |
|---|---|---|
| Evaluation | Closure and singleton emission | Evaluate Linux and Darwin targets; assert schema staging and exactly one V2 BrowserMCP entry. |
| Runtime | Adapters | Start `opencode2`; verify five adapters register and logs lack `@opencode/schema` resolution failures. |
| Runtime | BrowserMCP | Verify one port-9009 listener, `/mcps` shows 12 tools with no `resources/templates/list` error, then call a non-destructive tool with a paired tab. Without pairing, report unpaired, not healthy. |
| Regression | Existing guarantees | Run `nix flake check --no-build`, host evaluations, V1 byte-identity diff, deny/proxy smoke, and the SDD/review round-trip gate. |

## Threat Matrix

N/A — this design changes package closure, MCP negotiation, and singleton
configuration only; it introduces no routing, shell, subprocess, VCS/PR, or
executable-file-classification boundary.

## Migration / Rollout

No data or option migration is required. V2 activation replaces only managed
packages and MCP configuration; `v2.enable = false` is the rollback. V2 stays
opt-in until all runtime checks pass on rog, thinkcentre, t14, and macm5.

## Open Questions

None. The missing schema, unsupported resource-template capability, and
fixed-port lifecycle are confirmed by the pinned package source and V2 logs.
