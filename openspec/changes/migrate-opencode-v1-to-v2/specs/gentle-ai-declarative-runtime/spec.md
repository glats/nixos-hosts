# Delta for gentle-ai-declarative-runtime

## ADDED Requirements

### Requirement: Parameterized Runtime Generator

The OpenCode config generator MUST be parameterized by runtime (V1 vs V2). Emitting the V2 tree MUST NOT alter V1 output: the generated V1 `opencode.json`, `tui.json`, `commands/`, `skills/`, `plugins/`, and `node_modules/` MUST stay byte-identical.

#### Scenario: V1 output byte-identical [rog, thinkcentre, t14, macm5]

- GIVEN the parameterized generator
- WHEN the V1 tree is regenerated and diffed against baseline
- THEN V1 output is byte-identical

#### Scenario: V2 tree emitted in isolation [t14]

- GIVEN the parameterized generator
- WHEN the V2 tree is generated
- THEN V2 config is rooted under the V2 dir
