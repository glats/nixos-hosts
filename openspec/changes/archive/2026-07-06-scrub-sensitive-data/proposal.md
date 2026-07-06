# Proposal: scrub-sensitive-data

## Intent

The codebase contains plaintext PII -- full name `Redacted Name`, work email `work@example.com`, and personal email `personal@example.com` -- in `shared/git-identity.nix`, OpenSpec specs, docs, and git history. Identity labels (`glats`/`jcuzmar`) leak personal vs. work affiliation across 30+ files. This change encrypts the PII, renames identity labels to `personal`/`work`, and scrubs git history.

## Scope

### IN scope

| Area | Action |
|------|--------|
| PII values (name, emails) | Encrypt via sops (`secrets/user/identities.yaml`); replace plaintext Nix strings with sops-path references |
| Identity attrset keys | Rename `glats` -> `personal`, `jcuzmar` -> `work` in `shared/git-identity.nix` and all consumers |
| Sops secret paths | Rename `github/pat_jcuzmar` -> `github/pat_work`, `gpg_glats_*` -> `gpg_personal_*`, `gpg_jcuzmar_*` -> `gpg_work_*` |
| MCP wrapper binaries | `github-mcp-server-glats` -> `github-mcp-server-personal`, `github-mcp-server-jcuzmar` -> `github-mcp-server-work` |
| MCP config names | `github-glats` -> `github-personal`, `github-jcuzmar` -> `github-work` |
| Git history | `git filter-repo` to remove all traces of `work@example.com` and `Redacted Name` |
| Live specs/docs | Redact PII from `openspec/specs/gh-auth/spec.md`, `docs/multi-github-identity.md` |

### OUT of scope

| Area | Reason |
|------|--------|
| System usernames (`glats` on Linux, `jcuzmar` on macOS) | Tied to OS -- rename breaks home paths, SSH, service users |
| SSH host configs (`github-personal`, `github-enterprise`) | Already using `personal`/`*` naming -- no change needed |
| GPG key fingerprints | Public identifiers by design -- stay plaintext |
| Archived OpenSpec artifacts | Historical audit trail preserved as-is (git history scrub handles exposure) |
| Omarchy theme slug `"glats"` | Cosmetic only, no PII |

## Technical Approach

3-stage implementation to isolate risk:

**Stage 1 -- Encrypt PII**: Create `secrets/user/identities.yaml` under sops with `personal` and `work` name/email. Replace plaintext in `shared/git-identity.nix` with file-path references resolved at HM activation time. GPG fingerprints remain in Nix.

**Stage 2 -- Rename labels**: Rename `glats` -> `personal`, `jcuzmar` -> `work` across all Nix attrset keys, sops paths, MCP wrappers, and config. Add backward-compat sops aliases so old paths work during transition.

**Stage 3 -- Scrub history**: `git filter-repo` with text-replacement for `work@example.com`, `Redacted Name`. Force push to GitHub. Single-user repo minimizes coordination risk.

## Capabilities

Capabilities that MUST be covered by delta specs:

1. **Encrypted identity storage**: Name/email values stored under sops, NOT plaintext in Nix files
2. **Identity label rename**: All git/config/MCP labels use `personal`/`work` instead of `glats`/`jcuzmar`
3. **Git config continuity**: `user.name`/`user.email` resolve correctly on all Linux and Darwin hosts after rename
4. **Sops backward compatibility**: Old secret paths resolve during one-transition-cycle alias period
5. **Git history clean**: Zero occurrences of `work@example.com` or `Redacted Name` in reachable history after Stage 3
6. **System username preservation**: No `users.users.glats`, `/home/glats`, or `/Users/jcuzmar` references changed

## Affected Areas

- **Files**: `shared/git-identity.nix`, `home-linux/git.nix`, `home-darwin/git.nix`, `home-linux/gpg.nix`, `home-darwin/gpg.nix`, `shared/sops.nix`, `modules/base/sops.nix`, `modules/features/services/github-mcp-server.nix`, `home-darwin/github-mcp-server-wrapper.nix`, `shared/opencode/mcps-base.nix`, `modules/features/services/github-token-check.nix`, `flake.nix`
- **Secrets**: `secrets/user/identities.yaml` (new), `secrets/shared/passwords.yaml` (key renames)
- **Docs**: `docs/multi-github-identity.md`, `openspec/specs/gh-auth/spec.md`
- **Hosts**: All (rog, thinkcentre, t14, mact2) -- git identity applies to all

## Risks

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| HM fails if sops secrets unavailable | Medium | Conditional `lib.mkIf` + activation fallback |
| Git worktrees break during history rewrite | High | Prune all worktrees first (`code-work --done`) |
| Force push invalidates open branches | Low | Check no open PRs exist before Stage 3 |
| Build fails during label rename transition | Medium | Test `nix flake check --no-build` after each stage |

## Rollback Plan

**Per-stage rollback**:
- Stage 1: Revert to plaintext `shared/git-identity.nix` (git-revertable)
- Stage 2: Revert rename commits; old sops aliases protect against runtime issues
- Stage 3: Restore from pre-filter-repo backup ref (`refs/pre-scrub-backup`), force push that

**Global rollback**: If Stages 1-2 are committed but Stage 3 fails, the PII is already encrypted in HEAD -- the risk is only in history. Pre-filter-repo, create a tag `pre-history-scrub` for recovery. Post-filter-repo, `git push --force` to GitHub.

## Phases

| Phase | Deliverable | Dependencies |
|-------|-------------|--------------|
| 1. sops encrypt | `secrets/user/identities.yaml` + HM activation wiring | None |
| 2. Label rename | All Nix/MCP/sops renames + backward compat | Phase 1 |
| 3. History scrub | `git filter-repo` + force push | Phases 1-2 committed and stable |

## Success Criteria

- [ ] `shared/git-identity.nix` contains zero plaintext PII
- [ ] `identities.personal.name` and `identities.work.name` resolve correctly via sops
- [ ] `git config user.name` returns correct values on all hosts after rebuild
- [ ] `nix flake check --no-build` passes on all hosts
- [ ] `git log --all --oneline | xargs -I{} git show {} | grep -i "falabella"` returns empty
- [ ] System usernames (`glats`/`jcuzmar`) unchanged in `/etc/passwd`, home paths, SSH configs
