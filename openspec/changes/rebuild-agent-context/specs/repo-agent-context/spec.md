# repo-agent-context Specification

## Purpose

Defines the always-on agent context the NixOS configuration provides to OpenCode and Claude Code, grounded in the root `AGENTS.md` as the single concise factual source of Nix-repository context, with no duplicated instruction content across the two tools.

## Requirements

### Requirement: Single factual repository source

The repository MUST maintain the root `AGENTS.md` as the single concise factual source of Nix-repository context. It SHALL contain only factual Nix content — hosts, users, stack, commands, and critical rules — and MUST include an accurate, concise Omarchy Nix/t14 section.

#### Scenario: Concise factual context [rog, thinkcentre, t14, macm5]

- GIVEN the root `AGENTS.md`
- WHEN an agent loads repository context
- THEN it receives concise Nix facts (hosts, users, stack, commands, critical rules)
- AND the Omarchy Nix section states the pinned fork, t14-only `extraModules` integration, and the `hosts/t14/home/omarchy.nix` Home Manager import

#### Scenario: No duplicated or non-Nix instruction content [rog, thinkcentre, t14, macm5]

- GIVEN the root `AGENTS.md`
- WHEN an agent loads it
- THEN it contains no content already injected by another surface
- AND no non-Nix-repository instruction prose

### Requirement: Claude Code receives repository context

`shared/ai-assets.nix` MUST supply the root `AGENTS.md` as the `agentsMdSources` source so the generated `~/.claude/CLAUDE.md` carries the repository facts.

#### Scenario: Generated CLAUDE.md carries repository facts [rog, thinkcentre, t14, macm5]

- GIVEN `agentsMdSources` points at the root `AGENTS.md`
- WHEN activation regenerates `~/.claude/CLAUDE.md`
- THEN that file is populated with the repository facts
- AND it contains no content unrelated to the Nix repository

### Requirement: OpenCode uses project-root auto-discovery only

OpenCode MUST receive repository context solely through its project-root `AGENTS.md` auto-discovery. The Nix configuration MUST NOT generate a duplicate global `~/.config/opencode/AGENTS.md` instruction file.

#### Scenario: No generated global instruction file [rog, thinkcentre, t14, macm5]

- GIVEN OpenCode auto-reads `<repo>/AGENTS.md` as its project file
- WHEN activation assembles `~/.config/opencode/`
- THEN no global `AGENTS.md` instruction file is generated
- AND the repository facts are not double-loaded into OpenCode

### Requirement: Claude Code module unchanged

`shared/claude-code.nix` SHALL remain unchanged and MUST continue to concatenate `agentsMdSources` into `~/.claude/CLAUDE.md`.

#### Scenario: Module behavior preserved [rog, thinkcentre, t14, macm5]

- GIVEN `shared/claude-code.nix` is not edited
- WHEN `agentsMdSources` is repointed to the root `AGENTS.md`
- THEN `~/.claude/CLAUDE.md` reflects the new source with no change to the module
