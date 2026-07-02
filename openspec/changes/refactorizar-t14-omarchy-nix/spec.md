# Spec: refactorizar-t14-omarchy-nix

## Classification

Pure configuration refactor. No new or modified user-facing behavioral capabilities.
All changes are ownership moves (local → upstream) and duplicate deletions.

## Invariants

The following MUST NOT change across any commit. Verification methods are mandatory gates.

| ID | Invariant | Verification Method |
|----|-----------|-------------------|
| INV-1 | **Boot** — xfs root + LUKS + systemd-boot unchanged | `hardware-configuration.nix` byte-identical; `boot.initrd.supportedFilesystems = ["xfs"]` present |
| INV-2 | **Hyprland session launches** — greetd + uwsm + `programs.hyprland.enable` | `nixos-build dry` succeeds; `systemctl list-units | grep hyprland` shows active session post-switch |
| INV-3 | **Sops decryption** — `*host_t14` age key in `.sops.yaml`; `sops.age.sshKeyPaths` in `omarchy.nix` | `sops-nix` files decrypt on rebuild; `sops.age.sshKeyPaths` untouched |
| INV-4 | **HM standalone `hms`** — standalone HM build for t14 still evaluates | `home-manager build --flake .#t14` succeeds (or `hms` alias) |
| INV-5 | **XKB latam layout** — `mkForce "es,latam"` in `hypr/input.nix` and `xserver.xkb.layout` | `hyprctl getoption input:kb_layout` returns `es,latam` |
| INV-6 | **wayvnc connectivity** — VNC service reachable on port 5900 | `systemctl --user status wayvnc.service` active; `connect-wayvnc-t14` from another host succeeds |
| INV-7 | **Per-host identity** — `networking.hostName`, SSH configs, `.sops.yaml`, darwin `known_hosts` | Zero diffs in these files across all commits |

## Required Changes

### Commit 1 — Upstream: wayvnc module + osConfig fix (omarchy-nix repo)

- [ ] **ADD** `modules/home-manager/wayvnc.nix` in omarchy-nix: wayvnc user systemd service + config file, gated by `omarchy.wayvnc.enable`
- [ ] **ADD** options in omarchy-nix `config.nix`: `omarchy.wayvnc.enable` (bool, default `false`), `omarchy.wayvnc.port` (int, default `5900`), `omarchy.wayvnc.enable_pam` (bool, default `true`)
- [ ] **FIX** `omarchy-nix:flake.nix:55` — change `osConfig.omarchy` access to `osConfig.omarchy or {}` (attr-or-default pattern) so HM standalone eval does not crash when `osConfig` lacks `omarchy` attrs
- [ ] **VERIFY**: `nix flake check --no-build` passes in omarchy-nix

### Commit 2 — Move wayvnc upstream + delete osConfig workaround (this repo)

- [ ] **BUMP** `inputs.omarchy-nix` ref to commit from Commit 1 in `flake.nix`
- [ ] **ADD** `omarchy.wayvnc.enable = true` (+ port, enable_pam) to `hosts/t14/default.nix` `omarchy = { }` block
- [ ] **DELETE** `hosts/t14/home/wayvnc/default.nix` (51 lines — now upstream)
- [ ] **DELETE** `programs.wayvnc.enable = true` from `hosts/t14/default.nix` (replaced by `omarchy.wayvnc.enable`)
- [ ] **DELETE** `_module.args.osConfig = mkForce { omarchy = {}; };` workaround from `flake.nix:269-285` (upstream fix makes it unnecessary)
- [ ] **VERIFY**: `nix flake check --no-build` passes; `nixos-build dry` succeeds; `hms` standalone build succeeds WITHOUT the osConfig workaround

### Commit 3 — Delete pure-duplicate files

- [ ] **DELETE** `hosts/t14/home/hypr/xdph.nix` (31 lines — byte-identical to upstream `omarchy-nix:modules/home-manager/xdph.nix`)
- [ ] **DELETE** `hosts/t14/home/ghostty.nix` (17 lines — no delta from shared `home-linux/ghostty.nix`)
- [ ] **DELETE** `hosts/t14/home/scripts/window-switcher.sh` (17 lines — replaced by `omarchy-launch-walker -m windows` in keybinding)
- [ ] **DELETE** `hosts/t14/home/scripts/monitor-hotplug-handler.sh` (91 lines — superseded by upstream `omarchy-hyprland-monitor-watch`)
- [ ] **DELETE** `hosts/t14/home/hypr/autostart.nix` (17 lines — empty file, dead code)
- [ ] **REMOVE** `home.file` script-drop blocks from `hosts/t14/home/default.nix` that deployed the above deleted scripts
- [ ] **VERIFY**: `nix flake check --no-build` passes

### Commit 4 — Trim waybar override to iwd-wifi only

- [ ] **DELETE** ~200 lines of waybar config from `hosts/t14/home/default.nix` (upstream `omarchy-nix:modules/home-manager/waybar.nix` deploys near-identical config)
- [ ] **KEEP** `home.file."...indicators/iwd-wifi.sh"` drop (iwd-specific, not in upstream)
- [ ] **KEEP** waybar `modules-right` addition of `custom/iwd-wifi` (requires upstream waybar config patch or local `mkIf` overlay)
- [ ] **SIDE-EFFECT**: Auto-fixes hidden NerdFont U+E900 icon bug (upstream deploys raw config file, not `formats.json` which strips non-encodable chars)
- [ ] **VERIFY**: `nix flake check --no-build` passes; `nixos-build dry` succeeds; waybar renders with U+E900 omarchy icon visible

### Commit 5 — Final audit: bindings + input trim

- [ ] **DELETE** `hosts/t14/home/hypr/bindings.nix` (50 lines — all 5 bindings duplicate upstream: SUPER+Q → `omarchy-launch-walker -m windows`, SUPER+ALT+RETURN / SUPER+SHIFT+ALT+F are upstream duplicates, lid-switch covered by upstream `omarchy-hyprland-monitor-internal toggle`)
- [ ] **TRIM** `hosts/t14/home/hypr/input.nix` from 107 → ~15 lines: keep ONLY `mkForce kb_layout = "es,latam"` + `mkForce kb_options = "grp:alt_shift_toggle,compose:caps"`; delete touchpad re-assertions (match upstream defaults), gesture syntax (matches upstream), windowrules (upstream), opacity override (upstream)
- [ ] **VERIFY**: `nix flake check --no-build` passes; `nixos-build dry` succeeds

### Preserved as t14-local mkForce overrides (NOT deleted, NOT moved upstream)

Per user decisions, the following remain unchanged throughout all commits:

| File | Content | Reason |
|------|---------|--------|
| `hypr/hyprlock.nix` | 6 input-field overrides (size, font, placeholder, source, fingerprint, color) | User preference — t14-local `mkForce` |
| `hypr/hyprsunset.nix` | Progressive warm schedule (07:00/18:00/19:30/21:00/23:00) | t14-local `mkForce` override |
| `hypr/looknfeel.nix` | gaps_in=0, gaps_out=2.5, decoration (no shadow/blur/rounding), initial_workspace_tracking=false | t14-local `mkForce` override |
| `home/omarchy.nix` | hypridle lock_delay=200s, gtk.iconTheme=Papirus-Dark, gtk.colorScheme=dark, copyScreensaverTxt activation | t14-local `mkForce` overrides |
| `home/scripts/kb-layout.sh` + `kb-toggle.sh` | Chile 2-layout (es ↔ latam) cycling scripts | Chile-specific |
| `home/hypr/monitors.nix` | desc:-based multi-monitor list + cyclic workspaces | Physical monitor IDs are laptop-specific |
| `home/mouse-wiggle.nix` | Standalone mouse-wiggle utility | Custom, not omarchy-style |

## Build & Verify

Per-commit gate matrix:

| Commit | `nix flake check --no-build` | `nixos-build dry` | `hms` standalone | Runtime check |
|--------|:---:|:---:|:---:|---------------|
| 1 (upstream) | ✅ | n/a (omarchy-nix repo) | n/a | — |
| 2 (wayvnc + osConfig) | ✅ | ✅ | ✅ (workaround removed) | `systemctl --user status wayvnc` |
| 3 (dup deletes) | ✅ | — | — | — |
| 4 (waybar trim) | ✅ | ✅ | — | waybar renders, U+E900 icon visible |
| 5 (final audit) | ✅ | ✅ | — | `hyprctl getoption input:kb_layout` = `es,latam` |

**Universal invariant check (every commit):**
```bash
# Boot safety
git diff HEAD~1 -- hosts/t14/hardware-configuration.nix | wc -l  # MUST be 0
# Sops safety
git diff HEAD~1 -- .sops.yaml hosts/t14/secrets.nix | wc -l      # MUST be 0
# Identity safety
git diff HEAD~1 -- hosts/t14/default.nix | grep -c hostName       # MUST be 0
```

## Rollback

Every commit is independently `git revert`-able. No commit introduces new logic in this repo — all are deletions or opt-in moves to upstream `omarchy.*` options.

| Commit | Rollback | Side effects of revert |
|--------|----------|----------------------|
| 1 | Revert in omarchy-nix + bump input ref back in this repo | None — purely additive upstream |
| 2 | `git revert` restores osConfig workaround + local wayvnc + removes `omarchy.wayvnc` opt-in | wayvnc returns to local HM module; `hms` workaround restored |
| 3 | `git revert` restores 5 deleted files + `home.file` drops | Dead code restored (harmless) |
| 4 | `git revert` restores full waybar config in `home/default.nix` | Re-introduces NerdFont U+E900 bug (cosmetic) |
| 5 | `git revert` restores `bindings.nix` + full `input.nix` | Duplicate bindings restored (harmless — later bindings shadow earlier) |

**Worst case**: `git revert` of all 5 commits returns t14 to exact pre-refactor state (~1250 lines). No data loss, no config drift.
