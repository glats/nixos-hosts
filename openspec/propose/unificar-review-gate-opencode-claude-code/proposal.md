# Proposal: Unify SDD Review Gate (OpenCode + Claude Code)

## Intent

Claude Code has NO SDD review gate (done/retry/reiterate). OpenCode has it baked into `shared/opencode/assets/opencode/review-gate.md` (lines 410-429). After every `sdd-apply` slice, Claude Code's orchestrator can advance to verify/archive unchecked while OpenCode's gate forces a decision. This creates inconsistent SDD enforcement across tools. Give Claude Code the same review gate from a single shared source.

## Scope

### In Scope
- NEW: `shared/assets/review-gate.md` — platform-agnostic review gate source
- EDIT: `shared/claude-code.nix` line 151 — point `~/.claude/review-gate.md` to new shared source
- VERIFY: `nix flake check --no-build` passes for all 4 hosts

### Out of Scope
- OpenCode's 443-line orchestrator overlay (`shared/opencode/assets/opencode/review-gate.md`) — unchanged; it already deploys correctly
- `lib/packages.nix` — no derivation changes needed (direct `home.file` source, not extraAssets)
- `shared/opencode.nix` — already correct, no touch
- Upstream `claude/sdd-orchestrator.md` — already deprecated; no preservation
- Persona, skills, MCPs, agents — all identical between tools or different by design

## Capabilities

### Modified Capabilities
- `review-gates`: Claude Code's orchestrator SHALL receive the same platform-agnostic review gate content as OpenCode, deployed from a single shared file.

## Approach

1. Extract platform-agnostic gate text (lines 410-429 of `shared/opencode/assets/opencode/review-gate.md`) into `shared/assets/review-gate.md`. Content:
   - Mandatory gate after every `sdd-apply` slice
   - Present 3 options: done, retry, reiterate
   - Record verdict, no fourth option, no auto-advance
   - Do NOT launch `sdd-verify` unless verdict is `done`

2. Change `shared/claude-code.nix` line 153: replace `${pkgs.gentle-ai-assets}/share/gentle-ai/claude/sdd-orchestrator.md` with new shared source file path.

3. No changes to the existing `review-gate.md` in OpenCode's asset tree — OpenCode continues reading its full orchestrator overlay which includes the review gate.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `shared/assets/review-gate.md` | New | Shared review gate source (platform-agnostic) |
| `shared/claude-code.nix` | Modified | Line 151: source path from upstream to local shared file |
| `shared/opencode/assets/opencode/review-gate.md` | No change | OpenCode keeps full orchestrator overlay |

## Affected Hosts

rog, thinkcentre, t14, mact2 — all import both `shared/opencode.nix` and `shared/claude-code.nix`.

## Risks

None. Claude Code gains a feature it was missing. OpenCode unchanged. One-line edit, no build-side changes.

## Rollback Plan

Revert line 151 in `shared/claude-code.nix` to upstream source: `${pkgs.gentle-ai-assets}/share/gentle-ai/claude/sdd-orchestrator.md`. Delete `shared/assets/review-gate.md`. Run `nix flake check --no-build`.

## Success Criteria

- [ ] `shared/assets/review-gate.md` exists with platform-agnostic gate content
- [ ] `shared/claude-code.nix` line 151 points to new file
- [ ] `nix flake check --no-build` exits 0 for rog, thinkcentre, t14, mact2
- [ ] OpenCode's `review-gate.md` is unmodified (diff confirms zero changes)
