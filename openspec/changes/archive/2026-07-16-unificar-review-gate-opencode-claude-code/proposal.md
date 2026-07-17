# Proposal: Unify SDD Review Gate (OpenCode + Claude Code)

## Intent

Claude Code has NO SDD review gate (done/retry/reiterate). OpenCode has it baked into `shared/opencode/assets/opencode/review-gate.md` (lines 410-429). After every `sdd-apply` slice, Claude Code's orchestrator can advance to verify/archive unchecked while OpenCode's gate forces a decision. This creates inconsistent SDD enforcement across tools. Give Claude Code the same review gate from a single shared source.

## Scope

### In Scope
- NEW: `shared/assets/review-gate.md` — platform-agnostic review gate source
- EDIT: `lib/packages.nix` — add `extraAssetsShared` for derivation-based deployment
- EDIT: `pkgs/gentle-ai-assets/default.nix` — add parameter + copy block
- EDIT: `shared/claude-code.nix` — point `~/.claude/review-gate.md` to derivation path
- VERIFY: `nix flake check --no-build` passes for all 4 hosts

### Out of Scope
- OpenCode's 443-line orchestrator overlay (`shared/opencode/assets/opencode/review-gate.md`) — unchanged; it already deploys correctly
- `shared/opencode.nix` — already correct, no touch
- Upstream `claude/sdd-orchestrator.md` — already deprecated; no preservation
- Persona, skills, MCPs, agents — all identical between tools or different by design

## Capabilities

### Modified Capabilities
- `review-gates`: Claude Code's orchestrator SHALL receive the same platform-agnostic review gate content as OpenCode, deployed from a single shared file via the `gentle-ai-assets` derivation.

## Approach

1. Extract platform-agnostic gate text (lines 410-429 of `shared/opencode/assets/opencode/review-gate.md`) into `shared/assets/review-gate.md`. Content:
   - Mandatory gate after every `sdd-apply` slice
   - Present 3 options: done, retry, reiterate
   - Record verdict, no fourth option, no auto-advance
   - Do NOT launch `sdd-verify` unless verdict is `done`

2. Add `extraAssetsShared = ./../shared/assets;` to `lib/packages.nix` and pass it to `gentle-ai-assets` on both linux and darwin branches.

3. Add `extraAssetsShared ? null` parameter and copy block to `pkgs/gentle-ai-assets/default.nix`.

4. Change `shared/claude-code.nix` source path from old derivation to `${pkgs.gentle-ai-assets}/share/gentle-ai/review-gate.md`.

5. No changes to the existing `review-gate.md` in OpenCode's asset tree — OpenCode continues reading its full orchestrator overlay which includes the review gate.

## Affected Areas

| Area | Action | Description |
|------|--------|-------------|
| `shared/assets/review-gate.md` | New | Shared review gate source (platform-agnostic) |
| `lib/packages.nix` | Modified | Added `extraAssetsShared` attr + inherits |
| `pkgs/gentle-ai-assets/default.nix` | Modified | New param + copy block for shared assets |
| `shared/claude-code.nix` | Modified | Source path changed to derivation path |

## Affected Hosts

rog, thinkcentre, t14, mact2 — all import both `shared/opencode.nix` and `shared/claude-code.nix`.

## Risks

None. Claude Code gains a feature it was missing. OpenCode unchanged. 4-file change with established patterns.

## Rollback Plan

Revert `shared/claude-code.nix` source to old derivation path. Revert `lib/packages.nix` and `pkgs/gentle-ai-assets/default.nix` changes. Delete `shared/assets/review-gate.md`. Run `nix flake check --no-build`.

## Success Criteria

- [x] `shared/assets/review-gate.md` exists with platform-agnostic gate content
- [x] `shared/claude-code.nix` sources from derivation path
- [x] `lib/packages.nix` has `extraAssetsShared` passing shared/assets to derivation
- [x] `pkgs/gentle-ai-assets/default.nix` has the shared assets copy block
- [x] `nix flake check --no-build` exits 0
- [x] OpenCode's `review-gate.md` is unmodified (diff confirms zero changes)
