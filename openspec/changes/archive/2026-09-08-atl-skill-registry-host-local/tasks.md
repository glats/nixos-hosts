# Tasks: Make the ATL Skill Registry Host-Local

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~3 (1 `.gitignore` line + 1 untrack deletion; no code) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR — one fix-forward commit |
| Delivery strategy | single-pr |
| Chain strategy | size-exception |

Decision needed before apply: Yes
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Linux gitignore + untrack + commit + push | PR 1 | `git check-ignore -v .atl/skill-registry.md .atl/.skill-registry.cache.json` (both exit 0) | `git status --porcelain` clean of `.atl/` after a startup refresh on Linux | Revert the single commit + `git add -f .atl/skill-registry.md`; regenerate before recommit |
| 2 | mact2 pull + cache clear + force refresh | PR 1 (post-push) | `ssh mact2.local` then `git check-ignore -v .atl/...` (both exit 0) | `gentle-ai skill-registry refresh --force` → `# Skill Registry — nix` + `/Users/jcuzmar/...` | Re-push revert, re-pull; delete regenerated cache to restore any prior state |

**Gating note**: this diff touches no `.nix` files, so `format-nix && nix flake check --no-build` is NOT a meaningful gate (harmless to run, expected no-op). The real gates are git cleanliness + `git check-ignore` + per-host regen.

**Commit hygiene (applies to T1)**: never rewrite history (commits `d78893e`, `8a87039`, `7255cd3` already on `origin`); single commit for the whole Linux change; do NOT include the untracked `openspec/changes/prune-declared-builtin-providers/` folder in the commit — stage only `.gitignore` and the `.atl/` untrack (`git add .gitignore` + `git rm -r --cached .atl`, then commit exactly those).

## Phase 1: Linux — gitignore + untrack + fix-forward commit

- [x] **T1 [any-host]** In repo-root `.gitignore` (read `home/glats/.nixos/.gitignore`), add a `# Local AI runtime state` heading with `.atl/` beneath it (upstream `EnsureATLIgnored` convention). Then `git rm -r --cached .atl` (keeps files on disk; cache already untracked). Commit as a single fix-forward commit: `chore(atl): keep skill-registry host-local — gitignore .atl/ and untrack it` — staging ONLY `.gitignore` and the `.atl/` deletion, explicitly NOT `openspec/changes/prune-declared-builtin-providers/`. Push to `origin`.
  Verify: `git check-ignore -v .atl/skill-registry.md .atl/.skill-registry.cache.json` both exit 0; `git status --porcelain` shows no `.atl/` entry; `git log --oneline -1` matches the commit; pushed ref matches `origin`.
  Rollback: `git revert <sha>` on Linux (track `.atl/` again) + `git add -f .atl/skill-registry.md`; regenerate before recommitting.
  Files touched: `.gitignore`, `.atl/skill-registry.md` (index untrack only).

## Phase 2: mact2 — pull + clear stale cache + force refresh

- [x] **T2 [mact2-host via `ssh mact2.local`]** As user `jcuzmar` in `~/.config/nix` (read-only except the sanctioned steps): `git pull` the shared branch; confirm a clean tree (`git status --porcelain`); delete the stale cache `rm -f .atl/.skill-registry.cache.json` only if present (it may hold a fingerprint that forces a cache-hit on the old Linux md); then `gentle-ai skill-registry refresh --force` so the stale Linux md is replaced by a host-correct `/Users/jcuzmar/...` registry.
  Verify: `git check-ignore -v .atl/skill-registry.md .atl/.skill-registry.cache.json` both exit 0; `git status --porcelain` clean of `.atl/`; regenerated md contains `# Skill Registry — nix` + `/Users/jcuzmar/...`.
  Rollback: re-push the reverted commit, re-pull, delete the regenerated cache to restore prior mact2 state.
  Files touched (mact2 only): `.atl/skill-registry.md`, `.atl/.skill-registry.cache.json` (regenerated, untracked).

## Phase 3: Verification — both hosts

- [x] **T3 [linux-host]** Startup refresh: launch OpenCode on Linux (or `/skill-registry`), then confirm `git status --porcelain` shows no `.atl/` entries and `git check-ignore -v .atl/skill-registry.md .atl/.skill-registry.cache.json` both report ignored. Confirm regenerated md heading `.nixos` + `/home/glats/...` paths.
  Verify: `git status --porcelain` empty for `.atl/`; both check-ignore exit 0; grep heading/paths.
- [x] **T4 [mact2-host]** Startup refresh: launch OpenCode on mact2 (or `/skill-registry`), then confirm `git status --porcelain` shows no `.atl/` entries and `git check-ignore -v .atl/skill-registry.md .atl/.skill-registry.cache.json` both report ignored. Confirm regenerated md heading `nix` + `/Users/jcuzmar/...` paths.
  Verify: `git status --porcelain` empty for `.atl/`; both check-ignore exit 0; grep heading/paths.
- [x] **T5 [any-host]** Fresh-clone regen sanity check in a temp dir (cheap): `git clone <origin> /tmp/opencode/atl-clone-test`, then trigger the skill-registry startup refresh there (or run `gentle-ai skill-registry refresh --force --no-gitignore --cwd <clone>`), and confirm `.atl/` is regenerated, `git check-ignore -v .atl/...` reports both ignored, and `git status --porcelain` is clean of `.atl/`.
  Verify: all three checks pass in the temp clone; optionally run `format-nix && nix flake check --no-build` as a no-op gate (expected to pass untouched).

## Cross-cutting

- [x] **C1** No `.nix` file changed anywhere in the diff; `gentle-ai`/`gentle-ai-assets` derivations and `shared/opencode/runtime-config.nix` untouched; no secrets decrypted or touched (mact2 ssh steps remain read-only except the sanctioned pull/cache-delete/refresh); history never rewritten (all prior `.atl` commits stay on `origin`).
