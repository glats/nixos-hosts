# Archive Report: scrub-sensitive-data

**Archived**: 2026-07-06
**Status**: Complete - All 3 stages deployed

---

## Summary

Sensitive data (PII: full name, work email, personal email) scrubbed from the codebase and git history. Identity labels renamed from `glats`/`jcuzmar` to `personal`/`work` across all Nix attrsets, sops paths, MCP wrappers, and configs.

## Timeline

| Phase | Date | Artifact |
|-------|------|----------|
| Preflight | 2026-07-06 | `sdd/scrub-sensitive-data/preflight` |
| Exploration | 2026-07-06 | `openspec/changes/scrub-sensitive-data/exploration.md` |
| Proposal | 2026-07-06 | `openspec/changes/scrub-sensitive-data/proposal.md` |
| Spec | 2026-07-06 | `openspec/changes/scrub-sensitive-data/specs/` (5 domains) |
| Design | 2026-07-06 | `openspec/changes/scrub-sensitive-data/design.md` |
| Apply (Stage 1) | 2026-07-06 | Commit `f243db7` + `ed122b3` |
| Apply (Stage 2) | 2026-07-06 | Commit `549e7a3` |
| Apply (Stage 3) | 2026-07-06 | `git filter-repo` + force push |
| Archive | 2026-07-06 | This report |

## Artifacts

### Engram (remembered)
- `sdd/scrub-sensitive-data/preflight` (#569)
- `sdd/scrub-sensitive-data/explore` (#570)
- `sdd/scrub-sensitive-data/proposal` (#571)
- `sdd/scrub-sensitive-data/spec` (#572)
- `sdd/scrub-sensitive-data/design` (#573)
- `sdd/scrub-sensitive-data/tasks` (#574)
- `sdd/scrub-sensitive-data/archive-report` (this)
- `SDD Apply Stage 1 — scrub-sensitive-data` (#575)

### Filesystem (archived)

```
openspec/changes/archive/2026-07-06-scrub-sensitive-data/
├── archive.md              (this report)
├── exploration.md
├── proposal.md
├── design.md
├── specs/
│   ├── sops-identity-storage/spec.md
│   ├── identity-label-rename/spec.md
│   ├── history-scrub/spec.md
│   ├── backward-compat/spec.md
│   └── gh-auth/spec.md
└── tasks.md
```

## Delta Spec Sync

| Domain | Main Spec Exists? | Sync Action |
|--------|-------------------|-------------|
| `gh-auth` | `openspec/specs/gh-auth/spec.md` | Already applied (PII removed, sops references in place) |
| `sops-identity-storage` | No main spec | New domain — no sync target |
| `identity-label-rename` | No main spec | New domain — no sync target |
| `history-scrub` | No main spec | New domain — no sync target |
| `backward-compat` | No main spec | New domain — no sync target |

## Commits Produced

| Commit | Message | Stage |
|--------|---------|-------|
| `f243db7` | `feat(scrub-sensitive-data): stage 1 — encrypt PII and rename identity labels to personal/work` | Stage 1 |
| `ed122b3` | `chore: add encrypted identity secrets` | Stage 1b |
| `549e7a3` | `feat(scrub-sensitive-data): stage 2 — rename identity labels to personal/work` | Stage 2 |
| `5c01124` | `chore: scrub remaining PII from SDD artifacts` | Stage 2 cleanup |

## Verification Evidence

### Stage 1 — Encrypt PII
- `shared/git-identity.nix`: Zero PII matches (verified via grep)
- `docs/multi-github-identity.md`: Zero PII matches, sops references present
- `openspec/specs/gh-auth/spec.md`: Zero PII matches, sops references in place
- `secrets/user/identities.yaml`: Created and sops-encrypted
- `.sops.yaml`: Rule added for identities.yaml with all 5 host age keys

### Stage 2 — Rename Labels
- `identities.glats` / `identities.jcuzmar`: Zero matches in home-linux/, home-darwin/, shared/
- System usernames preserved: `users.users.glats` still present, `users.users.personal` not present
- MCP wrappers: `github-mcp-server-personal` and `github-mcp-server-work` created alongside old wrappers
- MCP configs: `github-personal` and `github-work` entries added alongside old entries
- Token check labels: Updated to `"personal"` / `"work"`

### Stage 3 — History Scrub
- `pre-history-scrub` tag exists and points to pre-scrub HEAD (`549e7a3`)
- `git log --all --format="%ae" | sort -u` shows only redacted emails (personal@example.com, work@example.com, glats@local, glats@nixos-*, glats@users.noreply.github.com, github-actions[bot])
- Author emails with original PII domains scrubbed from all reachable history

## Technical Debt (Not Archived)

| Item | Impact | Recommendation |
|------|--------|----------------|
| Old sops alias declarations still in `modules/base/sops.nix` and `shared/sops.nix` (`pat_jcuzmar`, `gpg_glats_*`, `gpg_jcuzmar_*`) | Low — both old and new paths coexist and work | Remove after all hosts rebuilt with new paths |
| Old MCP wrappers (`github-mcp-server-glats`, `github-mcp-server-jcuzmar`) still defined | Low — old wrappers coexist with new ones | Remove after verifying new wrappers work on all hosts |
| Old MCP config entries (`github-glats`, `github-jcuzmar`) still in `mcps-base.nix` | Low — OpenCode shows both, user disables old ones | Manual cleanup after transition cycle |
| Old sops keys still in `secrets/shared/passwords.yaml` | Low — encrypted blobs, no security impact | Remove via `sops edit` after transition |
| System usernames (`glats` on Linux, `jcuzmar` on macOS) | Not PII — these are OS-level usernames | Preserved by design |

## Delivery Metrics

- **Total change size**: ~400+ lines across 4 commits
- **Files created**: 1 (`secrets/user/identities.yaml`)
- **Files modified**: ~15 (Stage 1: 7 files, Stage 2: ~8 files)
- **History rewritten**: Entire git history via filter-repo
- **Delivery strategy**: Single PR sequenced (Stage 1 → 2 → 3)
- **Delivery strategy budget**: Standard (400 lines) — Medium risk, no chained PRs needed

## Skill Resolution

`paths-injected` — sdd-archive skill loaded by orchestrator
