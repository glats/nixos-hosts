# Tasks: Waybar Duplicate WiFi Icons

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~6 (2 in omarchy-nix, 1 in flake.lock) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single work unit, 2 commits (one per repo) |
| Delivery strategy | no-pr — commit direct to `main` / `master` |
| Chain strategy | size-not-needed |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-not-needed
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Commit target | Notes |
|------|------|---------------|-------|
| 1 | omarchy-nix waybar fix | `main` of `glats/omarchy-nix` | No PR — direct push, user has full access |
| 2 | nixos-hosts flake lock bump | `master` of `nixos-hosts` | Depends on WU 1 landing first |

## Cross-Repo Dependency

**WU 2 MUST NOT start until WU 1 is pushed.** The flake bump needs the new
omarchy-nix commit SHA. Order: omarchy-nix push → `nix flake update omarchy-nix`.

## Phase 1: omarchy-nix Waybar Fix (WU 1)

Repo: `~/repos/omarchy-nix` · Branch: `main` (HEAD: `b85fdc8`) · Push: direct

- [x] 1.1 Edit `config/waybar/config` line 86 — change the disconnected glyph.
  Diff: `"format-disconnected": "󰤮",` → `"format-disconnected": "󰌙",`
  Verify with: `grep -n 'format-disconnected' ~/repos/omarchy-nix/config/waybar/config`
- [x] 1.2 Edit `config/waybar/style.css` lines 32-36 — add `#custom-iwd-wifi` to the
  right-side module selector. Diff (insert one line after `#custom-update`):
  ```
  #cpu,
  #battery,
  #pulseaudio,
  #custom-omarchy,
  #custom-update,
  #custom-iwd-wifi {
  ```
  Verify with: `grep -n '#custom-iwd-wifi' ~/repos/omarchy-nix/config/waybar/style.css`
- [x] 1.3 Run `cd ~/repos/omarchy-nix && nix flake check --no-build` — must pass.
- [x] 1.4 Commit both edits on `main` with a focused message, then push:
  `git add config/waybar/config config/waybar/style.css && git commit -m "fix(waybar): show LAN-disconnect icon when NM unmanages wlan0; space iwd-wifi widget" && git push origin main`
  Capture the new HEAD SHA — needed for Phase 2 verification.

## Phase 2: nixos-hosts Flake Lock Bump (WU 2)

Repo: `/home/glats/.nixos` · Branch: `master` · Commit: direct

- [x] 2.1 Run `nix flake update omarchy-nix` in `/home/glats/.nixos`.
  Verify the diff in `flake.lock` shows `omarchy-nix` rev matching the SHA from 1.4:
  `git diff flake.lock | grep -A2 'omarchy-nix'`
- [x] 2.2 Run `nix flake check --no-build` in `/home/glats/.nixos` — must pass.
- [x] 2.3 Confirm no other flake inputs drifted:
  `git diff --stat flake.lock` should show only the `omarchy-nix` node changed.
- [x] 2.4 Commit on `master`:
  `git add flake.lock && git commit -m "chore(flake): bump omarchy-nix — waybar disconnected icon + iwd-wifi spacing"`.

## Phase 3: Visual Verification on t14

Host: `t14` (standalone-iwd, Omarchy/Hyprland) — user-driven, not CI

- [ ] 3.1 Rebuild and switch t14: ask user before running `nixos-build switch`
  (builds are long per AGENTS.md rules). Trigger when user is ready.
- [ ] 3.2 Reload waybar (`omarchy-restart-waybar` or `pkill waybar; waybar &`).
- [ ] 3.3 Visually confirm Spec scenarios:
  - `network` widget shows `󰌙` (LAN disconnect) when wifi connected via iwd, no ethernet
  - `custom/iwd-wifi` shows connected SSID, no longer clipped into `pulseaudio`
  - `nm-iwd` hosts (rog, thinkcentre) unaffected — wifi signal icons still render

## Phase 4: Archive

- [ ] 4.1 Once t14 visual check passes, archive the change via `sdd-archive`.
  This moves `openspec/changes/waybar-duplicate-wifi-icons/` into
  `openspec/changes/archive/YYYY-MM-DD-waybar-duplicate-wifi-icons/`.
