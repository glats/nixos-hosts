# Design: Rebuild Agent Context

## Technical Approach

Make the repository root `AGENTS.md` the only authored repository-context source. Home Manager exposes that file through the existing `home.ai-assets.agentsMdSources` option. Claude Code keeps its current activation behavior and concatenates the single source into `~/.claude/CLAUDE.md`; OpenCode relies on project-root auto-discovery and its activation removes the formerly managed global `~/.config/opencode/AGENTS.md`.

## Architecture Decisions

| Decision | Choice | Alternatives considered | Rationale |
|---|---|---|---|
| Context authority | Keep concise Nix facts only in root `AGENTS.md`, including the pinned `github:glats/omarchy-nix` fork, t14-only `extraModules`, and `hosts/t14/home/omarchy.nix` import | Preserve the current long document or split Omarchy facts into another source | One short file prevents drift and satisfies both tools' repository-context requirement. |
| Claude delivery | Set `home.ai-assets.agentsMdSources` default to `[ ../AGENTS.md ]` | Add a Claude-specific option or make Claude discover `AGENTS.md` | The existing typed option and unchanged Claude activation already provide the required path with no new interface. |
| OpenCode delivery | Remove global-file concatenation and delete the previously managed global file during activation | Emit an empty file or keep both global and project files | Absence, not emptiness, proves project-root auto-discovery is the sole source; cleanup prevents legacy duplication after upgrade. |
| Change boundary | Do not edit `shared/claude-code.nix` | Refactor its activation script | Its current concatenation behavior is the behavior under test, not an implementation target. |

## Data Flow

```text
<repo>/AGENTS.md ── OpenCode project auto-discovery ──> OpenCode
        │
        └─ home.ai-assets.agentsMdSources
             └─ unchanged deployClaudeCodeAssets ──> ~/.claude/CLAUDE.md ──> Claude Code

makeOpencodeConfigMutable-default ── removes legacy ~/.config/opencode/AGENTS.md
```

## File Changes

| File | Action | Description |
|---|---|---|
| `AGENTS.md` | Modify | Reduce to approximately 85 lines of hosts, users, stack, commands, critical rules, and verified Omarchy/t14 facts; remove duplicated formatting/workflow prose and unrelated instructions. |
| `shared/ai-assets.nix` | Modify | Change the `agentsMdSources` default to `[ ../AGENTS.md ]`; retain its `types.listOf types.path` interface. |
| `shared/opencode/runtime-config.nix` | Modify | Remove `AGENTS.md` from mutable-file conversion, remove the concatenation block, and remove the legacy global file during activation. Leave skills, commands, plugins, and JSON generation unchanged. |
| `shared/claude-code.nix` | Verify only | Confirm lines 306–312 still concatenate `agentsMdSources` into `~/.claude/CLAUDE.md`; no edit. |

## Interfaces / Contracts

`home.ai-assets.agentsMdSources` remains a `listOf path`; only its default changes. No option is renamed or removed, so there is no breaking option migration. The generated-file contract becomes: Claude owns a populated global `CLAUDE.md`; OpenCode owns no global `AGENTS.md`.

## Implementation Sequence

1. Rewrite `AGENTS.md` from facts verified in `flake.nix`, `hosts/t14/default.nix`, `hosts/t14/home/default.nix`, and `hosts/t14/home/omarchy.nix`.
2. Repoint `agentsMdSources` in `shared/ai-assets.nix`.
3. Remove OpenCode global generation and add stale-file cleanup in `shared/opencode/runtime-config.nix`.
4. Format only the two modified Nix files, then execute the verification plan without touching `shared/claude-code.nix`.

## Testing Strategy

| Layer | What to Test | Approach |
|---|---|---|
| Static | Root context is concise, Nix-only, and contains the three required Omarchy/t14 facts | Review line count and content against the four factual source files. |
| Module evaluation | All hosts resolve one `agentsMdSources` path and both activation entries evaluate | Evaluate `homeConfigurations.{rog,thinkcentre,t14,macm5}.activationPackage.drvPath` and inspect the option value. |
| Generated behavior | Claude activation contains the root source; OpenCode activation removes rather than creates global `AGENTS.md` | Inspect `home.activation.deployClaudeCodeAssets.data` and `home.activation.makeOpencodeConfigMutable-default.data`; verify `git diff --exit-code -- shared/claude-code.nix`. |
| Repository gate | Shared Nix changes remain valid | Run `nix fmt -- shared/ai-assets.nix shared/opencode/runtime-config.nix`, then `nix flake check --no-build`. |

## Threat Matrix

The activation shell changes require matrix review, but none of the matrix's execution-selection boundaries changes.

| Boundary | Applicability | Reason |
|---|---|---|
| Documentation-like paths | N/A | No executable classification is introduced. |
| Git repository selection | N/A | No Git invocation or cwd selection changes. |
| Commit state | N/A | No commit/index automation exists here. |
| Push state | N/A | No push or ref resolution exists here. |
| PR commands | N/A | No PR command composition exists here. |

## Migration / Rollout and Rollback

Home Manager activation removes the stale OpenCode global file and regenerates Claude's file from the new source; no data migration or feature flag is needed. Roll back by reverting the three modified files and activating again, which restores the prior generated outputs.

## Scope Exclusions

Do not edit `shared/claude-code.nix`, `shared/opencode/agents.nix`, overlays, agent prompts, skills, commands, plugins, MCP/provider/permission configuration, `shared/rules/*`, host modules, flake inputs, or root `session-ses_*.md` files.

## Open Questions

None.
