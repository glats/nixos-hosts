# Proposal: Make the ATL Skill Registry Host-Local

## Intent

Stop versioning host-specific `.atl/` output. Linux already has a modified registry plus untracked cache; mact2 has a clean but incorrect Linux-generated registry frozen by cache-hit behavior. Each checkout should regenerate its own runtime state without Git churn.

## Scope

### In Scope
- Add `.atl/` under a `# Local AI runtime state` heading in repo-root `.gitignore`.
- Run `git rm -r --cached .atl/skill-registry.md`; keep generated files locally.
- Fix forward on Linux, commit, and push. Then mact2 user `jcuzmar`, repo `~/.config/nix`, pulls the shared branch and refreshes locally. This avoids duplicate commits and races.
- Rely on OpenCode startup or `/skill-registry` for regeneration.

### Out of Scope
- History rewriting, `flake.lock` updates, upstream changes, or plugin, skill, and Nix changes.
- Optional follow-ups: report upstream stale-md/portability behavior; document `EnsureATLIgnored` defaults.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
None; this is generated-state repository hygiene.

## Approach

Adopt exploration Approach A: ignore the generated directory and remove its tracked index entry. After mact2 pulls, force refresh (or remove its cache first) so the stale Linux md becomes a `/Users/jcuzmar/...` registry. Git can no longer restore a foreign md beside a host-local cache.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `.gitignore` | Modified | Ignore `.atl/`. |
| `.atl/skill-registry.md` | Untracked | Remove from Git's index only. |
| Linux, mact2 checkouts | Migrated | Push once; pull and refresh once. |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Registry read before first startup | Low | Consumers tolerate absence; startup regenerates it and `/skill-registry` can force refresh. |
| Old registry remains in history | Certain | It is harmless generated data; fix forward. |

## Rollback Plan

Revert the commit to track the registry again; regenerate before recommitting.

## Dependencies

- Existing Gentle AI v2.5.0 generator and OpenCode startup plugin.
- SSH access to mact2 and a synchronized shared branch.

## Success Criteria

- [ ] `git check-ignore -v .atl/skill-registry.md .atl/.skill-registry.cache.json` succeeds on both hosts.
- [ ] `git status --porcelain` shows no `.atl/` entries after startup refresh on either host.
- [ ] Forced refresh yields `.nixos` plus `/home/glats/...` on Linux, and `nix` plus `/Users/jcuzmar/...` on mact2.
- [ ] A fresh clone regenerates `.atl/` after startup and remains clean.

## Task Breakdown Preview

1. Commit and push the Linux ignore/untrack change.
2. Pull on mact2, clear stale cache if needed, and force refresh.
3. Run per-host ignore, cleanliness, content, and fresh-clone checks. `format-nix` and flake evaluation are not gates because no Nix files change.

## Open Confirmations

None blocking. The optional upstream issue requires separate approval.
