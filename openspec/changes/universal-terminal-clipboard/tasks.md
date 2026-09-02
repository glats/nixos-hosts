# Tasks: Universal Terminal Clipboard

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 250-450 |
| 400-line budget risk | Medium |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Medium

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Confirm Wetty support before any frontend/pin work | PR 1 | Evidence review + live/inspect check on rog | Wetty container/image inspection on rog | Drop all Wetty-specific assumptions |
| 2 | Document routing matrix and terminal policies | PR 1 | `nix flake check --no-build` | Manual copy/reattach scenarios | Remove docs only |

## Phase 1: Evidence Spike and Scope Lock

- [x] 1.1 Inspect `wettyoss/wetty` upstream, deployed image, or `rog` runtime to prove whether Wetty really handles OSC 52 + Clipboard API; record exact evidence in notes before any pin/frontend decision.
- [x] 1.2 If Wetty support is absent or unclear, stop at a documented unsupported/custom-frontend decision; do not assume or invent browser clipboard support.
- [x] 1.3 Reconfirm the target file list and host scope from `openspec/changes/universal-terminal-clipboard/{proposal.md,design.md,specs/terminal-clipboard-routing/spec.md}`.

## Phase 2: Documentation Matrix and Boundary Policy

- [x] 2.1 Create `docs/terminal-clipboard.md` with a receiver-by-flow matrix for tmux, nested tmux, SSH, OpenCode, Ghostty, Kitty, Alacritty, MATE/XRDP, Wetty, and kmscon.
- [x] 2.2 Add explicit rows for primary path, fallback (`tmux paste-buffer`), supported/unsupported status, and the exact limit or boundary for each flow.
- [x] 2.3 Document XRDP/`cliprdr` reconnect behavior as a verification outcome, and state the `tmux` buffer survival boundary separately from RDP clipboard continuity.
- [x] 2.4 Document kmscon as a bounded console path with no promised external clipboard, and note reattach-from-supported-client as the recovery path.
- [x] 2.5 Add Kitty/Alacritty policy statements only after version-specific verification; keep them marked unverified until checked.

## Phase 3: Verification Plan and Manual Tests

- [x] 3.1 Write manual test cases for local tmux copy, SSH passthrough, nested tmux passthrough, and OpenCode copy using the same OSC 52 contract.
- [x] 3.2 Write manual Wetty tests covering HTTPS/secure-context clipboard write, focus/gesture requirement, and oversized payload rejection or truncation.
- [x] 3.3 Write manual XRDP tests for disconnect/reconnect, confirming `tmux paste-buffer` survives and recording `cliprdr` behavior.
- [x] 3.4 Write negative tests for MATE/VTE and kmscon showing no external clipboard guarantee and no remote clipboard tool fallback.

## Phase 4: Nix Checks and Completion Gates

- [x] 4.1 Define the exact Nix verification commands to run after any future `.nix` edit, including `format-nix` and `nix flake check --no-build`.
- [x] 4.2 Add host-specific build/switch notes for the touched Linux hosts and `rog` if Wetty or receiver policy work later requires config changes.
- [x] 4.3 Mark the change complete only when the docs matrix, Wetty evidence spike, and manual verification plan are all in place.
