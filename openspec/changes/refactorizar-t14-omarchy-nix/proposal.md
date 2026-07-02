# Proposal: refactorizar-t14-omarchy-nix

## Intent

Move t14 from ~1250 lines of local config overlays to a thin consumer of `omarchy-nix`. Push reusable logic upstream as `omarchy.*` options, delete local duplicates. Fourth application of the established consumer pattern (prior: `restore-omarchy-hyprland-ownership`, `omarchy-theme-glats-upstream`, `nixos-host-pattern-refactor`). Result: t14 host tree shrinks to ~600 lines of pure per-host identity, hardware, and secrets; all shared functionality lives upstream.

## Approach

Upstream-first, then delete local. Add 12–14 new `omarchy.*` options to `github:glats/omarchy-nix`, bump the flake input, convert t14's `mkForce` overrides to `omarchy.*` opt-ins, then delete the now-redundant local files. t14's role becomes: (a) opt-in via `omarchy.*` options, (b) `mkDefault` for t14-specific values, (c) `mkForce` only where a genuine per-host collision exists (XKB latam).

## Scope

### MUST STAY (per-host identity — no changes)

| File | Why |
|------|-----|
| `hosts/t14/hardware-configuration.nix` | Auto-generated (xfs, LUKS, UUIDs) |
| `hosts/t14/default.nix:61-110` | hostName, nixpkgs, XKB latam, initrd/xfs, wayvnc opt-in |
| `hosts/t14/secrets.nix` | sops placeholders |
| `flake.nix:212-215` | nixos-hardware + omarchy-nix wiring |
| `hosts/t14/home/mouse-wiggle.nix` | Custom utility, not portable |
| `hosts/t14/home/scripts/{kb-layout,kb-toggle}.sh` | Chile 2-layout cycling |
| `hosts/t14/home/hypr/monitors.nix` (monitor list only) | desc:-based physical monitor IDs |
| `.sops.yaml`, SSH configs, darwin known_hosts | Host identity / connectivity |

### SHOULD MOVE to omarchy-nix (then delete locally — ~530 lines deleted)

| Local file | LoC | Action |
|------------|----:|--------|
| `hypr/xdph.nix` | 31 | DELETE — byte-identical upstream |
| `home/ghostty.nix` | 17 | DELETE — no delta from shared |
| `home/scripts/window-switcher.sh` | 17 | DELETE — `omarchy-launch-walker -m windows` |
| `home/scripts/monitor-hotplug-handler.sh` | 91 | DELETE — `omarchy-hyprland-monitor-watch` |
| `home/hypr/autostart.nix` | 17 | DELETE — empty |
| `home/hypr/bindings.nix` | 50 | DELETE — 5/5 bindings duplicate upstream |
| `home/hypr/hyprlock.nix` | 65 | MOVE → `omarchy.hyprlock.*` options |
| `home/hypr/hyprsunset.nix` | 59 | MOVE → `omarchy.hyprsunset.schedule` |
| `home/hypr/looknfeel.nix` | 48 | MOVE → `omarchy.hyprland.gaps_*`, `decoration.*` |
| `home/hypr/input.nix` | 107 | TRIM → keep only `mkForce kb_layout="es,latam"` |
| `home/default.nix` (waybar) | 240 | TRIM → keep only iwd-wifi indicator |
| `home/omarchy.nix` (overrides) | 130 | MOVE → `omarchy.{hypridle,gtk}.*` options |
| `default.nix:162-228` (portals) | ~40 | MOVE → upstream gtk.portal fix |
| `home/wayvnc/default.nix` | 51 | MOVE → new `omarchy.wayvnc` module (see Open Q) |

### New `omarchy.*` options needed upstream (12–14)

| Option | Module | Default |
|--------|--------|---------|
| `omarchy.hyprlock.{size,font_family,placeholder_text,fingerprint}` | `hyprlock.nix` | upstream current |
| `omarchy.hyprland.gaps_in/out` | `looknfeel.nix` | `5`/`10` |
| `omarchy.hyprland.decoration.{rounding,shadow,blur}` | `looknfeel.nix` | upstream current |
| `omarchy.hyprland.initial_workspace_tracking` | `looknfeel.nix` | `true` |
| `omarchy.hyprland.keyboard.{layout,options}` | `input.nix` | `us`/`compose:caps` |
| `omarchy.hyprsunset.schedule` | `hyprsunset.nix` | current default |
| `omarchy.hypridle.lock_delay` | `hypridle.nix` | `151` |
| `omarchy.gtk.iconTheme` | `default.nix` | unset |
| `omarchy.wayvnc.{enable,port}` | **new** module | `false`/`5900` |

## Migration Strategy

**Delivery: direct-to-main** (commits on main, no PRs). Review budget: 1000 lines.
**Decision: 5 independent commits, one per phase.** Rationale: although the 1000-line budget could absorb all ~530 deleted lines in one commit, per-phase bisectability ensures each commit is independently `git revert`-able. Each commit in this repo is 50–150 lines (pure deletions + opt-in moves) — well within focus limits. Upstream omarchy-nix changes are committed directly to that repo before the corresponding commit here.

| Commit | Phase | This repo (lines) | omarchy-nix (lines) | Gate |
|--------|-------|-------------------:|--------------------:|------|
| 1 | Add new `omarchy.*` options upstream | 0 (input bump only) | +280–380 | `nix flake check --no-build` |
| 2 | Convert t14 `mkForce` → `omarchy.*` opt-ins | ~130 deleted, ~20 added | 0 | `nix flake check` + `nixos-build dry` |
| 3 | Delete pure-duplicate files | ~230 deleted | 0 | `nix flake check` |
| 4 | Trim waybar override (keep iwd-wifi only) | ~200 deleted | 0 | `nix flake check` + `nixos-build dry` |
| 5 | Final audit: bindings, input, monitors, hyprsunset, hyprlock | ~80 deleted | 0 | `nix flake check` + `nixos-build dry` |

**Total: ~530 lines deleted (this repo), ~280–380 lines added (omarchy-nix).**

## Risk & Rollback

### Hard invariants (cannot break)

1. **Boot** — xfs root + LUKS + systemd-boot. Never touch `hardware-configuration.nix`.
2. **Hyprland session** — `programs.hyprland.enable` + greetd + uwsm. omarchy-nix owns all three.
3. **Sops** — `*host_t14` age key in `.sops.yaml`; `sops.age.sshKeyPaths` in `omarchy.nix:92`.
4. **HM standalone `hms`** — `osConfig` workaround in `flake.nix:269-285` is fragile (see Open Q).

### Soft risks

| Risk | Likelihood | Mitigation |
|------|-----------|-----------|
| Waybar config drift after switching to upstream | Med | Diff t14 vs upstream `config/waybar/config`; only delta is `custom/iwd-wifi` |
| `gtk.iconTheme = Papirus-Dark` lost | Med | New `omarchy.gtk.iconTheme` option with default `"Papirus-Dark"` |
| `hyprlock` color source breaks | Med | Upstream already sources theme via palette; t14 source line is redundant |
| Hidden waybar bug (NerdFont U+E900 stripped by `formats.json`) | — | **Auto-fixed** by switching to upstream waybar (raw file deploy) |

### Rollback

Each commit is independently `git revert`-able. No new logic in this repo — only deletions and opt-in moves. Worst case: revert the offending commit, t14 returns to previous working state.

## Open Questions

These need user decision before specs/design:

1. **wayvnc**: Should it become a new upstream module (`omarchy.wayvnc.enable`) or stay as a t14-local HM module? Pushing upstream is cleaner but adds scope to omarchy-nix.

2. **hyprsunset schedule**: Push the progressive warming schedule (07:00/18:00/19:30/21:00/23:00) upstream as `omarchy.hyprsunset.schedule`, or keep as a t14-only `xdg.configFile` override?

3. **hyprlock preferences**: The 6 overrides (size 650×100, Source Sans Pro, "Enter Password", etc.) are user-preference, not t14-specific. Push upstream as `omarchy.hyprlock.*` with new defaults, or keep as t14 `mkForce`?

4. **looknfeel gaps/decoration**: Tight gaps (0/2.5) + no shadow/blur are laptop-friendly defaults. Push as `omarchy.hyprland.gaps_*` / `decoration.*` with new defaults, or keep as t14 `mkForce`?

5. **kb-layout scripts**: Generalize upstream as `omarchy-cycle-keyboard-layout`, or keep as t14-local scripts?

6. **osConfig workaround**: The `_module.args.osConfig = mkForce { omarchy = {}; };` in `flake.nix:269-285` exists because of an upstream eval bug. Should we fix the one-line upstream fix (`attr or default` in `omarchy-nix:flake.nix:55`) in this same change? This would let us delete the entire workaround.

## Capabilities

### New Capabilities
None — pure refactor, no user-facing behavior changes.

### Modified Capabilities
None — spec-level behavior unchanged. All modifications are internal ownership moves.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `hosts/t14/home/hypr/*.nix` (8 files) | Removed/Modified | 5 deleted, 3 trimmed |
| `hosts/t14/home/default.nix` | Modified | Waybar override → iwd-wifi only |
| `hosts/t14/home/omarchy.nix` | Modified | 175 → ~30 lines (pure import shim) |
| `hosts/t14/home/scripts/*` | Removed | 2 deleted, 2 stay (kb-*) |
| `hosts/t14/home/wayvnc/` | Removed | If moved upstream |
| `hosts/t14/default.nix` | Modified | Portal overrides deleted, omarchy block expanded |
| `github:glats/omarchy-nix` | Modified | 12–14 new options + wayvnc module (optional) |

## Dependencies

- `github:glats/omarchy-nix` must accept the new options before this repo can consume them
- Each phase's upstream commit must land + flake input bumped before local deletions

## Success Criteria

- [ ] `nix flake check --no-build` passes after each commit
- [ ] `nixos-build dry` succeeds after phases 2–4
- [ ] t14 host tree ≤ 650 lines (from ~1250)
- [ ] Zero `mkForce` overrides in `home/omarchy.nix` (all converted to `omarchy.*` opt-ins)
- [ ] `hosts/t14/home/hypr/` has ≤ 3 files (from 8)
- [ ] Hyprland session launches, waybar renders (including U+E900 icon), wayvnc connects
- [ ] HM standalone `hms` still builds (osConfig workaround intact or fixed upstream)
