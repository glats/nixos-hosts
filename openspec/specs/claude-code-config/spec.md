# claude-code-config Specification

## Purpose

Claude Code runtime with Gentle AI skills, MCP servers, settings, CLI auth, CLAUDE.md, commands, and personas deployed to all 4 hosts. Shares `gentle-ai-assets` derivation with OpenCode; both coexist independently.

## Requirements

| # | Requirement | Strength | Key Points |
|---|------------|----------|------------|
| R1 | Binary Installation | MUST | `claude-code` from nixpkgs on PATH when enabled |
| R2 | Skills Deployment | MUST | All skills from gentle-ai-assets to `~/.claude/skills/` via cmp-guarded activation |
| R3 | MCP Configuration | MUST | 6 MCP servers rendered to `~/.claude/.mcp.json` in Claude Code format |
| R4 | Settings Generation | MUST | `~/.claude/settings.json` with permissions defaults, writable copy |
| R5 | CLAUDE.md Instructions | MUST | Project instructions from AGENTS.md deployed to `~/.claude/CLAUDE.md` |
| R6 | Commands Deployment | MUST | SDD slash commands from claude/commands/ to `~/.claude/commands/` |
| R7 | Personas Deployment | MUST | Persona and output-style files to `~/.claude/personas/` |
| R8 | OpenCode Coexistence | MUST | OpenCode skills, MCPs, configs unchanged after deployment |
| R9 | Per-Host Enablement | MAY | `home.claude-code.enable` boolean; module shared across all hosts |

### R1: Binary Installation

The `claude-code` binary from nixpkgs unstable MUST be on PATH for all hosts when enabled.

#### Scenario: Binary on PATH

- GIVEN `home.claude-code.enable = true`
- WHEN `nixos-build switch` completes
- THEN `claude` is executable and `claude --version` reports the nixpkgs-packaged version

#### Scenario: Binary absent when disabled

- GIVEN `home.claude-code.enable = false`
- WHEN rebuild completes
- THEN `claude` is NOT on PATH

### R2: Skills Deployment

All Gentle AI skills from `${pkgs.gentle-ai-assets}/share/gentle-ai/skills/` MUST deploy to `~/.claude/skills/`. Activation SHALL use cmp-guarded copy with orphan removal, mirroring the OpenCode skill sync pattern.

#### Scenario: Skills deployed

- GIVEN `home.claude-code.enable = true`
- WHEN activation runs
- THEN `~/.claude/skills/*/SKILL.md` exists for every skill in the derivation

#### Scenario: Orphan cleanup

- GIVEN a skill exists in `~/.claude/skills/` but was removed upstream
- WHEN activation runs
- THEN the stale directory is deleted

### R3: MCP Configuration

6 MCP servers from shared config MUST generate to `~/.claude/.mcp.json`. Translation: `type:"local"` to `"stdio"`, `type:"remote"` to `"http"`. `command[0]` becomes `command`, `command[1..]` become `args`.

#### Scenario: Local MCP to stdio

- GIVEN `type = "local"`, `command = ["github-mcp-server-personal", "stdio"]`
- THEN generated entry uses `"type": "stdio"`, `"command": "github-mcp-server-personal"`, `"args": ["stdio"]`

#### Scenario: Remote MCP to http

- GIVEN `type = "remote"`, `url = "https://mcp.context7.com/mcp"`
- THEN generated entry uses `"type": "http"`, `"url": "https://mcp.context7.com/mcp"`

#### Scenario: Disabled MCPs excluded

- GIVEN an MCP has `enabled = false`
- THEN that server is absent from `.mcp.json`

### R4: Settings Generation

`~/.claude/settings.json` MUST be generated as a writable file (real copy, not symlink) with a JSON `permissions` block.

#### Scenario: Settings deployed

- GIVEN `home.claude-code.enable = true`
- WHEN activation runs
- THEN `~/.claude/settings.json` exists, writable, with valid JSON permissions

### R5: CLAUDE.md Instructions

`~/.claude/CLAUDE.md` MUST deploy from `${pkgs.gentle-ai-assets}/share/gentle-ai/AGENTS.md`.

#### Scenario: CLAUDE.md deployed

- GIVEN `home.claude-code.enable = true`
- WHEN activation runs
- THEN `~/.claude/CLAUDE.md` exists matching upstream AGENTS.md

### R6: Commands Deployment

Slash commands from `${pkgs.gentle-ai-assets}/share/gentle-ai/claude/commands/` MUST deploy to `~/.claude/commands/`.

#### Scenario: Commands available

- GIVEN `home.claude-code.enable = true`
- WHEN activation runs
- THEN all claude/commands/*.md files exist in `~/.claude/commands/`

### R7: Personas Deployment

Persona and output-style files from the Claude assets MUST deploy to `~/.claude/personas/`.

#### Scenario: Personas available

- GIVEN `home.claude-code.enable = true`
- WHEN activation runs
- THEN `~/.claude/personas/` contains persona-gentleman.md, persona-neutral-residual.md, and all output-style files

### R8: OpenCode Coexistence

OpenCode MUST continue working unchanged. Claude Code deployment SHALL NOT alter `~/.config/opencode/` paths or configs.

#### Scenario: OpenCode intact

- GIVEN Claude Code is deployed
- WHEN `openCode` launches
- THEN all skills, MCPs, agents, and configs work identically to before

### R9: Per-Host Enablement

Each host MAY enable/disable via `home.claude-code.enable`. The shared module at `shared/claude-code.nix` SHALL be imported in both `home-linux/shared-modules.nix` and `home-darwin/shared-modules.nix`.

#### Scenario: Host opts in

- GIVEN `home.claude-code.enable = true` on a host
- THEN all artifacts deploy on that host

#### Scenario: Host opts out

- GIVEN `home.claude-code.enable = false` on a host
- THEN no `~/.claude/` files deploy on that host
