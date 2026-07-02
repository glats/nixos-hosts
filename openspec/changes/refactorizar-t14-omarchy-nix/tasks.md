# Tasks: refactorizar-t14-omarchy-nix

Delivery: direct-to-main. Review budget: 1000 lines total. 5 commits, each
independently `git revert`-able. No PRs.

## Review Workload Forecast

| Commit | This-repo Δ | Upstream Δ | 1000-line budget | 400-line guard |
|--------|------------:|-----------:|-----------------:|----------------|
| 1      | 0 (input bump) | +~95 / -1 | OK (upstream) | OK |
| 2      | -70 / +5     | 0          | OK              | OK             |
| 3      | -175 / 0     | 0          | OK              | OK             |
| 4      | -243 / 0     | 0          | OK              | OK             |
| 5      | -92 / +15    | 0          | OK              | OK             |
| **Total** | **-575 / +20** | **+95 / -1** | OK | OK |

Each commit stays under 250 changed lines in this repo; commit 1's load is
in the omarchy-nix repo (out of scope for this budget). No commit triggers
the chained-PR guard. Worst-case single commit (commit 4) is 243 deletions,
all in one file, all pure deletion.

Decision needed before apply: No
Chained PRs recommended: No (direct-to-main per preflight)
Chain strategy: size-exception (single repo, single branch, 5 sequential commits)
400-line budget risk: Low

## Commit 1: Add wayvnc module + osConfig fix (omarchy-nix)

Repository: **`github:glats/omarchy-nix`** (NOT this repo). Land first; this
repo's commit 2 bumps the input ref to this commit's SHA.

### 1.1 [Upstream] Create `modules/nixos/wayvnc.nix`
- New file at `omarchy-nix:modules/nixos/wayvnc.nix` (~35 lines).
- Signature: `{ config, lib, pkgs, ... }:` with `let cfg = config.omarchy.wayvnc; in`.
- `config = lib.mkIf cfg.enable { programs.wayvnc.enable = true; environment.systemPackages = [ pkgs.wayvnc ]; };`
- Required because `pkgs.wayvnc` is not in omarchy-nix's package set by default.

### 1.2 [Upstream] Create `modules/home-manager/wayvnc.nix`
- New file at `omarchy-nix:modules/home-manager/wayvnc.nix` (~45 lines).
- Mirror of current `hosts/t14/home/wayvnc/default.nix`, gated by
  `config.omarchy.wayvnc.enable`.
- Emits `xdg.configFile."wayvnc/config".text` (use_relative_paths, address,
  port from `cfg.port`, enable_pam from `cfg.enable_pam`).
- Emits `systemd.user.services.wayvnc` with `graphical-session.target`
  After/PartOf, `ExecStartPre` pkill, `ExecStart = ${pkgs.wayvnc}/bin/wayvnc`.
- `WantedBy = [ "graphical-session.target" ]`.

### 1.3 [Upstream] Add `omarchy.wayvnc` option block in `omarchy-nix:config.nix`
- Add submodule with `enable` (bool, default `false`), `port` (port, default
  `5900`), `enable_pam` (bool, default `true`). Outer attr default `{}`.

### 1.4 [Upstream] Wire new modules into aggregator imports
- Edit `omarchy-nix:modules/nixos/default.nix`: add `./wayvnc.nix` to imports
  (after `./hardware.nix`).
- Edit `omarchy-nix:modules/home-manager/default.nix`: add `(import ./wayvnc.nix inputs)` to imports.

### 1.5 [Upstream] Fix `osConfig.omarchy` lazy-eval in `omarchy-nix:flake.nix:58-60`
- In the `config = lib.mkIf (osConfig ? omarchy) { … };` block, change
  `omarchy = osConfig.omarchy;` to `omarchy = osConfig.omarchy or {};`.
- This makes the attr access lazy-safe so `pushDownProperties` cannot force
  evaluation before `mkIf` short-circuits. Required so the
  `_module.args.osConfig = mkForce { … }` workaround in
  `flake.nix:269-285` of THIS repo can be deleted in commit 2.

### 1.6 [Upstream] Verify
- `nix flake check --no-build` in omarchy-nix repo.
- Capture the new commit SHA — needed for commit 2.

## Commit 2: Convert osConfig mkForce → opt-in + delete osConfig workaround (nixos-hosts)

Net: ~70 lines deleted, ~5 added. Replaces the local wayvnc HM module with
the new upstream opt-in, then removes the osConfig workaround now that the
upstream fix (commit 1.5) makes it unnecessary.

### 2.1 Bump `inputs.omarchy-nix` ref
- `flake.nix:19-23` — same `url = "github:glats/omarchy-nix/main";`. Update
  the `flake.lock` entry to the commit SHA from commit 1.6.
- `nix flake update omarchy-nix` (or run `nix flake lock --update-input
  omarchy-nix`).

### 2.2 Delete local wayvnc module
- `git rm hosts/t14/home/wayvnc/default.nix` (51 lines, file content
  documented in `sdds/refactorizar-t14-omarchy-nix/exploration.md:53`).

### 2.3 Remove wayvnc import from `hosts/t14/home/default.nix:33`
- Delete line 33: `./wayvnc`.
- Imports list at `hosts/t14/home/default.nix:21-34` now ends at `./mouse-wiggle.nix` (line 32).

### 2.4 Delete `programs.wayvnc.enable` from `hosts/t14/default.nix:94`
- Delete the line `programs.wayvnc.enable = true;` (line 94).
- The block comment at lines 92-93 ("VNC server — captures Wayland screen
  via wlroots screencopy") STAYS as documentation.

### 2.5 Add `wayvnc.enable = true` to the omarchy block
- `hosts/t14/default.nix:117-148` — inside the `omarchy = { … };` block,
  add `wayvnc.enable = true;` immediately after the existing
  `firewall.enable = false;` (line 147).
- Keeps port + enable_pam at upstream defaults (5900, true).

### 2.6 Delete the osConfig workaround in `flake.nix:269-285`
- Delete the entire `_module.args.osConfig = nixpkgs.lib.mkForce { omarchy =
  { }; services.xserver.videoDrivers = [ ]; };` block.
- The inner `omarchy = { … };` block (lines 274-284, the standalone-HM
  values) STAYS — standalone HM still needs them, but the workaround itself
  is no longer required.
- Optionally remove the `services.xserver.videoDrivers = [ ];` line that
  was bundled in the workaround (verify first — it may still be needed for
  HM-standalone without a NixOS host).

### 2.7 Verify
- `nix flake check --no-build`
- `nixos-build dry` (full eval)
- `hms` standalone build — must succeed WITHOUT the osConfig workaround.
  This is the critical invariant: if commit 1.5 didn't land correctly,
  commit 2's HM-standalone build crashes.

## Commit 3: Delete pure-duplicate files (nixos-hosts)

Net: ~175 lines deleted, 0 added. Five files removed; imports and
`home.file` script drops trimmed in `hosts/t14/home/default.nix`.

### 3.1 Delete `hosts/t14/home/hypr/xdph.nix` (31 lines)
- Byte-identical content to upstream `omarchy-nix:modules/home-manager/xdph.nix`.
- `git rm hosts/t14/home/hypr/xdph.nix`.

### 3.2 Delete `hosts/t14/home/ghostty.nix` (17 lines)
- Only re-imports `../../../home-linux/ghostty.nix` with no t14 delta.
- The shared `home-linux/ghostty.nix` is already applied via
  `home-linux/shared-modules.nix` (need to verify) OR will be picked up
  by omarchy's HM module's own ghostty config; if neither, add the shared
  module to the t14 imports list BEFORE deleting.
- `git rm hosts/t14/home/ghostty.nix`.

### 3.3 Delete `hosts/t14/home/scripts/window-switcher.sh` (17 lines)
- Replaced by `omarchy-launch-walker -m windows` (already on PATH).
- `git rm hosts/t14/home/scripts/window-switcher.sh`.

### 3.4 Delete `hosts/t14/home/scripts/monitor-hotplug-handler.sh` (91 lines)
- Superseded by upstream `omarchy-hyprland-monitor-watch` daemon.
- `git rm hosts/t14/home/scripts/monitor-hotplug-handler.sh`.

### 3.5 Delete `hosts/t14/home/hypr/autostart.nix` (17 lines)
- Empty file (only comments, explains why the handler was removed).
- `git rm hosts/t14/home/hypr/autostart.nix`.

### 3.6 Remove deleted imports from `hosts/t14/home/default.nix:21-34`
- Delete line 26: `./hypr/autostart.nix` (autostart removed by 3.5).
- Delete line 29: `./hypr/xdph.nix` (xdph removed by 3.1).
- Delete line 30: `./ghostty.nix` (ghostty wrapper removed by 3.2).
- The imports list now has 8 entries (down from 12).

### 3.7 Remove deleted-script `home.file` drops from `hosts/t14/home/default.nix:39-50`
- Delete the entire `".local/share/omarchy/bin/window-switcher.sh"` block
  (lines 41-44, plus the preceding comment at line 40).
- Delete the entire `".local/share/omarchy/bin/monitor-hotplug-handler.sh"`
  block (lines 47-50, plus the preceding comment at line 46).
- KEEP lines 52-79: `kb-toggle.sh`, `kb-layout.sh`, and the `.config/hypr/`
  symlink copies (Chile 2-layout scripts STAY per spec).

### 3.8 Verify
- `nix flake check --no-build`.
- (No `nixos-build dry` required — pure file deletions, no eval change.)

## Commit 4: Trim waybar override to iwd-wifi only (nixos-hosts)

Net: ~243 lines deleted, 0 added. Switches to upstream's waybar config (raw
file deploy) and keeps only the iwd-wifi indicator.

### 4.1 Delete waybar config override in `hosts/t14/home/default.nix:104-346`
- Delete the entire `xdg.configFile."waybar/config" = lib.mkForce { … };`
  block (lines 104-346, the 243-line JSON config).
- This includes the `jsonFormat` / `baseConfig` / `source = jsonFormat.generate` pipeline.
- Upstream `omarchy-nix:modules/home-manager/waybar.nix` deploys the
  raw `config/waybar/config` file via `home.file."…".source` (recursive
  directory copy), so no redeploy is needed.
- **Side-effect**: auto-fixes the hidden NerdFont U+E900 icon bug
  (`pkgs.formats.json` in the local override stripped non-encodable chars;
  raw file deploy preserves them).

### 4.2 Update comment block at `hosts/t14/home/default.nix:82-88`
- Replace the comment block explaining "we override JUST the config file"
  with a comment explaining the new state: "omarchy-nix owns the waybar
  config. We add only the iwd-wifi indicator script (iwd-specific, not in
  upstream). The script deploys but is not referenced by upstream's
  waybar modules-right (follow-up: patch upstream waybar config to
  include `custom/iwd-wifi`)."

### 4.3 Keep the iwd-wifi indicator
- Lines 89-102 (the `home.file.".config/waybar/indicators/iwd-wifi.sh"`)
  STAY as-is. The script deploys even though upstream's waybar config does
  not include `custom/iwd-wifi` in `modules-right` (out of scope for this
  refactor).

### 4.4 Verify
- `nix flake check --no-build`.
- `nixos-build dry` (the waybar deploy is part of the HM build).
- Runtime: after rebuild, check waybar renders with U+E900 omarchy icon
  visible in the top bar (was previously broken).

## Commit 5: Final audit hypr/* files (nixos-hosts)

Net: ~92 lines deleted, ~15 added. Deletes `bindings.nix` (all duplicates)
and trims `input.nix` to the only genuine t14 override (Chile keyboard).

### 5.1 Delete `hosts/t14/home/hypr/bindings.nix` (50 lines)
- All 5 bindings are duplicates of upstream omarchy-nix or refer to
  deleted scripts:
  - `SUPER, Q` → `window-switcher.sh` (deleted in 3.3); upstream has
    `omarchy-launch-walker -m windows`.
  - `SUPER, M` → `window-switcher.sh` (same).
  - lid-switch (on/off) → upstream's `omarchy-hyprland-monitor-internal toggle`
    binding (SUPER CTRL DELETE) covers it.
  - `SUPER SHIFT, R` → wofi run (wofi not in omarchy's package set; this
    override was already non-functional).
  - `SUPER ALT, RETURN` / `SUPER ALT SHIFT, F` → byte-identical to
    upstream's bindings.
- `git rm hosts/t14/home/hypr/bindings.nix`.

### 5.2 Remove bindings import from `hosts/t14/home/default.nix:24`
- Delete line 24: `./hypr/bindings.nix`.
- Imports list now has 7 entries (down from 12 originally).

### 5.3 Trim `hosts/t14/home/hypr/input.nix` from 107 → ~15 lines
- KEEP only: `mkForce kb_layout = "es,latam"` and `mkForce kb_options =
  "grp:alt_shift_toggle,compose:caps"` (currently lines 37-38).
- DELETE:
  - Lines 43-49: touchpad block (matches upstream `mkDefault` values;
    re-asserting them is dead code).
  - Lines 52-57: repeat_rate, repeat_delay, follow_mouse, sensitivity,
    numlock_by_default, accel_profile (all match upstream `mkDefault`
    values).
  - Lines 64-66: `cursor.no_hardware_cursors = true` (not t14-specific;
    upstream's default applies).
  - Line 74: `gesture = "3, horizontal, workspace"` (upstream uses
    equivalent syntax already).
  - Lines 85-96: windowrule block (float picker / steam / scroll_touchpad
    — upstream's windows.nix + bindings already covers these).
  - Lines 104-106: opacity `mkAfter` extraConfig (upstream sets 0.97/0.90;
    deleting accepts upstream's slight transparency).
- Final file is 12-15 lines: just the kb_layout + kb_options `mkForce`
  pair under `wayland.windowManager.hyprland.settings.input`.

### 5.4 Verify
- `nix flake check --no-build`.
- `nixos-build dry`.
- Runtime: `hyprctl getoption input:kb_layout` returns `es,latam` (INV-5).

## Verification Gates (per commit)

| Commit | `nix flake check --no-build` | `nixos-build dry` | `hms` standalone | Runtime |
|--------|:---:|:---:|:---:|---------|
| 1      | ✅ (in omarchy-nix) | n/a (different repo) | n/a | — |
| 2      | ✅ | ✅ | ✅ (workaround removed) | `systemctl --user status wayvnc` |
| 3      | ✅ | — | — | — |
| 4      | ✅ | ✅ | — | waybar renders, U+E900 visible |
| 5      | ✅ | ✅ | — | `hyprctl getoption input:kb_layout` = `es,latam` |

**Universal invariant check (every commit):**
```bash
git diff HEAD~1 -- hosts/t14/hardware-configuration.nix | wc -l  # MUST be 0
git diff HEAD~1 -- .sops.yaml hosts/t14/secrets.nix | wc -l      # MUST be 0
git diff HEAD~1 -- hosts/t14/default.nix | grep -c hostName       # MUST be 0
```

**Format gate (every commit, before commit):**
```bash
format-nix   # or nix fmt -- <changed-files>
```

## Commit Ordering & Parallelism Within a Commit

- **Sequential between commits**: each commit depends on the previous
  one's state. Cannot parallelize.
- **Within a commit**:
  - Commit 1: 1.1-1.2 (new files) parallel; 1.3-1.4 (edits) sequential
    after 1.1/1.2; 1.5 (flake.nix edit) parallel with 1.3-1.4; 1.6
    (verify) sequential.
  - Commit 2: 2.1 (flake lock update) first; 2.2-2.5 can run in any
    order; 2.6 (osConfig delete) sequential after 2.1; 2.7 (verify)
    sequential.
  - Commit 3: 3.1-3.5 (file deletes) parallel; 3.6-3.7 (imports + home.file
    edits) parallel after 3.1-3.5; 3.8 (verify) sequential.
  - Commit 4: 4.1 (delete override) is the only edit; 4.2 (comment
    update) optional after; 4.3-4.4 sequential.
  - Commit 5: 5.1-5.2 (bindings delete + import) sequential; 5.3 (input
    trim) parallel; 5.4 (verify) sequential.

## Reference: Files Preserved (Unchanged Across All Commits)

Per spec, these stay as t14-local `mkForce` overrides / per-host identity:
`hosts/t14/hardware-configuration.nix`, `hosts/t14/secrets.nix`,
`hosts/t14/default.nix:61-110` (hostName, XKB, initrd/xfs, console.keyMap),
`hosts/t14/default.nix:117-148` (omarchy config block, with `wayvnc.enable`
added in commit 2), `hosts/t14/default.nix:150-228` (portal overrides,
out of scope), `hosts/t14/home/hypr/{monitors,hyprlock,hyprsunset,looknfeel}.nix`,
`hosts/t14/home/omarchy.nix:113-174` (hypridle + gtk + copyScreensaverTxt
overrides), `hosts/t14/home/scripts/{kb-layout,kb-toggle}.sh`,
`hosts/t14/home/mouse-wiggle.nix`, `.sops.yaml` (host_t14 rules), SSH
configs, darwin `known_hosts`.
