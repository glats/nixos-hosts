# opencode-v2-gentle-ai-runtime Specification

## Purpose

Native-first V2 emission: V1 byte-identical default, explicit drop set, final-cutover runbook.

## Requirements

### Requirement: Phased Port Slices

The system MUST port V2 features in four verify-gated slices: P1 COPY skills/commands + native media, P2 REMAP agents/permissions/MCP + `cli.json`, P3 five adapters, P4 drop + cutover doc.

#### Scenario: Slice ordering

- GIVEN the V2 generator emits only the provider allowlist [all]
- WHEN slices land in P1→P4 order
- THEN each is independently evaluable; P3 never precedes P2

### Requirement: V1 Byte-Identical Fallback

The system MUST keep V1 `opencode.json` and assets byte-identical; V1 SHALL stay default and fallback.

#### Scenario: V1 untouched, V2 opt-in

- GIVEN a V2 slice is applied [all]
- WHEN V1 config/assets are diffed and `opencode2` runs
- THEN V1 stays byte-identical, launches all features, and V2 is opt-in

### Requirement: Skills and Commands Copy

The system MUST copy skills (sdd-*, judgment-day, caveman, ponytail, nix-verify, archify) and command bodies into the V2 tree; `subtask` SHALL become `subagent`; media SHALL be native.

#### Scenario: Discovery and delegation

- GIVEN skills and commands are copied into the V2 tree [all]
- WHEN `opencode2` advertises skills and delegation fires
- THEN all families list unchanged and delegation targets `subagent`

### Requirement: Agents Remap

The system MUST translate the V1 agent graph to V2 `agents` schema (`prompt`→`system`, `disable`→`disabled`, `maxSteps`→`steps`, `#variant` joins model, `mode`→primary/subagent/all) and SHALL emit 10 SDD, 3 JD, 6 review, orchestrator, neutral, managed agents.

#### Scenario: Agent emission

- GIVEN the agent graph is built from overlays [all]
- WHEN `opencode2` lists agents
- THEN 10 SDD + 3 JD + 6 review + orchestrator/neutral/managed appear in native V2 shape

### Requirement: Permissions Remap

The system MUST remap V1 permissions to V2 `{action, resource, effect}` rules (`bash`→`shell`, `task`→`subagent`, bare grants→engram actions, `disabledTools`→MCP deny rules) and MUST NOT loosen deny coverage.

#### Scenario: Deny preserved

- GIVEN V1 denies `sops*`, `sudo`, `nixos-build *` [all]
- WHEN V2 permission rules evaluate
- THEN equivalent denies hold; disabled GitHub tools stay hidden

### Requirement: MCP, Engram, and AGENTS Remap

The system MUST group servers under V2 `mcp.servers`, use inverse `disabled`, snake_case OAuth keys, preserve proxy-scrub, and emit AGENTS memory context. Engram SHALL stay version-agnostic.

#### Scenario: Server connectivity and memory context

- GIVEN the 7 servers are remapped [all]
- WHEN `/mcps` is checked and AGENTS context loads
- THEN all 7 connect; local children skip HTTPS_PROXY; AGENTS context native

### Requirement: Minimal Adapter Set

The system MUST ship exactly five minimal adapters for genuine gaps — rtk (shell rewrite), sdd-task-result (envelope), review-transport (reviewer relay), skill-registry (startup refresh), engram (session attribution) — against V2 `Plugin.define`; rtk SHALL fire on bash; engram mem ops SHALL succeed.

#### Scenario: Adapter smoke

- GIVEN the five adapters are loaded [all]
- WHEN `opencode2` starts
- THEN all register, rtk fires on bash, engram mem ops succeed

### Requirement: Explicit Drop Set

The system MUST NOT emit claude-auth, warden, the TUI pair, or model-variants; multimodal SHALL use native media.

#### Scenario: Dropped plugins absent

- GIVEN V2 emission completes [all]
- WHEN the V2 tree is inspected
- THEN none of the dropped plugins are emitted

### Requirement: Final Cutover Doc

The system MUST provide `docs/opencode-v2-final-cutover.md`, a runbook migrating `~/.config/opencode-v2` + `~/.local/opencode-v2` to default XDG roots, preserving config, sessions, and credentials.

#### Scenario: Cutover runbook present

- GIVEN P4 lands [all]
- WHEN the docs tree is checked
- THEN the runbook covers config, sessions, and credentials

### Requirement: SDD and Reviewer Round-Trip

The system MUST gate the V2 default flip on a full SDD cycle and `gentle-ai review` round-trip across all four hosts; until then V2 SHALL stay opt-in.

#### Scenario: Default flip gate

- GIVEN all slices have shipped [rog, thinkcentre, t14, macm5]
- WHEN a full SDD cycle and reviewer round-trip pass
- THEN V2 may become default; otherwise it stays opt-in
