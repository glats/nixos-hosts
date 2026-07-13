# Proposal: Ponytail + OpenCode Integration

## Intent

Integrate Ponytail (github.com/DietrichGebert/ponytail) skills and commands into the
Gentle AI OpenCode deployment. Ponytail compresses CODE output (-54% LOC, -22% tokens)
by teaching agents YAGNI/laziness patterns. It complements Caveman (prose compression)
with no domain overlap.

## Scope

### In Scope
- Add `ponytail-src` flake input (pattern: caveman-src)
- Wire into `gentle-ai-assets-vanilla` derivation (6 skills + AGENTS.md + OpenCode commands)
- Pass through `lib/packages.nix` to both linux + darwin

### Out of Scope
- OpenCode plugin (`.opencode/plugins/ponytail.mjs`) — deferred for mode persistence
- Slash commands (`/ponytail lite|full|ultra`) — require plugin
- Node.js runtime dependency — skills-only approach needs none

## Capabilities

### New Capabilities
None. Assets flow through existing pipeline.

### Modified Capabilities
None. No spec-level behavior changes — new asset source wired into existing overlay + deployment mechanisms.

## Approach

Copy the caveman-src pattern exactly:
1. `flake.nix`: `ponytail-src = { url = "github:DietrichGebert/ponytail"; flake = false; }`
2. `vanilla.nix`: new `ponytail-src` parameter, copy block for skills/, `.opencode/command/`, AGENTS.md
3. `lib/packages.nix`: pass `ponytail-src = inputs.ponytail-src` to both linux + darwin

Existing `shared/opencode.nix` deployment needs zero changes — it already copies all skills/ and
commands/ from `gentle-ai-assets`.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `flake.nix` | Modified | New `ponytail-src` input |
| `pkgs/gentle-ai-assets/vanilla.nix` | Modified | `ponytail-src` param + copy block |
| `lib/packages.nix` | Modified | Pass `ponytail-src` to vanilla (linux + darwin) |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Ponytail AGENTS.md auto-loads and changes agent behavior unexpectedly | Low | Caveman AGENTS.md already auto-loads with no issues; `/ponytail off` disables |
| Repo structure changes upstream (v5+) | Low | Pin to a specific rev in flake input; check on update |
| Skills clash with Gentle AI skills | Low | Trigger domains disjoint; caveman-pairing documented in Ponytail SKILL.md |

## Rollback Plan

- Remove `ponytail-src` input and its wiring in `vanilla.nix` + `packages.nix`
- Rebuild: skills/ revert to previous state
- No state, no migration, no data loss

## Dependencies

- Ponytail repo: `github:DietrichGebert/ponytail` (public, no auth needed)

## Success Criteria

- [ ] `nix flake check --no-build` passes
- [ ] `nix build .#gentle-ai-assets-vanilla` produces output with ponytail skills in `share/gentle-ai/skills/`
- [ ] `nix build .#gentle-ai-assets-vanilla` produces output with ponytail commands in `share/gentle-ai/opencode/commands/`
- [ ] Ponytail AGENTS.md present in `share/gentle-ai/AGENTS.md` (appended, not replaced)
- [ ] `nixos-build dry` passes on at least one host (rog or thinkcentre)
