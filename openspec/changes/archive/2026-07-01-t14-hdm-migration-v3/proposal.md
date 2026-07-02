# Proposal: T14 HDM Migration v3

## Intent

Replace ~290-line custom monitor stack (polling bash daemon + hyprlang conditionals + 300-char bindls + settings.conf + udev drop-in) with HyprDynamicMonitors v1.4.0 — event-driven profiles via native Hyprland IPC and UPower D-Bus. See [exploration.md](exploration.md) for tool evaluation (8 tools surveyed; HDM is the only one with native lid events).

## Scope

### In Scope
- Add `hyprdynamicmonitors` flake input, wire HM module to t14
- Create HDM `config.toml`: 4 profiles + `[fallback_profile]` + `[scoring]` (lid_state_match=10, monitor_match=5, description_match=5) + `[lid_events]` (UPower D-Bus) + `[general]` (debounce_time_ms=1500), description matching with `match_description_using_regex`, `--enable-lid-events` in extraFlags
- Create 5 static hyprconfigs with explicit `monitor=` AND `workspace=` rules per profile (docked-lid-open: 4 monitors at y=420 + ws 1-20; docked-lid-closed: eDP-1 at -30000x0, externals at y=0 + ws 4-20; undocked: only eDP-1 at 0x0 + ws 1-3; fallback: generic)
- Strip old stack: daemon, bindls, hyprlang ifs, settings.conf, udev drop-in, validator script
- Move workspace rules from `mkWorkspaceRules` in `monitors.nix` into HDM profile hyprconfigs (fixes ws 1-3 duplication bug)
- Remove `mkWorkspaceRules` filter — workspace rules live in hyprconfigs, not Nix

### Out of Scope
- `omarchy.greeter.*` (separate session), other hosts, `omarchy-hyprland-monitor-watch` (orthogonal, kept), `omarchy.hyprland.lidSwitch.enable = false` (kept)

## Capabilities

### New Capabilities
- `hdm-profiles`: HDM TOML configuration — 4 profiles, fallback, scoring, lid_events via UPower, description-based match with regex
- `hdm-hyprconfigs`: 5 static Hyprland configs — each profile owns its `monitor=` directives AND `workspace=` rules

### Modified Capabilities
- `t14-monitor-layout`: REMOVE CAP-CONDITIONAL, CAP-DAEMON, CAP-SETTINGS, CAP-DRM, CAP-STANDALONE. MODIFY CAP-LIDSWITCH (keep `lidSwitch.enable=false`; remove T14 bindls — HDM handles lid via UPower D-Bus). MODIFY CAP-HOTPLUG (keep omarchy-hyprland-monitor-watch; remove T14 daemon polling)

## Approach

1. Add `hyprdynamicmonitors` flake input with `inputs.nixpkgs.follows = "nixpkgs"`
2. Wire HM module via `homeManagerModules.default` in t14 HM imports
3. Deploy HDM config via `home.hyprdynamicmonitors` module (inline TOML + extraFiles for hyprconfigs)
4. Strip `monitors.nix` extraConfig, replace with `source` directive to HDM output
5. Delete validator script and all references

## Affected Areas

| File | Action |
|------|--------|
| `flake.nix` | Modified — add flake input |
| `hosts/t14/default.nix` | Modified — import HM module + UPower assertion |
| `hosts/t14/home/default.nix` | Modified — remove old stack, add HDM config |
| `hosts/t14/home/hypr/monitors.nix` | Modified — strip old, add source directive |
| `hosts/t14/home/scripts/monitor-lid-validator.sh` | Deleted |
| `hosts/t14/hdm/config.toml` | NEW |
| `hosts/t14/hdm/hyprconfigs/*.conf` | NEW (5 files) |
| `docs/t14-monitor-layout.md` | Modified — update architecture |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| HDM #152 symlink race ("globbing error") on fast profile switches | Low | debounce_time_ms=1500 absorbs |
| HDM #145 NixOS callback paths (`/usr/bin/bash`) | N/A | Don't use callbacks; workspace rules in hyprconfigs |
| omarchy-hyprland-monitor-watch race with HDM | Low | 1500ms debounce + both idempotent |
| EDID description drift on monitor replacement | Low | `[fallback_profile]` covers unknown sets |

## Rollback

`git revert` the single commit. Old daemon preserved in git history. HDM destination outside HM management — clean removal.

## Success Criteria

- [ ] `nix flake check --no-build` passes for t14
- [ ] All 4 monitor states apply correctly
- [ ] Dead-zone y=420 preserved
- [ ] eDP-1 parked at -30000x0 (not disabled)
- [ ] Workspace 1-3 only on eDP-1, 4-20 on externals
- [ ] No phantom high workspaces when undocked
- [ ] Old daemon, settings.conf, udev drop-in fully removed
- [ ] No cross-host regressions
