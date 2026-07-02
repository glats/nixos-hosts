# Tasks: anti-hallucination-sdd-paths

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 700-1100 (3 full vanilla copies dominate) |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1: packaging foundation; PR 2: override content + source switch |
| Delivery strategy | single-pr-default |
| Chain strategy | pending (stacked-to-main recommended) |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: pending
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | PR | Base |
|------|------|-----|------|
| 1 | Add `extraAssets` derivation parameter; wire in `lib/packages.nix` | PR 1 | main |
| 2 | Add 3 override files in `shared/opencode/assets/`; switch `shared/opencode.nix:100` source | PR 2 | PR 1 branch |
| 3 | Upstream PR to `Gentleman-Programming/gentle-ai` (Track 2) | n/a | n/a |

## Phase 1: Packaging Foundation (PR 1)

- [x] 1.1 `pkgs/gentle-ai-assets/default.nix` — add `extraAssets ? null` to args; add `cp -r ${extraAssets}/. $TEMP_DIR/` block in `installPhase` after `extraCommands` (Nix-level conditional, same pattern as `extraCommands`)
- [x] 1.2 `lib/packages.nix` — add `extraAssets = ./../shared/opencode/assets` to `sharedOpencodePaths`; `inherit (sharedOpencodePaths) extraAssets` in both `linuxPackages.gentle-ai-assets` and `darwinPackages.gentle-ai-assets` calls
- [x] 1.3 Validate: `nix flake check --no-build` + `nix build .#gentle-ai-assets` (no override content yet — vanilla output unchanged)
- [x] 1.4 `format-nix` on both modified `.nix` files

## Phase 2: Override Content + Source Switch (PR 2)

- [x] 2.1 `nix build .#gentle-ai-assets-vanilla`; copy `opencode/sdd-orchestrator.md`, `skills/sdd-explore/SKILL.md`, `skills/sdd-init/SKILL.md` from `${result}/share/gentle-ai/` to `shared/opencode/assets/` (NEVER from `~/.config/opencode/` — may be stale/patched)
- [x] 2.2 `shared/opencode/assets/opencode/sdd-orchestrator.md` — append `> **Filesystem path convention**: Engram topic keys use the sdd/ prefix for memory organization — this is NOT a filesystem path. The canonical filesystem directory for SDD artifacts is openspec/. Never reference .sdd/, sdds/, or bare sdd/ as filesystem paths. These do not exist.` after `Artifact Store Policy` (lines 69-74)
- [x] 2.3 `shared/opencode/assets/skills/sdd-explore/SKILL.md` — append `> **Filesystem path convention**: The SDD artifact directory is openspec/. Do NOT use sdd/, .sdd/, or sdds/ as filesystem paths — these do not exist. Engram topic keys use the sdd/ prefix for memory organization only.` after `Retrieving Context` section
- [x] 2.4 `shared/opencode/assets/skills/sdd-init/SKILL.md` — append same path-convention note (from 2.3) after `Hard Rules` section
- [x] 2.5 `shared/opencode.nix:100` — `${pkgs.gentle-ai-assets-vanilla}` → `${pkgs.gentle-ai-assets}` (deploy layered version, not vanilla)
- [x] 2.6 Validate build: `nix flake check --no-build`; `nix build .#gentle-ai-assets`; `grep -c "Filesystem path convention" result/share/gentle-ai/{opencode/sdd-orchestrator.md,skills/sdd-explore/SKILL.md,skills/sdd-init/SKILL.md}` ≥1 each
- [x] 2.7 `nixos-build dry`; ASK before `nixos-build switch` (per AGENTS.md "boundaries" — builds are long)
- [x] 2.8 After switch: `grep -c "Filesystem path convention" ~/.config/opencode/{sdd-orchestrator.md,skills/sdd-explore/SKILL.md,skills/sdd-init/SKILL.md}` ≥1 each (proposal success criterion; update proposal to match new wording)

## Phase 3: Track 2 — Upstream PR (separate, non-blocking)

- [ ] 3.1 Apply same 3 path-convention notes to `internal/assets/{opencode/sdd-orchestrator.md,skills/sdd-explore/SKILL.md,skills/sdd-init/SKILL.md}` in `Gentleman-Programming/gentle-ai` (verify section names against upstream layout)
- [ ] 3.2 Optional: add same note to `internal/assets/skills/_shared/sdd-phase-common.md` and `internal/assets/windsurf/workflows/sdd-new.md` (per design §Open Questions)
- [ ] 3.3 Open PR with rationale referencing this SDD change + local override PR
- [ ] 3.4 After merge: bump `gentle-ai-src` flake input in `flake.nix` + `flake.lock`; drop local `shared/opencode/assets/` override files (Track 2 supersedes Track 1)

## Notes

- Override files are FULL vanilla copies + appended note (design rationale: diffable, reviewable, regenerable on `nix flake update`). High line count is from file sizes, not new logic.
- Wording uses `Filesystem path convention` per user feedback — direct, not "Anti-hallucination". The proposal §"Success Criteria" grep command should be updated to match.
- Vanilla source for override files: `${pkgs.gentle-ai-assets-vanilla}/share/gentle-ai/` from nix store, NOT `~/.config/opencode/`.
- PR 1 establishes mechanism with no behaviour change (existing `extraSkills` still works); PR 2 deploys the actual notes. Both independently testable.
