## Exploration: t14-cleanup-hdm-waybar (code-only)

### Current State

**The code at HEAD is clean.** The waybar fix (migration from `waybar-git` overlay to stable `pkgs.waybar` + systemd user service) is fully deployed and working. All waybar-git experiment code was already removed in prior commits — the repo has zero waybar-src/waybar-git references anywhere.

**Git history** documents the complete evolution: waybar-git overlay experiment (5 commits), its revert (`7745e34`), and the final systemd-based fix (`7de121f`). The validator iteration commits (`d464361` through `c90bf2a`, `f2137fb`, etc.) and HDM doc commit (`55d20c1`) are legitimate development history. Per user directive: **no rebase, no history rewriting**.

**Both repos have clean working trees** — no staged or unstaged changes.

### Code Audit

| Check | Status | Detail |
|-------|--------|--------|
| `waybar-src` in `flake.nix` | ✅ ZERO | Removed in `7de121f` |
| `waybar-git` in `flake.nix` | ✅ ZERO | Removed in `7745e34` (revert) |
| `waybar-git` in `flake.lock` | ✅ ZERO | Confirmed via `grep -c waybar flake.lock` → 0 |
| `waybar-git` in `overlays/linux.nix` | ✅ ZERO | No waybar references ever existed there |
| Commented-out waybar-git code | ✅ ZERO | `rg -n "#.*waybar"` returns nothing |
| Waybar systemd service | ✅ CORRECT | Uses `pkgs.waybar`, Restart=always, StartLimitBurst=20, StartLimitIntervalSec="5s" |
| Workspace filter in monitors.nix | ✅ PRESENT | `persistent:${lib.boolToString (w <= 5)}` — workspaces 1-5 persist |
| `hyprctl reload` in validator | ✅ ZERO | `apply()` function has no reload call; validator uses polling-only |
| All t14 imports resolve | ✅ ALL OK | All 7 home imports + 2 host imports exist |
| `nix flake check --no-build` | ✅ PASSES | rog, thinkcentre, t14, darwin, formatter — all pass |

### What Needs Action

#### 1. format-nix — 88 Files Unformatted (CRITICAL)

The repository-wide formatter (`nixfmt 1.3.1`) reports **88 `.nix` files as unformatted**. This is the primary cleanup action. Files include:

- `flake.nix`
- All t14 files: `hosts/t14/default.nix`, `hardware-configuration.nix`, `home/default.nix`, `home/hypr/monitors.nix`, `home/omarchy.nix`
- `overlays/linux.nix`
- All darwin configs (4 files)
- All home-darwin configs (8 files)
- All home-linux configs (11 files)
- All rog services (9 files)
- All thinkcentre files (3 files)
- All lib files (4 files)
- All shared/opencode files (9 files)
- All pkgs derivations (10 files)
- Multiple modules (base, desktop, features, hardware, networking, virtualisation)

Running `format-nix` is a **purely cosmetic, deterministic operation** (nixfmt 1.3.1 is idempotent). It does not change semantics.

#### 2. omarchy-nix Untracked SDD Artifacts

The omarchy-nix repo (`/home/glats/repos/omarchy-nix`) has 4 untracked directories under `openspec/`:

| Directory | Contents | Status |
|-----------|----------|--------|
| `fix-screensaver-idle-lock/` | `upstream-comparison.md` (19KB research) | Research doc, likely superseded |
| `iwd-wifi-queda-en-upstream...` | `exploration.md` + `tasks.md` | SDD artifacts, never committed |
| `waybar-duplicate-wifi-icons/` | `design.md` + `proposal.md` | SDD artifacts, never committed |
| `openspec/specs/iwd-wifi-indicator/` | `spec.md` | SDD spec, never committed |

The `.gitignore` only has `result` — no `openspec/` entry. These are SDD artifacts that were never committed. Two options:
- **A**: Add `openspec/` to `.gitignore` (if these are transient working artifacts)
- **B**: Commit them (if they represent valuable design history)

#### 3. Existing SDD Change Artifacts

| Change | Status |
|--------|--------|
| `t14-workspace-switch-resets/` | COMPLETE — Phases 1-2 done, Phase 3 (hardware verification) pending |
| `t14-hdm-migration-v2/` | UNSTARTED — all 15 tasks are `[ ]`. This is the *next* change to implement (HDM-based monitor management) |
| `t14-cleanup-hdm-waybar/` | IN PROGRESS — this exploration |

### What's Already Clean

- ✅ No broken code anywhere
- ✅ No stale imports or references to non-existent files
- ✅ No dead code or commented-out waybar-git references
- ✅ `nix flake check --no-build` passes for all hosts
- ✅ Working trees are clean in both repos
- ✅ Waybar systemd service correctly configured with crash protection
- ✅ Monitor-lid-validator has no `hyprctl reload` (verified in `apply()` function)
- ✅ Git history documents the complete evolution — no rebase needed

### Minimum Cleanup Plan

```markdown
## Cleanup Plan (code-only — no history rewriting)

### Phase 1: Format (nixos-hosts)
- [ ] 1.1 Run `format-nix` — formats 88 unformatted .nix files
- [ ] 1.2 Run `nix flake check --no-build` — verify nothing broke
- [ ] 1.3 Run `git diff --stat` — confirm only formatting changes
- [ ] 1.4 Commit with message: `style: format all .nix files with nixfmt 1.3.1`

### Phase 2: omarchy-nix Untracked (decision needed)
- [ ] 2.1 Decide: commit SDD artifacts OR add `openspec/` to .gitignore
- [ ] 2.2 Execute decision

### Phase 3: Verify
- [ ] 3.1 `grep -r "waybar-src\|waybar-git" flake.nix flake.lock overlays/` → must return empty
- [ ] 3.2 `nix flake check --no-build` → must pass
- [ ] 3.3 `git status --short` → clean (no uncommitted)
```

### Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| `format-nix` breaks eval | None | nixfmt only changes whitespace/indentation; `nix flake check` catches issues |
| Missed stale reference | None | grep confirms zero waybar-src/waybar-git; all imports verified |
| omarchy-nix untracked dirs contain WIP | Low | They're SDD artifacts — either commit or .gitignore, no data loss |

### Ready for Proposal

**Yes.** The code is clean at HEAD. The only code-level action needed is running `format-nix` across the repo. The omarchy-nix untracked dirs need a decision (commit vs. .gitignore). No code fixes, no rebase, no history rewrite required.
