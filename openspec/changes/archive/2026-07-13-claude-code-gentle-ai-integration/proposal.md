# Proposal: Claude Code + Gentle AI: feature parity with OpenCode

## Intent

Deploy Claude Code on all 4 hosts alongside OpenCode, sharing the same Gentle AI skills, MCP servers, Engram memory, and SDD phase skills. Opening either tool must feel identical -- same stack, same behavior. Both coexist; no replacement.

## Scope

### In Scope
- Install `claude-code` binary on rog, thinkcentre, t14, mact2 via `sadjow/claude-code-nix` flake input (auto-updating, always latest)
- Deploy all 32 Gentle AI skills to `~/.claude/skills/` from the same `gentle-ai-assets` derivation
- Generate `.mcp.json` with all 6 MCP servers translated to Claude Code format
- Generate `~/.claude/settings.json` with permissions and model defaults
- Generate `~/CLAUDE.md` mirroring AGENTS.md instructions
- First-run OAuth `/login` (same pattern as OpenCode `/connect` with GitHub Copilot)
- Copy caveman slash commands and skill-creator/registry commands to `~/.claude/commands/`
- Deploy OpenCode persona files to `~/.claude/personas/`

### Out of Scope
- SDD orchestrator port (OpenCode-specific agent graph)
- Per-phase model routing (Claude Code uses one model per session)
- Plugin port (engram.ts, secret-guard.ts are OpenCode-specific; Engram works via MCP)
- Custom npm derivation (Anthropic deprecated npm; nixpkgs binary is the only path)

## Capabilities

### New Capabilities
- `claude-code-config`: Claude Code runtime with Gentle AI skills, MCP servers, settings, CLI auth, CLAUDE.md instructions, and persona files deployed to all 4 hosts

### Modified Capabilities
None. Existing specs (skill-deployment, gentle-ai-asset-overlay) are unchanged -- skills continue to source from the single `gentle-ai-assets` derivation.

## Approach

New HM module `shared/claude-code.nix` mirrors `shared/opencode.nix` structure. Skills deployed from `gentle-ai-assets` to both `~/.claude/skills/` and `~/.config/opencode/skills/`. MCP config generated from existing `mcps-base.nix`, rendered as Claude Code `.mcp.json` (stdio/http format). Auth via OAuth `/login` flow (same pattern as OpenCode `/connect` with GitHub Copilot). No API key or sops changes needed -- Claude Code supports OAuth via Claude Pro/Max/Teams/Enterprise subscriptions with browser-based login.

Commands/personas copied via activation script with cmp guard (same pattern as OpenCode skill sync). Claude Code reads `.claude/commands/` for slash commands and `.claude/personas/` for output styles.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `flake.nix` | Modified | Add `claude-code-nix` flake input + `claude-code` to linuxPackages/darwinPackages |
| `shared/claude-code.nix` | New | HM module: config, skills, MCPs, commands, personas, CLAUDE.md |
| `shared/opencode.nix` | Modified | Skills activation: also deploy to `~/.claude/skills/` |
| `overlays/linux.nix` | Modified | Add `claude-code` to self.packages inherit block |
| `overlays/darwin.nix` | Modified | Add `claude-code` to self.packages inherit block |
| `home-linux/shared-modules.nix` | Modified | Import `../shared/claude-code.nix` |
| `home-darwin/shared-modules.nix` | Modified | Import `../shared/claude-code.nix` |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Headless hosts (thinkcentre) can't open browser for OAuth | Low | Use `claude setup-token` on a host with browser, copy token to headless host |
| Skill format drift between OpenCode and Claude Code | Low | Both use identical SKILL.md format; gentle-ai maintains cross-compatibility |
| Config collision between tools | Low | Separate directories (`~/.claude/` vs `~/.config/opencode/`) |
| External flake input may break on upstream changes | Low | Pinned by flake.lock; auto-updating but deterministic per lockfile |

## Rollback Plan

Remove `claude-code.nix` import from shared-modules lists, remove `claude-code` from overlays, rebuild. OpenCode unaffected. No state migration or data loss.

## Dependencies

- `sadjow/claude-code-nix` flake input (auto-updating, always latest binary from GCS)
- Active Claude subscription (Pro, Max, Teams, or Enterprise) tied to user's work email
- First-run OAuth `/login` on each host (browser-based, one-time)

## Success Criteria

- [ ] `nix flake check --no-build` passes for rog and mact2
- [ ] `claude-code` binary on PATH on all 4 hosts
- [ ] `~/.claude/skills/` contains all 32 Gentle AI skills matching OpenCode
- [ ] `.mcp.json` generated with all 6 MCP servers
- [ ] `claude` command launches OAuth `/login` flow on rog and mact2
- [ ] `claude` command launches without errors on rog
- [ ] OpenCode continues working unchanged (skills, MCPs, agents intact)
- [ ] Opening either tool feels identical: same skills available, same MCPs, same SDD phase skills
