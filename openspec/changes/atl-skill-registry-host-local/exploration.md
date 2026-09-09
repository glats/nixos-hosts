## Exploration: atl-skill-registry-host-local

### Current State

The repo tracks `.atl/skill-registry.md` (a machine-generated Gentle AI skill index) but ignores its companion `.atl/.skill-registry.cache.json`. The registry is produced by `gentle-ai skill-registry refresh`, wired into OpenCode startup via the `skill-registry` plugin, and also written by the `/skill-registry` skill and `sdd-init`. This repo pins `gentle-ai-src = github:Gentleman-Programming/gentle-ai/v2.5.0` (`flake.lock` rev `f5dd1a6cf1823371374c7b2bef5b71e4790a146a`, `flake=false`) and builds two derivations from it: `gentle-ai` (the Go binary) and `gentle-ai-assets` (the asset tree that ships the OpenCode plugins, incl. `skill-registry.ts`).

The registry is **inherently host-specific**, which is the root of the cross-host problem. Verified from the pinned upstream source `internal/skillregistry/registry.go` (blob `e3e84a744917ccf0e42cdc56bad1ed819b509af2` at `refs/tags/v2.5.0`):

- **Absolute paths.** `findAllSkillFiles` builds absolute `<root>/<skill>/SKILL.md` paths, and `LoadSkill` stores them verbatim in `SkillEntry.Path`; `RenderRegistry` emits them into the `Path` column. User-skill roots are absolute and never relativized.
- **"Sources scanned" is host-shaped.** The list is `filepath.Rel(cwd, dir)` only when a dir is *inside* the repo (`cwd`); every user-global skill root (`~/.agents/skills`, `~/.config/opencode/skills`, `~/.claude/skills`, `~/.codex/skills`, …) falls through to its absolute form. This repo has no project-local skills tracked — all four scanned roots are user-global — so the entire source list is absolute.
- **The H1 heading differs per checkout.** `RenderRegistry` uses `projectName := filepath.Base(cwd)`. Linux checkout `/home/glats/.nixos` → `# Skill Registry — .nixos`; mact2 checkout `/Users/jcuzmar/.config/nix` → `# Skill Registry — nix`.
- **"Last updated" is a wall-clock date.** `Last updated: time.Now().UTC().Format("2006-01-02")` — always differs by host/run.
- **No portability flags exist at v2.5.0.** The only render-affecting flag is `--force`. There is no `~`-prefix/relative-path option and no date-suppression option.
- **The cache is host-specific by construction.** `Fingerprint` hashes `schema:<n>` plus, per file, `path:mtime-ns:size:sha1(content)`. Absolute path + mtime guarantee the fingerprint differs across machines even when the skill *set* is identical.
- **Cache-hit never validates the md.** `Regenerate` returns early (`Reason: "cache-hit"`) when `!force && cached == fp && fileExists(registryPath)` — it does **not** check whether the existing md matches what discovery would produce.

Upstream's own default intent is to **not** track this directory: `EnsureATLIgnored(cwd)` appends `.atl/` to `.gitignore`, and it runs on every refresh *unless* `--no-gitignore` is passed. The startup plugin (and the Codex/Claude SessionStart hooks in `internal/components/sdd/inject.go`) pass `--no-gitignore` — so the startup path deliberately leaves `.gitignore` alone; the `/skill-registry` skill and `sdd-init` (which run without that flag) are the paths that *would* add the entry.

### Evidence: how the two hosts diverged

Local (Linux, user `glats`, checkout `/home/glats/.nixos`):

- `git ls-files .atl/` → only `.atl/skill-registry.md` is tracked; the cache is untracked. `git check-ignore` on both files exits 1 (nothing ignored today).
- Working tree: `M .atl/skill-registry.md` ("Last updated 2026-09-08", 4 sources: `~/.agents/skills`, `~/.config/opencode/skills`, `~/.claude/skills`, `~/.codex/skills`; all rows absolute `/home/glats/…`) + untracked cache fingerprint `de4d27bb…`. HEAD's committed md is the older 3-source "2026-09-06" version (no codex) — the registry has already drifted twice in two days on one host.
- Skill roots: `~/.agents/skills` → `rom-downloader` (a **symlink** to a nix store path — the scanner follows it via `os.Stat`), `~/.config/opencode/skills` → 61 dirs, `~/.claude/skills` → 61 dirs, `~/.codex/skills` → `.system/` only (contributes 0 top-level skills).

mact2 (macOS, user `jcuzmar`, checkout `/Users/jcuzmar/.config/nix`, read-only via `ssh mact2.local`):

- `.atl/skill-registry.md` tracked and clean (`== HEAD`), content is the **Linux-generated** registry ("# Skill Registry — .nixos", "Last updated 2026-09-06", 3 sources, `/home/glats/…` paths). Cache untracked, fingerprint `d568caba…` (≠ Linux's `de4d27bb…`).
- Skill roots present: `~/.config/opencode/skills` → 61 dirs, `~/.claude/skills` → 61, `~/.codex/skills` → 5; `~/.agents/skills` **MISSING** (so `rom-downloader` is absent). A correct mact2 refresh would emit `/Users/jcuzmar/…` paths and a different source list — it never did.
- The deployed plugin `~/.config/opencode/plugins/skill-registry.ts` is **patched** with the worktree-root fallback (`worktreeIsRoot`), and `gentle-ai` is the nix-built binary at `/etc/profiles/per-user/jcuzmar/bin/gentle-ai`. So mact2's refresh is *not* skipped by the cwd bug or the project-marker guard.

`.gitignore` history on Linux explains how the file got tracked: commit `6f350b1 "chore: add remmina, tmux status-position, gitignore .atl"` added `.atl/` to `.gitignore`; commit `d78893e "openspec updated and atl ini"` **removed** that line to make `.atl/skill-registry.md` committable. The three commits touching `.atl` are `d78893e`, `8a87039 "init sdd"`, `7255cd3 "updated sklls registry"` (all already on `origin`).

### Root cause of mact2's stale md (question 3)

The failure is the **cache-hit-on-stale-md** semantics, not the plugin cwd bug and not the guard:

1. mact2 has an untracked, host-local cache whose fingerprint `d568caba…` matches mact2's *own* current skill set (`/Users/jcuzmar/…` paths + mtimes + contents).
2. `git clone/checkout/pull` restored the **committed Linux md** over mact2's local copy, but left the untracked cache in place.
3. Every startup refresh computes `fp == d568caba`, reads `cached == d568caba`, sees `fileExists(md) == true`, and returns `cache-hit` without touching the md. The md stays Linux-stale forever because cache-hit never validates md content against discovery.

This is self-perpetuating: the cache correctly tracks mact2's reality while the md tracks Linux's reality, and the cache-hit rule trusts the cache over the md. Only a `--force` refresh (or deleting the cache) would rewrite the md — and then git would flag the md as modified, recreating the cross-host churn. The two files can never be made consistent on two hosts while the md is tracked and the cache is not.

### Affected Areas

- `.atl/skill-registry.md` — tracked, host-specific generated index; the source of the cross-host conflict.
- `.atl/.skill-registry.cache.json` — untracked, host-specific; drives the cache-hit that masks the stale md on mact2.
- `.gitignore` — must gain a `.atl/` entry (upstream's own `EnsureATLIgnored` default).
- No Nix file is touched: `gentle-ai`/`gentle-ai-assets` derivations, `shared/opencode/runtime-config.nix`, and the `pkgs/gentle-ai-assets/skill-registry-worktree-root.ts` local plugin override all continue to work unchanged. The plugin override is orthogonal to this change (it fixes cwd resolution on git-less workspaces; this change is about *not tracking* the registry output).

### Approaches

1. **A — Host-local (gitignore the whole `.atl/`), recommended.** Add `.atl/` to `.gitignore` and `git rm -r --cached .atl` so neither the md nor the cache is tracked. Each host regenerates its own registry + cache at startup; the stale-md divergence becomes impossible because there is no committed md to restore.
   - Pros: zero upstream change; zero `flake.lock` bump; the registry is correct on every host automatically; removes the cache-vs-md desync class entirely; matches upstream's default intent (`.atl/` gitignored); the startup plugin already regenerates on a fresh clone (`.git` is a project marker, no cache → fingerprint mismatch → rewrite).
   - Cons: the registry is no longer versioned (irrelevant — it is a disposable index regenerated on every launch, and delegators read it from disk/Engram, not git); requires one manual untrack step per host.
   - Effort: **Low**.

2. **B — Track a normalized/portable registry.** Requires upstream changes that do not exist at v2.5.0: `~`-prefixed relative paths, date suppression, cache exclusion from git, and a stable cross-host source list. Even if all four landed, the *skill set itself* still diverges per host (Linux has `~/.agents/skills/rom-downloader` via symlink and a 1-entry codex root; mact2 lacks `~/.agents/skills` entirely and has a 5-entry codex root; 61-vs-61 opencode/claude counts hide different contents) — so a tracked registry would still churn on every cross-host refresh. Requires bumping the `gentle-ai-src` pin (asset + binary rebuild + `flake.lock` update) or forking.
   - Pros: registry remains inspectable in git (low value — it's regenerated each launch).
   - Cons: high effort; blocked on upstream features; **does not actually solve the divergence** because skill sets differ; couples this repo's config to an unpinned upstream feature.
   - Effort: **High**.

3. **C — Hybrid: track the md, ignore only the cache.** Keeps the md in git but ignores the cache. This is exactly today's state and is what produced the mact2 stale-md bug, so it is not a fix — it only moves the churn from the cache to the md.
   - Pros: none over A.
   - Cons: reintroduces the exact cross-host conflict this exploration exists to solve.
   - Effort: Low (but wrong).

### Recommendation

**Approach A — make `.atl/` host-local.** The registry is 100% host-specific by design (absolute user-global paths, host-shaped "Sources scanned", `filepath.Base(cwd)` heading, wall-clock date, path+mtime fingerprint), it carries no project-local content, and it is regenerated from scratch on every OpenCode start. Tracking it can only ever produce cross-host churn, and the current half-tracked state (md tracked, cache ignored) actively produces a stale registry on mact2 that would send delegators to nonexistent `/home/glats/…` paths. Gitignoring both files is the only option with zero upstream dependency, zero `flake.lock` impact, and a complete fix. Approach B is rejected because even a fully "portable" renderer cannot paper over the differing per-host skill sets.

### Migration outline

1. On both hosts, add a `.gitignore` entry under a "# Local AI runtime state" header (matching upstream `EnsureATLIgnored`'s own convention): `.atl/`.
2. Untrack the md on both hosts: `git rm -r --cached .atl` (the cache is already untracked; the local files remain on disk).
3. Commit the `.gitignore` change + the untrack as a single fix-forward commit (do **not** rewrite history — `7255cd3`, `8a87039`, `d78893e` are already pushed to `origin`, and the blobs are a disposable index, not secrets).
4. On next OpenCode start each host regenerates its own correct registry; `git status` stays clean on both.
5. Note: the repo-local `/skill-registry` skill and `sdd-init` run without `--no-gitignore`, so upstream will idempotently re-assert `.atl/` in `.gitignore` — consistent with this change, no conflict.

### Verification plan (for the eventual change)

- `.gitignore` change is nix-free, so `format-nix && nix flake check --no-build` is expected to be a no-op for this diff (no `.nix` files touched); still run it to keep the repo's required verification green.
- After untracking, `git check-ignore -v .atl/skill-registry.md .atl/.skill-registry.cache.json` must report both as ignored on both hosts.
- Fresh-clone regeneration proof: on a clean clone, the patched startup plugin spawns `gentle-ai skill-registry refresh --quiet --no-gitignore --cwd <root>`; guard.go `hasProjectMarker` accepts `.git`, and with no cache present the fingerprint mismatch forces a rewrite — so `.atl/` appears with host-correct paths. (Evidence: `registry.go` cache-hit branch requires a matching cache + existing md; `guard.go` returns `SkipNone` for a git checkout.)
- Both hosts' trees stay clean (`git status --porcelain` empty for `.atl/`) after a startup refresh.

### Open questions for the user

1. Do you also want the startup plugin override (`pkgs/gentle-ai-assets/skill-registry-worktree-root.ts`) audited for removal once upstream ships the worktree-root fix (issue #1731 / PR #2079)? That is a separate, optional upstream-alignment task — this change does not depend on it.
2. Is there any tooling in your workflow that reads `.atl/skill-registry.md` from *git* rather than from disk or Engram? The SDD common protocol falls back to reading `.atl/skill-registry.md` from the repo root on disk, and Engram holds observation `457` (`skill_registry`) — neither needs the file tracked. Confirm nothing else consumes the tracked file before untracking.
3. Should the `.atl/` ignore entry use upstream's exact `.atl/` form, or the `.atl/*` + `!.atl/…` exception form (relevant only if a future upstream feature ever wants a *tracked* file inside `.atl/`, per issue #1562)? Recommend plain `.atl/` now.

### Ready for Proposal

Yes. The recommendation is a two-line change (`.gitignore` entry + untrack) with no upstream dependency, no `flake.lock` impact, and a complete fix for the cross-host conflict. The orchestrator should tell the user: "Don't try to make the registry portable — it is host-specific by design (absolute paths, per-host skill sets, wall-clock date, path+mtime fingerprint), and upstream v2.5.0 has no relative-path or date-suppression options. The right fix is to stop tracking `.atl/` entirely: gitignore both files and untrack the md, then let each host regenerate its own registry at startup. That also removes the cache-hit bug that is silently leaving a stale Linux registry on mact2."
