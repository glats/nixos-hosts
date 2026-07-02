# Tasks: App Audit Per Host

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~+35/-65 (omarchy-nix ~-61; nixos-hosts ~+30/-5) |
| 400-line budget risk | Low |
| Chained PRs recommended | No (2 repos, independent commits) |
| Suggested split | Commit A (omarchy-nix) → Commit B (nixos-hosts) |
| Delivery strategy | single-pr (per repo) |
| Chain strategy | stacked-to-main |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: stacked-to-main
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Commit | Notes |
|------|------|--------|-------|
| 1 | omarchy-nix: drop imv | A | Delete `imv.nix`, remove import. `loupe` remains. |
| 2 | nixos-hosts: gate 18 dup pkgs | B | 4 profile files + `packages.nix`. |
| 3 | Verify both | Local | `nix flake check --no-build` + closure audit. |

## Phase 1: omarchy-nix — Remove imv (Commit A, `glats/omarchy-nix`)

- [x] 1.1 Verify `modules/home-manager/imv.nix` exists at current pin (`0d87d4fe…`).
- [x] 1.2 Delete `modules/home-manager/imv.nix` (60 lines: pkg + config + xdg mime + desktop entry).
- [x] 1.3 Edit `modules/home-manager/default.nix`: remove `./imv.nix` import (line 74 old pin; verify current).
- [x] 1.4 Run `nix flake check --no-build`. Must pass.

## Phase 2: nixos-hosts — Gate 18 packages (Commit B, `glats/.nixos`)

- [x] 2.1 Edit `modules/base/profiles/base.nix`: change `{ pkgs }` → `{ pkgs, config, lib }`. Add `let cfg = config.my.desktop.suite; nonGnome = p: lib.mkIf (cfg != "gnome") p; in`. Wrap 11: `fzf`(L11) `curl`(L14) `wget`(L15) `unzip`(L18) `fastfetch`(L30) `btop`(L32) `coreutils`(L42) `lazygit`(L74) `lazydocker`(L75) `jq`(L79) `ghostty`(L86).
- [x] 2.2 Edit `dev.nix`: same sig + helper. Wrap 2: `gnumake`(L9) `nodejs`(L20).
- [x] 2.3 Edit `media.nix`: same sig + helper. Wrap 3: `mpv`(L7) `wiremix`(L8) `ffmpeg`(L9).
- [x] 2.4 Edit `browsers.nix`: same sig + helper. Wrap 2: `chromium`(L8) `brave`(L9).
- [x] 2.5 Edit `modules/base/packages.nix`: pass `config` and `lib` to 4 profile imports (`import ./profiles/X.nix { inherit pkgs config lib; }`). `virt.nix`/`mate.nix`/`gnome.nix` unchanged.
- [x] 2.6 Run `nix flake check --no-build`. Must pass.
- [x] 2.7 Run `format-nix` on edited files.

## Phase 3: Verification

- [ ] 3.1 `coreutils` reaches t14 via omarchy PATH wrapper (`system.nix:34`) despite gating.
- [ ] 3.2 `nodejs` reaches t14 via `home-linux/neovim.nix:10` (HM) despite gating.
- [ ] 3.3 t14 closure: `git`(omarchy:11), `btop`(omarchy:67), `ffmpeg`(omarchy:16) present.
- [ ] 3.4 t14 closure: `bat`(L12), `htop`(L31), `meld`(L89) present (base.nix still arrives).
- [ ] 3.5 `loupe` on t14, no `imv` binary.
- [ ] 3.6 `libsecret` on all 3 hosts (untouched).
- [ ] 3.7 All 4 browsers on all 3 hosts (untouched).

## Acceptance Criteria

- [ ] AC1 `nix flake check --no-build` passes both repos.
- [ ] AC2 `format-nix` clean in nixos-hosts.
- [ ] AC3 t14: no `imv`; `loupe` is viewer; 18 gated pkgs absent.
- [ ] AC4 rog/tc: all 18 gated pkgs present; non-gated shared on t14.
- [ ] AC5 `libsecret` + 4 browsers on all 3 hosts (untouched).

## Out of Scope

`libsecret` dedup · HM dupes (`ripgrep`,`fd` in `neovim.nix`) · omarchy-only pkgs · `git`/`gnome-themes-extra` from `base.nix`.
