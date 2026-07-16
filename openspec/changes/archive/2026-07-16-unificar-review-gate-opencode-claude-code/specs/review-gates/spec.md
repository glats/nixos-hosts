# Delta for review-gates

## ADDED Requirements

### RG-001: Single Source of Truth

The review gate content MUST live in exactly one file: `shared/assets/review-gate.md`. OpenCode MUST continue deploying review-gate.md to `~/.config/opencode/review-gate.md` (unchanged path). Claude Code MUST deploy review-gate.md to `~/.claude/review-gate.md` via the `extraAssetsShared` mechanism: `lib/packages.nix` passes `shared/assets/` to `pkgs/gentle-ai-assets/default.nix`, which copies the file into the derivation store, and `shared/claude-code.nix` sources from `${pkgs.gentle-ai-assets}/share/gentle-ai/review-gate.md`.

#### Scenario: Both tools deploy from shared source

- GIVEN `shared/assets/review-gate.md` is the authoritative source
- WHEN home-manager deploys to any host
- THEN `~/.config/opencode/review-gate.md` and `~/.claude/review-gate.md` contain identical content

#### Scenario: Single edit propagates to both tools

- GIVEN `shared/assets/review-gate.md` is modified
- WHEN home-manager switch runs
- THEN both deployed copies reflect the edit

#### Scenario: Claude Code deploys via derivation path

- GIVEN `shared/assets/review-gate.md` has content
- WHEN the `gentle-ai-assets` derivation builds
- THEN the derivation store contains `share/gentle-ai/review-gate.md`
- AND `shared/claude-code.nix` references that derivation path

### RG-002: Content Correctness

The review gate file MUST present exactly 3 options: done, retry, reiterate. The file MUST NOT present a fourth option. The content MUST be platform-agnostic (no OpenCode-specific or Claude-specific tool references).

#### Scenario: Gate presents exactly 3 options

- GIVEN the review gate file is read after an `sdd-apply` slice
- WHEN the orchestrator presents options to the user
- THEN exactly 3 options appear: done, retry, reiterate
- AND no fourth option exists

#### Scenario: Platform-agnostic content

- GIVEN the gate file is deployed to both OpenCode and Claude Code
- WHEN the file is read on either platform
- THEN no tool-specific references (e.g., "claude", "opencode") appear in the gate prose

### RG-003: No Regression

OpenCode's review gate behavior MUST remain identical to current state. `shared/opencode.nix` MUST NOT be modified. OpenCode's existing orchestrator overlay deployment path MUST NOT change.

#### Scenario: OpenCode unchanged

- GIVEN the existing review-gate.md in OpenCode's orchestrator overlay
- WHEN this change is deployed
- THEN `git diff` on `shared/opencode.nix` and `shared/opencode/assets/opencode/review-gate.md` shows zero changes

### RG-004: Claude Code Gain

Claude Code MUST have `~/.claude/review-gate.md` after deployment containing done/retry/reiterate. The file MUST be sourced from `${pkgs.gentle-ai-assets}/share/gentle-ai/review-gate.md` via `shared/claude-code.nix`. The derivation path MUST be reachable via the `extraAssetsShared` mechanism in `lib/packages.nix` and `pkgs/gentle-ai-assets/default.nix`.

#### Scenario: Claude Code receives review gate

- GIVEN a fresh deployment on any host
- WHEN home-manager switch runs
- THEN `~/.claude/review-gate.md` exists with done/retry/reiterate content
- AND the file is sourced from the derivation `${pkgs.gentle-ai-assets}/share/gentle-ai/review-gate.md`
- AND the source originates at `shared/assets/review-gate.md`

### RG-005: Host Coverage

All 4 hosts (rog, thinkcentre, t14, mact2) MUST deploy `review-gate.md` to `~/.claude/review-gate.md` via `shared/claude-code.nix`.

#### Scenario: All hosts covered

- GIVEN any of rog, thinkcentre, t14, or mact2
- WHEN home-manager switch runs
- THEN `~/.claude/review-gate.md` exists with the done/retry/reiterate gate content
