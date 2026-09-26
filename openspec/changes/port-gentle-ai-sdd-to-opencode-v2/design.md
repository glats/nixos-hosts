# Design: Port Gentle AI SDD to OpenCode V2

## Technical Approach

Keep the existing isolated `opencode2` service and V1 fallback. Replace the prior plugin-rewrite plan with four verify-gated slices: copy portable skills/commands and use native media; remap the agent, permission, MCP, and AGENTS-memory configuration to V2; add only five gap adapters; then record the drop set and final-cutover runbook. V1 assets and JSON remain outside every V2 branch and byte-identical.

## Architecture Decisions

| Decision | Choice | Rationale |
|---|---|---|
| V2 boundary | Add V2-only emitters and activation; retain `home.opencode.v2.{enable,runtimeRoot,projectConfigCommand}`. | The current `runtime-config.nix` already branches on `runtimeConfig.version`; no V1 generalization is needed. |
| Portable assets | Copy all configured skill sources and the three command roots into V2, with V2-only orphan cleanup and `subtask` → `subagent`. | Assets are data; copying preserves V1 and lets V2 discover its native layouts. Native V2 media replaces multimodal. |
| Native remaps | Derive V2 agents from the existing overlay graph, V2 rules from the deny-first permissions, and `mcp.servers` from the seven filtered MCPs; emit AGENTS memory context. | Reuses host/provider selection, proxy scrubbing, and local policy instead of duplicating semantics. |
| Adapter ceiling | Ship exactly `rtk`, `sdd-task-result`, `review-transport`, `skill-registry`, and `engram`, each as a pinned-2.0.14 `Plugin.define` adapter. | These are the only verified native gaps; adapters call existing Go binaries and do not recreate V1 plugins. |
| Explicit drops | Do not emit claude-auth, warden, either TUI plugin, or model-variants. | V2 native policies replace only denial, not Warden audit logging; model routing is provider configuration, not a speculative catalog transform. |

## Data Flow

```
Nix options + asset derivations
        └── V2 emitters ──> ~/.config/opencode-v2/{opencode.json,AGENTS.md,skills,commands,plugins}
                                  └── opencode2 supervisor ──> native config/MCPs + five adapters
V1 emitter ──> ~/.config/opencode/ (unchanged)
```

V2 agent translation is `prompt`→`system`, `disable`→`disabled`, `maxSteps`→`steps`, `#variant` joins the model, and mode becomes primary/subagent/all. Permission translation is `bash`→`shell`, `task`→`subagent`, bare grants→Engram MCP actions, and disabled tools→MCP denies. MCP translation inverses `enabled`, uses snake_case OAuth fields, and applies the existing local-child proxy scrub. The adapter contract is pass-through on unavailable binaries or hook failure; no adapter stages, commits, pushes, or selects a repository destination.

## File Changes

| File | Action | Description |
|---|---|---|
| `shared/opencode/runtime-config.nix` | Modify | Add V2-native config, asset deployment, AGENTS copy, and five-adapter deployment while preserving the V1 branch. |
| `shared/opencode.nix` | Modify | Wire V2 emitters and isolated runtime dependencies without changing V1 options. |
| `shared/opencode/v2-{agents,permissions,mcps}.nix` | Create | Translate the existing graph, deny policy, and MCP registry to V2 shape. |
| `shared/opencode/rtk-v2.ts` | Create | V2 shell rewrite adapter; preserve `rtk.ts`. |
| `pkgs/gentle-ai-assets/default.nix`, `pkgs/engram-assets/{default.nix,vanilla.nix}` | Modify | Stage the four Gentle AI and one Engram V2 adapter sources; retain `ENGRAM_BIN` substitution. |
| `pkgs/opencode-npm-packages-v2/`, `lib/packages.nix` | Create/Modify | Provide only the pinned V2 plugin package/types needed by adapters. |
| `docs/opencode-v2-final-cutover.md` | Create | Final migration from isolated V2 XDG roots to default roots, preserving config, sessions, and credentials. |

## Testing Strategy

| Layer | What to Test | Approach |
|---|---|---|
| RED/eval | V1 identity, V2 assets, agent inventory, denies, and dropped files | Snapshot V1; evaluate V2 JSON and deployed trees before green changes. |
| Integration | Seven MCPs, proxy scrub, skills/commands, adapters | `opencode2` smoke: discovery, shell rewrite, Engram memory operation, SDD and review round-trip. |
| Matrix | Shared configuration | `nix flake check --no-build`; Linux HM evals for rog/thinkcentre/t14 and Darwin evaluation for macm5. |

## Threat Matrix

| Boundary | Applicability | Safe/failure behavior | Planned RED tests |
|---|---|---|---|
| Documentation-like paths | N/A: activation copies data and performs no executable-file classification. | — | — |
| Git repository selection | Applicable: skill-registry/review adapters accept only the V2 session worktree; reject relative and outside-root selectors. | Reject before subprocess. | Relative and absolute-outside rejection. |
| Commit state | Applicable: adapters observe only. | Never stage or commit; fail closed on mutation request. | Empty, staged, and `commit -a` no-mutation cases. |
| Push state | Applicable: native shell rules retain ask/deny; adapters resolve no ref. | Preserve caller destination ownership. | Tracking, first-push, and explicit-refspec ask/deny. |
| PR commands | Applicable: reviewer relay forwards owned arguments unchanged. | Reject malformed input; do not rewrite head or environment prefix. | Explicit `--head`, env-prefix, composed-command pass-through. |

## Migration / Rollout

No option migration is required. Each slice is independently revertible and `v2.enable = false` disables V2. V2 stays opt-in until a full SDD cycle and reviewer round-trip pass on rog, thinkcentre, t14, and macm5. The final doc is the only future default-root migration procedure.

## Open Questions

- [ ] Confirm each adapter hook against the pinned 2.0.14 declaration files immediately before implementation; omit a failed adapter rather than reviving a dropped V1 plugin.

## Data Flow and Contracts

Nix options and shared assets feed the V2 emitter, which writes mutable config and copied assets, then restarts the isolated V2 service. Native config supplies agent routing, permissions, and MCPs; V2 plugins receive hook context, transform only their declared domain, and call unchanged `rtk`, `engram`, and `gentle-ai` binaries. V1 follows its current generator and activation path exclusively.

V2 agent mapping is `prompt→system`, `disable→disabled`, `maxSteps→steps`, model variant joins, and V1 modes to V2 primary/subagent/all. Permission mapping is `bash→shell`, `task→subagent`, plus explicit MCP action denies and Engram grants; preserve deny-first ordering. Map MCP enablement and OAuth fields only after checking the pinned 2.0.14 schema. Before each P3 implementation, type-check its SDK against the pinned package; API drift blocks that plugin rather than falling back to V1 code.

## Testing Strategy

Run `nix flake check --no-build` plus Linux Home Manager evaluations for rog, thinkcentre, t14 and Darwin evaluation for macm5 after every slice. Snapshot V1 `opencode.json` and deployed assets before/after each slice. P1 validates listed skills/commands; P2 validates agent inventory, all MCP connections, proxy removal, and preserved denies for sops, sudo, and nixos-build. P3 validates plugin registration, rtk rewrite/pass-through, Engram memory operations, an SDD cycle, and a `gentle-ai review` round-trip. Default status remains opt-in until those end-to-end checks pass on all hosts.

## Threat Matrix

| Boundary | Applicability and safe/failure behavior | RED test |
|---|---|---|
| Documentation-like paths | N/A: no executable-file classification. | None. |
| Git repository selection | Applicable: reviewer/SDD hooks use only V2 session worktree; reject relative or outside-worktree selectors. | Relative and absolute selector rejection. |
| Commit state | Applicable: review hooks observe but never stage or commit; empty/staged/`-a` remain caller-owned. | Three no-mutation cases. |
| Push state | Applicable: V2 permissions preserve ask/deny behavior; no hook resolves a destination. | Tracking, first-push, refspec denial/ask cases. |
| PR commands | Applicable: reviewer transport forwards composed input without rewriting head/environment ownership. | Explicit head, env-prefix, composed-command pass-through. |

## Open Questions

- [ ] Confirm pinned 2.0.14 schema and generated SDK types before P0/P2/P3; public current documentation still shows the legacy hook-object API, so no unverified API shape will ship.
- [ ] Decide whether model variants has a proven V2 catalog-transform implementation; default disposition is deprecation.
