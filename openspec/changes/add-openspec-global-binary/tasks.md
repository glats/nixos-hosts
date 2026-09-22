# Tasks: Add Global openspec Binary

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 2–6 authored lines (two list entries) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR (both platform shell modules) |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Append `pkgs.openspec` to both platform shell modules | PR 1 | `nix fmt -- linux/home/shell.nix darwin/home/shell.nix` + `nix flake check --no-build` | After activation on each host: `command -v openspec`, `openspec --version`, `openspec list --json` from a non-project directory | Remove the two added list entries; no files, secrets, or persistent state touched |

## Phase 1: Preflight and Source Proof

- [ ] 1.1 Record RED: from a directory without `project-init`, `command -v openspec` exits non-zero on the current host — the gap this change closes.
- [x] 1.2 Verify the lock-selected `pkgs.openspec` resolves for `x86_64-linux` and `aarch64-darwin` from pinned nixpkgs; record the resolved version (current lock: 1.4.1, not the proposal's 1.2.0). `flake.lock` (read-only).
- [x] 1.3 Confirm no flake input, overlay, wrapper, or `pkgs/nixos-scripts` change is required; the design threat matrix is entirely N/A, so no RED security task applies.

## Phase 2: Minimal Additive Edits

- [x] 2.1 Append `pkgs.openspec` to `home.packages` in `linux/home/shell.nix`; preserve `pkgs.nixos-scripts` and `pkgs.qrencode` unchanged.
- [x] 2.2 Append `pkgs.openspec` to `home.packages` in `darwin/home/shell.nix`; preserve `pkgs.nixos-scripts` unchanged.
- [x] 2.3 Inspect the diff: exactly two files changed, no removals, renames, reordering, or unrelated edits.

## Phase 3: Formatting and Evaluation

- [ ] 3.1 Run `nix fmt -- linux/home/shell.nix darwin/home/shell.nix` (cwd-scoped; never `format-nix` in a worktree).
- [ ] 3.2 Run `nix flake check --no-build`.
- [ ] 3.3 Evaluate `.#nixosConfigurations.{rog,thinkcentre,t14}.config.system.build.toplevel.drvPath`.
- [ ] 3.4 Evaluate `.#darwinConfigurations.macm5.config.system.build.toplevel.drvPath`; on an x86_64-linux runner record platform mismatch as evaluation-blocked, not failure.
- [ ] 3.5 Evaluate all four `.#homeConfigurations.<host>.activationPackage.drvPath` targets (rog, thinkcentre, t14, macm5).
- [ ] 3.6 JSON-eval each host's `home.packages` and assert `pkgs.openspec` appears exactly once.

## Phase 4: Runtime Verification

- [ ] 4.1 On rog, thinkcentre, and t14 after activation, run `command -v openspec`, `openspec --version`, and `openspec list --json` from a directory without `project-init`.
- [ ] 4.2 On macm5 after activation, run the same three commands from a directory without `project-init`.
- [ ] 4.3 Re-apply once and confirm `openspec` appears exactly once on PATH and existing packages remain installed (idempotence).

## Phase 5: Closeout

- [ ] 5.1 Confirm all proposal success criteria and that `add-project-init` and `pkgs/nixos-scripts` are untouched.
- [ ] 5.2 Record the lock-selected version and any platform-blocked evaluations in the change notes.
