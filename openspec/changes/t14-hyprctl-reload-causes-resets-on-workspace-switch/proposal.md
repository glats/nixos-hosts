# Proposal: t14-hyprctl-reload-causes-resets-on-workspace-switch

## Intent

Fix waybar crashes (disappear/reappear) on T14 workspace switches. Four causes: (1) validator daemon `hyprctl reload` every 2s, (2) dual workspace bindings (1-3 to externals AND eDP-1) creating hybrid rules via Hyprland 0.55 `mergeLeft`, (3) omarchy-nix `monitoradded>>` reload on dock, (4) waybar v0.15.0 SIGSEGV on `destroyworkspace>>` events (upstream #4361, #4357, #5008, #5035; fix in unreleased PR #5103).

## Scope

### In Scope
- Remove `hyprctl reload` from `monitor-lid-validator.sh:47`
- Filter workspaces 1-3 from `mkWorkspaceRules` in `monitors.nix`
- Remove `monitoradded>>` → `hyprctl reload` from `omarchy-nix/bin/omarchy-hyprland-monitor-watch`
- Wrap waybar launch with stderr capture in `autostart.nix`

### Out of Scope
- Switch to `ext/workspaces` module (fallback)
- Rebuild waybar from git with PR #5103 (fallback)
- Other hosts, greeter layout

## Capabilities

### New Capabilities
None

### Modified Capabilities
- `t14-monitor-layout`: CAP-DAEMON (REQ-DAEMON-6: remove reload), CAP-HOTPLUG (REQ-HOTPLUG-1: remove `monitoradded>>` reload), CAP-CONDITIONAL (filter 1-3 from external rules)

## Approach

Four synchronous changes (Approach 3+4):
1. **Daemon**: Remove `hyprctl reload` from `apply()` — uses `hyprctl keyword` only
2. **Workspace rules**: `builtins.filter (w: w > 3)` — 1-3 bind only to eDP-1 (lid open) or auto-assign (lid closed)
3. **Monitor-watch**: Remove `monitoradded>>` handler — daemon polling handles hotplug
4. **Stderr capture**: `uwsm-app -- bash -c 'exec waybar 2>>$HOME/.cache/waybar-stderr.log'`

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `hosts/t14/home/scripts/monitor-lid-validator.sh` | Modified | Remove `hyprctl reload` |
| `hosts/t14/home/hypr/monitors.nix` | Modified | Filter workspaces 1-3 |
| `omarchy-nix/bin/omarchy-hyprland-monitor-watch` | Modified | Remove `monitoradded>>` handler |
| `omarchy-nix/modules/home-manager/hyprland/autostart.nix` | Modified | Stderr capture wrapper |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Waybar still crashes (Hyprland 0.55/waybar incompatibility) | Medium | Stderr diagnoses; fallback: `ext/workspaces` or PR #5103 rebuild |
| `monitoradded>>` removal affects omarchy behavior | Low | Owned repo, recent change; daemon handles layout |
| Workspaces 1-3 unbound docked+lid closed | Low | Hyprland auto-assigns; `persistent:true` keeps stable |

## Rollback Plan

Revert commits in nixos-hosts and omarchy-nix, rebuild.

## Dependencies

- omarchy-nix (user-owned, push access)
- flake.lock pins omarchy-nix at `3b42b9d` — activates on next rebuild

## Success Criteria

- [ ] `nix flake check --no-build` passes
- [ ] `format-nix` passes
- [ ] No `hyprctl reload` in t14 validator or omarchy monitor-watch
- [ ] Workspaces 1-3 bound only to eDP-1 (lid open) or unbound (lid closed)
- [ ] No waybar flicker on rapid workspace switching
- [ ] Waybar stderr captured at `~/.cache/waybar-stderr.log`
