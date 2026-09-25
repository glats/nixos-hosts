# Delta for repo-agent-context

## MODIFIED Requirements

### Requirement: OpenCode uses project-root auto-discovery only

OpenCode MUST receive repository context solely through its project-root `AGENTS.md` auto-discovery. The Nix configuration MUST NOT generate a duplicate global `~/.config/opencode/AGENTS.md` instruction file. V2 SHALL read project `AGENTS.md` only via its opt-in wrapper.

(Previously: no V2 distinction.)

#### Scenario: No generated global instruction file [rog, thinkcentre, t14, macm5]

- GIVEN OpenCode auto-reads `<repo>/AGENTS.md` as its project file
- WHEN activation assembles `~/.config/opencode/`
- THEN no global `AGENTS.md` instruction file is generated
- AND no repository facts are double-loaded

#### Scenario: V2 project context gated by opt-in [t14]

- GIVEN a repo containing `AGENTS.md`
- WHEN V2 loads via the default wrapper
- THEN it skips project `AGENTS.md`
- AND via the opt-in wrapper in a V2-compatible repo it discovers it
