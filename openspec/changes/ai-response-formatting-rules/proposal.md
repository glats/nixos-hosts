# Proposal: AI Response Formatting Rules

## Intent

Make coding-agent replies compact prose by default, reducing filler, needless lists, and templated mini-headings while retaining useful structured answers.

## Scope

### In Scope
- Add a shared output-format fragment for OpenCode and Claude Code.
- Append that fragment through the default `agentsMdSources` list.
- Apply to **all hosts**: rog, thinkcentre, t14, and mact2.

### Out of Scope
- Changes to `opencode.json`, provider settings, skills, or generated files directly.
- Reformatting upstream Gentle AI assets or enforcing output shapes in code/diffs/command output.

## Capabilities

### New Capabilities
- `ai-response-format`: Shared agent-instruction rules for concise, shape-appropriate responses.

### Modified Capabilities
- None.

## Approach

Create `shared/rules/output-format.md` with imperative English rules: lead with the answer; prose by default; use lists only for enumerable content or an explicit request; prohibit bold-mini-heading-plus-bullet templates; omit filler and excess blank lines; preserve code blocks, diffs, and command output. Add it after existing sources in `shared/ai-assets.nix`; Home Manager activation will concatenate it into both generated instruction files. Require answers to match the question's shape so list requests remain supported.

## Affected Areas

| Area | Impact | Description |
|---|---|---|
| `shared/ai-assets.nix` | Modified | Append rule fragment to default sources. |
| `shared/rules/output-format.md` | New | Shared response-format instructions. |
| `~/.config/opencode/AGENTS.md` | Generated | Receives appended section on activation. |
| `~/.claude/CLAUDE.md` | Generated | Receives appended section on activation. |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| “Poet” overcorrection rejects appropriate lists. | Medium | Explicit shape-matching permits lists when requested or enumerable. |
| Rules are drowned out by noisy instructions. | Medium | Keep the fragment short, imperative, and appended to both generated files. |

## Rollback Plan

`git revert` the changes to `shared/ai-assets.nix` and `shared/rules/output-format.md`, then rebuild; activation regenerates both instruction files without the section.

## Dependencies

- None external.

## Success Criteria

- [ ] `format-nix && nix flake check --no-build` passes.
- [ ] After rebuild, both generated files contain the new section.
- [ ] Before/after diff shows ONLY the appended section.
- [ ] Host scope is all four hosts: rog, thinkcentre, t14, and mact2.
