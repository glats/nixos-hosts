# Proposal: Rebuild Agent Context

## Intent

Rebuild the always-on agent context so both tools receive only concise, factual Nix-repository context. The root `AGENTS.md` becomes the single factual source: Claude Code reaches it through `agentsMdSources` → `~/.claude/CLAUDE.md`, while OpenCode auto-loads `<repo>/AGENTS.md` directly and must not also load it globally.

**Hosts:** all four (rog, thinkcentre, t14, macm5) — assembly lives in `shared/`.

## Scope

### In Scope
- `<repo>/AGENTS.md`: trim to a concise Nix-repository facts document (~85 lines) with a dedicated Omarchy Nix section (t14 integration facts).
- `shared/ai-assets.nix`: repoint `agentsMdSources` to the single root `AGENTS.md` (`[ ../AGENTS.md ]`).
- `shared/opencode/runtime-config.nix`: stop generating the global instruction file — remove the `ag_md` concatenation loop so OpenCode does not double-load the root `AGENTS.md` it already auto-reads.

### Out of Scope
- `shared/claude-code.nix` — no edit; verified only.
- Stray `session-ses_*.md` files at the repo root (deferred).

## Capabilities

### New Capabilities
- `repo-agent-context`: always-on agent context from the root `AGENTS.md` only; OpenCode loads it as the project file, Claude Code via generated `~/.claude/CLAUDE.md`.

### Modified Capabilities
None.

## Approach

The root `AGENTS.md` is trimmed to concise Nix facts plus the Omarchy Nix section, becoming the single source of truth. `agentsMdSources` is repointed to it, so `shared/claude-code.nix` generates a populated `~/.claude/CLAUDE.md` unchanged. The OpenCode `ag_md` loop is removed so no global instruction file is generated, avoiding a double-load of the root file OpenCode already auto-reads.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `AGENTS.md` | Modified | concise Nix facts + Omarchy Nix section |
| `shared/ai-assets.nix` | Modified | `agentsMdSources` → `[ ../AGENTS.md ]` |
| `shared/opencode/runtime-config.nix` | Modified | remove `ag_md` loop; no global instruction file |
| `shared/claude-code.nix` | Unchanged (verify-only) | `agentsMdSources` → `~/.claude/CLAUDE.md` propagates automatically |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| OpenCode double-loads root facts | Med | Remove the `ag_md` loop entirely |
| Omarchy facts go stale | Low | Keep section short and factual |
| Claude Code loses context if repoint fails | Low | Verify `~/.claude/CLAUDE.md` is populated after activation |

## Rollback Plan

Revert the commit. Activation regenerates `~/.claude/CLAUDE.md` and OpenCode's config from tracked Nix files — no manual state edits exist.

## Dependencies

None — edits existing repo files only.

## Success Criteria

- [ ] Root `AGENTS.md` is a concise repo-facts document (≤ ~85 lines) with an accurate Omarchy Nix section.
- [ ] `agentsMdSources` = `[ ../AGENTS.md ]`; generated `~/.claude/CLAUDE.md` carries the repo facts.
- [ ] `shared/opencode/runtime-config.nix` generates no global instruction content.
- [ ] `shared/claude-code.nix` is unchanged.
- [ ] `nix flake check --no-build` passes; targeted eval of the OpenCode HM module on `rog`/`t14` resolves.
