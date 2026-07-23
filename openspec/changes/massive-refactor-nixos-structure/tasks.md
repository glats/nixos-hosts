# Tasks: massive-refactor-nixos-structure

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 480–580 |
| 400-line budget risk | Medium |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

```
Decision needed before apply: Yes
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Medium
```

~515 lines: 250 deletions (orphans + profile chain), 80 new XML, 185 host rewrites + path updates. Most "additions" are extracted XML. Renames (45 ops) add 0 diff. Single PR feasible — content changes are mechanical substitutions. But flag because design estimates 500–700 and budget is 400. If reviewer wants <400, split: T1–T5 (zero content) as PR1, T6–T7 (content) as PR2, T8 as PR2 annex.

## Phase 1: Infrastructure (git mv — zero content)

- [ ] T1: Branch + target dirs. `git checkout -b refactor/nixos-flat-structure`. `mkdir -p linux/system darwin/system darwin/services shared/fontconfig`. Verify: `ls -d`.
- [ ] T2: Git mv module dirs. `git mv modules/{base,desktop,hardware,networking,features,virtualisation}/ linux/system/`. `git mv modules/darwin/{system,services}/ darwin/`. `git mv home-linux/ linux/home/ ; git mv home-darwin/ darwin/home/`. Delete empty profile dirs: `git rm modules/profiles/ modules/darwin/profiles/`. If `modules/` is empty after moves: `rmdir modules/`. ~45 renames + 2 deletes. Verify: `git status --short`.
- [ ] T3: Git mv services. `mkdir linux/system/services/{media,web,network}`. `git mv hosts/rog/services/*.nix` into media/web/network per design categories. `git mv hosts/thinkcentre/services/maquilinux-mounts.nix linux/system/services/`. 15 moves. Verify: `ls linux/system/services/*/`.
- [ ] T4: Fontconfig XML extraction. Create `shared/fontconfig/family-map.xml` (80-line dedup). Update `linux/system/desktop/fonts.nix` + `linux/home/fontconfig.nix` to import instead of inline XML. Verify: XML matches original.
- [ ] T5: Delete orphans. `git rm linux/home/opencode-theme.nix darwin/home/windsurf.nix darwin/home/mise-tools.nix`. Verify: files absent.

## Phase 2: Content changes

- [ ] T6: Rewrite host flat imports. Replace profile chain in `hosts/rog/default.nix` (50 imports), `hosts/thinkcentre/default.nix` (25 imports) with explicit lists per design manifests. Update `hosts/t14/default.nix` path prefix `../../modules/` → `../../linux/system/`. Verify: visual + census cross-ref.
- [ ] T7: Path ref updates (15 files). `flake.nix` path binds. `linux/system/base/home-manager.nix` depth fix. Both `shared-modules.nix`: `../shared/` → `../../shared/`. `darwin/default.nix` flatten + paths. `hosts/t14/home/omarchy.nix` + `default.nix` path updates. All `../shared/` refs across `linux/home/*.nix` + `darwin/home/*.nix` → `../../shared/`. `linux/home/mate.nix`: `../lib/` → `../../lib/`. Verify: `nix flake check --no-build`.

## Phase 3: Verification

- [ ] T8: Format + check. `format-nix && nix flake check --no-build`. `rg "modules/"` returns 0 (no stale paths). Verify: exit 0 on all 4 hosts.

## Notes

- T1–T5: zero content change. Revertable as git reset.
- T6+T7: real content. If combined diff >400, split into 2 PRs.
- T6 depends on T1–T5 (correct paths).
- T7 depends on T1–T5.
- T8 depends on all.
