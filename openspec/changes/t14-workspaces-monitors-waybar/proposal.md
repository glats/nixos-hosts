# Proposal: Fix Waybar Workspace Visibility on t14 Multi-Monitor Setup

## Intent

Waybar on t14 shows phantom workspaces instead of actual Hyprland workspaces. Root cause: `persistent-workspaces` uses workspace numbers as keys (`"1"`, `"2"`...), but waybar's C++ source interprets keys as **monitor names** (e.g., `DP-3`). No monitor named `"1"` exists → phantom mode. With `all-outputs: false` (default), only the focused monitor's phantoms appear. Hyprland bindings (AOC→ws1, Lenovo→ws2, AOC→ws3 via mod-3 distribution) are already correct — only waybar display is broken.

## Scope

### In Scope
- Fix `persistent-workspaces` in `omarchy-nix/config/waybar/config` to use `"*"` key with workspace array
- Add `"all-outputs": true` to show workspaces across all monitors
- Bump `omarchy-nix` flake input in `nixos-hosts/flake.lock`

### Out of Scope
- Changes to Hyprland workspace bindings (already correct)
- Per-monitor workspace filtering (deferred — `all-outputs: true` shows all 20 on every bar)
- Waybar config for other hosts (rog, thinkcentre — no Hyprland)

## Capabilities

### New Capabilities
- None

### Modified Capabilities
- None (waybar is not a tracked spec capability; this is a config fix in omarchy-nix upstream)

## Approach

**Upstream fix in omarchy-nix** (glats has direct push access — no PR needed):

1. Edit `omarchy-nix/config/waybar/config` — replace `persistent-workspaces`:
   ```json
   "persistent-workspaces": { "*": [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20] }
   ```
2. Add `"all-outputs": true` to `hyprland/workspaces` module
3. Commit+push to `omarchy-nix`, bump `flake.lock` in `nixos-hosts`
4. Validate: `nix flake check --no-build`

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `omarchy-nix/config/waybar/config` | Modified | Fix persistent-workspaces keys + add all-outputs |
| `nixos-hosts/flake.lock` | Modified | Bump omarchy-nix input to new commit |

## Alternatives Considered

- **t14-only override**: Copy waybar config into `hosts/t14/home/` — rejected, duplicates upstream config and defeats omarchy-nix purpose
- **Minimal workaround**: Set `all-outputs: true` without fixing keys — rejected, still shows phantoms
- **Per-monitor waybar instances**: One waybar per monitor with filtered workspaces — rejected, overengineered for this use case

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| 20 workspaces clutter every bar | Medium | Compact single-char icons (1-9, A-J) already defined |
| `"*"` syntax unsupported | Low | waybar 0.11+ in nixos-unstable supports it |

## Rollback Plan

Revert omarchy-nix commit (single JSON change), run `nix flake lock --update-input omarchy-nix` in nixos-hosts, rebuild.

## Dependencies

- `omarchy-nix` repo push access (confirmed: glats has full access)
- waybar 0.11+ with `"*"` persistent-workspaces support (confirmed in nixos-unstable)

## Success Criteria

- [ ] Docked t14 shows workspaces 1-20 on all 3 external monitors in waybar
- [ ] Workspace icons reflect actual Hyprland state (occupied vs empty)
- [ ] `nix flake check --no-build` passes
- [ ] Undocked (single laptop screen) still shows workspaces correctly
