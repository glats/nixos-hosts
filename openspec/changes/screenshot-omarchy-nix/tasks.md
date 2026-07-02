# Tasks: screenshot-omarchy-nix

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~3 upstream + ~10 in `flake.lock` (auto) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Two direct commits on main, one per repo |
| Delivery strategy | exception-ok (user opted out of PRs) |
| Chain strategy | size-exception (not applicable, no PRs) |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Commit | Notes |
|------|------|--------|-------|
| 1 | Add 3 missing packages to upstream `glats/omarchy-nix` | direct to `main` | `modules/packages.nix` only; verify `nix flake check` |
| 2 | Bump `nixos-hosts` `flake.lock` to pull new packages | direct to `main` | `nix flake lock --update-input omarchy-nix` + `nix flake check --no-build` |

## Phase 1: Upstream package additions (glats/omarchy-nix)

**Repo path**: `/home/glats/repos/omarchy-nix` (verified clean local clone per design)

- [ ] 1.1 Edit `modules/packages.nix` — insert `grim`, `wl-clipboard`, `tesseract` on three new lines after `slurp` (line 41), before `hyprland-preview-share-picker` (line 42), inside the existing `# Screenshot and recording` section
- [ ] 1.2 Format the file: `nix fmt -- modules/packages.nix` from the omarchy-nix repo root
- [ ] 1.3 Verify evaluation: `nix flake check --no-build` from `/home/glats/repos/omarchy-nix` passes
- [ ] 1.4 Commit and push to `main`: `git add modules/packages.nix && git commit -m "fix(packages): add grim, wl-clipboard, tesseract for screenshot pipeline" && git push origin main`
- [ ] 1.5 Record the new `omarchy-nix` short rev (e.g. `git rev-parse --short HEAD`) for downstream verification

## Phase 2: Downstream flake.lock bump (glats/nixos-hosts)

**Repo path**: `/home/glats/.nixos`

- [ ] 2.1 Confirm working copy clean: `git status` from `/home/glats/.nixos` shows no unrelated changes
- [ ] 2.2 Bump the input: `nix flake lock --update-input omarchy-nix`; confirm `flake.lock` shows the new rev from step 1.5
- [ ] 2.3 Verify evaluation: `nix flake check --no-build` passes for all hosts (rog, thinkcentre, t14, mact2)
- [ ] 2.4 Commit to `main`: `git add flake.lock && git commit -m "chore(flake): bump omarchy-nix for screenshot deps"`; push

## Phase 3: Spec verification (read-only)

- [ ] 3.1 R1/R2/R3 satisfied by construction — 3 added packages unblock the existing scripts `omarchy-capture-screenshot`, `omarchy-capture-text-extraction`, `omarchy-capture-screenrecording`; no further code changes
- [ ] 3.2 R4 satisfied — confirm `hosts/t14/home/omarchy.nix` has no `home.packages` block listing `grim`, `wl-clipboard`, or `tesseract` (grep check)
- [ ] 3.3 (Out of scope here) Runtime smoke tests on t14 — `,`+`PRINT`, text extraction keybinding, `ALT`+`PRINT`; covered by user after `nixos-build`
