# Proposal: Point gentle-ai to fork main + fix PR #988 CodeRabbit comments

## Intent

PR #988 (SDD path convention fixes) is open on upstream `Gentleman-Programming/gentle-ai` but unmerged. CodeRabbit left 3 unresolved comments. Point nixos-hosts to `glats/gentle-ai/main` (fork with fixes applied) so the path convention fixes are available NOW without waiting for upstream merge.

## Scope

### In Scope
- Sync `glats/gentle-ai/main` with upstream `Gentleman-Programming/gentle-ai/main`
- Apply 3 CodeRabbit nits to skill files on fork's `main` branch:
  1. sdd-apply: Add standalone "Filesystem path convention" bolded note
  2. sdd-archive: Fix archive path to `openspec/changes/archive/YYYY-MM-DD-{change-name}/`
  3. sdd-explore: Add explicit "Output Contract" section
- Fix MD022 markdownlint warnings on sdd-apply + sdd-explore
- Change `gentle-ai-src.url` in `flake.nix` from `github:Gentleman-Programming/gentle-ai/main` to `github:glats/gentle-ai/main`
- Lock update: `nix flake lock --update-input gentle-ai-src`

### Out of Scope
- Merging PR #988 upstream
- Changing `gentle-ai` consumers in nixos-hosts (vanilla.nix, default.nix) — unchanged
- Switching back to upstream after PR merges (future concern)

## Capabilities

### New Capabilities
None — config change + doc-only fixes.

### Modified Capabilities
None — no spec-level behavior changes.

## Approach

1. **Sync fork main**: Pull upstream `Gentleman-Programming/gentle-ai/main` into `glats/gentle-ai/main`
2. **Apply fixes** to `glats/gentle-ai/main`: 3 skill files edited (~10 lines total)
3. **Point nixos-hosts**: Change flake URL → lock update → verify

## Files Changed

### glats/gentle-ai (fork)
| File | Change |
|------|--------|
| `internal/assets/skills/sdd-apply/SKILL.md` | +3 lines (path convention note) + MD022 fix |
| `internal/assets/skills/sdd-archive/SKILL.md` | Fix archive path to full canonical form |
| `internal/assets/skills/sdd-explore/SKILL.md` | +4 lines (Output Contract section) + MD022 fix |

### glats/nixos-hosts
| File | Change |
|------|--------|
| `flake.nix` L44 | URL: `Gentleman-Programming` → `glats` |
| `flake.lock` | Auto-regenerated (`--update-input gentle-ai-src`) |

## Risks

| Risk | L | Mitigation |
|------|---|------------|
| Fork `main` drifts from upstream | Low | Synced before applying fixes. If upstream adds competing changes, re-sync and re-apply fixes |
| nixos-hosts build breaks after lock update | Low | `nix flake check --no-build` after lock update |
| MD022 fix accidentally changes YAML frontmatter behavior | Low | Only blank-line additions; no content changes |

## Rollback

- **nixos-hosts**: `git checkout -- flake.nix flake.lock` or revert commit
- **gentle-ai fork**: Revert commit or force-push to previous `main` SHA

## Verification

- [ ] `glats/gentle-ai/main` has 3 skill file fixes applied
- [ ] `nix flake lock --update-input gentle-ai-src` succeeds on nixos-hosts
- [ ] `nix flake check --no-build` passes on nixos-hosts
- [ ] Skill file fixes are syntactically valid markdown (no broken YAML frontmatter)
