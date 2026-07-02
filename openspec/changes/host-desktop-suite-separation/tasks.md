# Tasks: Host Desktop Suite Separation

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~50-80 (3 new files + 4 edits + 1 lock bump) |
| 400-line budget risk | Low |
| Chained PRs recommended | No — direct commits to main (per user) |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: n/a
400-line budget risk: Low

## Commit Plan (4 direct commits across 2 repos)

| # | Repo | Commit | Touches | Depends on |
|---|------|--------|---------|------------|
| 1 | `glats/omarchy-nix` | `om: add gnome-disk-utility` | 1 file, 1 line | — |
| 2 | `glats/.nixos` | `infra: add my.desktop.suite option + MATE/GNOME profiles` | 3 new files + 1 import | — (parallel w/ #1) |
| 3 | `glats/.nixos` | `feat: wire suite selection, trim base, gate dconf` | 6 files, ~30 lines | #2 |
| 4 | `glats/.nixos` | `flake: update omarchy-nix` | `flake.lock` only | #1 merged |

#1 and #2 are independent and may ship in parallel. #3 follows #2 in the same repo. #4 follows #1 merge (upstream → lock bump).

---

## Phase 1 — Upstream (Repo `glats/omarchy-nix`, workdir `/tmp/opencode/omarchy-nix`)

- [x] **1.1** Edit `modules/packages.nix`: insert `gnome-disk-utility` on a new line between line 25 (`gnome-themes-extra`) and line 26 (`blueman`). Keep the 4-space indent; match the `bibata-cursors gnome-themes-extra blueman` style.
  - **Verify**: `nix flake check --no-build` passes in `/tmp/opencode/omarchy-nix`.
  - **Commit**: `om: add gnome-disk-utility` → push to `glats/omarchy-nix:main`.

## Phase 2 — Foundation (Repo `glats/.nixos`)

> No behavior change. Sets up the option and new profile files so Phase 3 can wire them. Safe intermediate — option declared but unread, profiles exist but unused.

- [ ] **2.1** Create `modules/base/options.nix` declaring `my.desktop.suite = lib.mkOption { type = lib.types.nullOr (lib.types.enum [ "mate" "gnome" ]); default = null; ... }`. Use the exact text from design §1 (lines 116-129).
- [ ] **2.2** Edit `modules/profiles/base.nix`: add `../base/options.nix` to the imports list, between line 4 (`cachix.nix`) and line 5 (`dconf.nix`).
  - **Verify**: `nix flake check --no-build` passes (option declared, zero consumers).
- [ ] **2.3** Create `modules/base/profiles/mate.nix`: 9 MATE packages (`atril caja engrampa eom marco pluma mate-panel mate-sensors-applet mate-user-share`) + `materia-theme`. Match the `{ pkgs }: with pkgs; [ ... ]` contract used by sibling profiles. Use the text from design §3 (lines 156-179).
- [ ] **2.4** Create `modules/base/profiles/gnome.nix`: `[ gnome-system-monitor ]` with a comment documenting the omarchy-nix baseline (nautilus, calculator, evince, loupe, sushi, pavucontrol, blueman, gnome-themes-extra, gnome-keyring, ffmpegthumbnailer). Use the text from design §4 (lines 181-195).
  - **Verify**: `nix flake check --no-build` passes; `nix eval .#nixosConfigurations.rog.config.my.desktop.suite` returns `null`.
  - **Commit**: `infra: add my.desktop.suite option + MATE/GNOME profiles` → push to main.

## Phase 3 — Atomic Refactor (Repo `glats/.nixos`)

> **One commit** — splitting this breaks the flake between edits (rog/thinkcentre would lose MATE packages before declaring their suite). All 6 edits ship together. This is the only commit in the change with non-trivial review surface; ~30 lines across 6 files.

- [ ] **3.1** Edit `modules/base/profiles/base.nix`: remove lines 10-19 (MATE block, including the `# MATE desktop support` comment header) and line 104 (`materia-theme`). Update the file header comment per design §2 (lines 138-154). Keep `gnome-themes-extra` (line 105) and `adwaita-icon-theme` (line 107) — both stay in shared base.
- [ ] **3.2** Edit `modules/base/packages.nix`: add `let cfg = config.my.desktop.suite;` binding plus `suitePkgs = if cfg == "mate" then import ./profiles/mate.nix { inherit pkgs; } else if cfg == "gnome" then import ./profiles/gnome.nix { inherit pkgs; } else [];`. Append `suitePkgs` to `environment.systemPackages` per design §5 (lines 197-236). The `lib` arg is now used; keep it.
- [ ] **3.3** Edit `modules/base/dconf.nix`: wrap `programs.dconf.profiles.user.databases = [ ... ];` in `lib.mkIf (config.my.desktop.suite == "mate")`. Use the exact pattern from design §6 (lines 260-278).
- [ ] **3.4** Edit `hosts/rog/default.nix`: add `my.desktop.suite = "mate";` immediately after line 71 (`my.shutdownDebug.enable = true;`), preceded by a one-line comment (`# Desktop suite — rog uses MATE via XRDP`). Match the format in design §8.
- [ ] **3.5** Edit `hosts/thinkcentre/default.nix`: add `my.desktop.suite = "mate";` after the `boot-settings = { ... };` block (line 30), preceded by a one-line comment (`# Desktop suite — thinkcentre uses MATE via XRDP`). Match design §9.
- [ ] **3.6** Edit `hosts/t14/default.nix`: add `my.desktop.suite = "gnome";` after the `omarchy = { ... };` block (line 148), preceded by a 3-line comment explaining that omarchy-nix provides the GNOME baseline and this adds `gnome-system-monitor` via `modules/base/profiles/gnome.nix`. Match design §10.
  - **Verify (all 6 edits)**:
    - `nix flake check --no-build` passes.
    - `nix eval .#nixosConfigurations.rog.config.my.desktop.suite` returns `"mate"`.
    - `nix eval .#nixosConfigurations.thinkcentre.config.my.desktop.suite` returns `"mate"`.
    - `nix eval .#nixosConfigurations.t14.config.my.desktop.suite` returns `"gnome"`.
    - `git diff` confirms 5 t14 dark-mode files UNCHANGED: `patches/xdg-desktop-portal/settings-allow-unsandboxed.patch`, `hosts/t14/default.nix` portal block (lines 82-90, 151-180, 217-227), `hosts/t14/home/omarchy.nix` GTK section (lines 151-164).
  - **Commit**: `feat: wire suite selection, trim base, gate dconf` → push to main.

## Phase 4 — Lock Bump (Repo `glats/.nixos`)

> **Prerequisite**: Phase 1 commit has been merged to `glats/omarchy-nix:main`.

- [ ] **4.1** Run `nix flake update omarchy-nix`. No source edits — lock file only.
  - **Verify**: `nix flake check --no-build` passes. `git diff flake.lock` shows only the `omarchy-nix` input rev/narHash changed; no other input moved.
  - **Commit**: `flake: update omarchy-nix` → push to main.

## Phase 5 — Final Closure Verification (Repo `glats/.nixos`)

> Run after Phase 4. This phase is verification only — no source edits, no commit. If any check fails, fix the underlying issue and amend the responsible commit (do not add a fixup commit).

- [ ] **5.1** Closure content check. For each host, run:
  ```sh
  nix build .#nixosConfigurations.<host>.config.system.path.toplevel -L
  nix path-info -r ./result | grep -E '-(atril|caja|engrampa|eom|marco|pluma|mate-panel|mate-sensors-applet|mate-user-share|materia-theme|gnome-system-monitor|gnome-disk-utility)-' | sort -u
  ```
  Assert:
  - **rog / thinkcentre**: all 9 MATE packages + `materia-theme` present, 0 `gnome-system-monitor`, 0 `gnome-disk-utility`.
  - **t14**: 0 MATE packages, 0 `materia-theme`, `gnome-system-monitor` present, `gnome-disk-utility` present (after Phase 4).
- [ ] **5.2** Option presence: `grep -n 'my.desktop.suite' hosts/*/default.nix` returns exactly 3 matches (rog=mate, thinkcentre=mate, t14=gnome).
- [ ] **5.3** `format-nix` produces zero diff against the working tree.
- [ ] **5.4** `git log --stat main --not <base-commit>` across all 4 commits: confirm the 5 t14 dark-mode files appear in no commit's `Files changed` list. Use `git log --name-only --pretty=format: main --not <base>` and grep the output.
