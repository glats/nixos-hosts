# Proposal: Fix Screensaver Idle Lock Toggle

## Intent

Super+Ctrl+I (toggle idle lock) is broken: systemd's `Restart=always` auto-restarts hypridle 10s after `systemctl stop`, and `ExecStartPre` clears the `screensaver-off` flag on restart. The toggle has no lasting effect.

## Scope

### In Scope
- Override hypridle's systemd `Restart` from `always` to `on-failure` in omarchy-nix
- Bump nixos-hosts flake.lock to pick up the omarchy-nix fix

### Out of Scope
- Changes to `omarchy-toggle-idle`, `omarchy-launch-screensaver`, or `omarchy-screensaver`
- T14 host overrides (`hosts/t14/home/omarchy.nix`)
- Monitor config, keybindings, or multi-monitor screensaver logic

## Capabilities

**New Capabilities**: None — config-level fix, no new feature.
**Modified Capabilities**: None — no spec-level behavior change.

## Approach

Re-apply the fix from commit `92a3745` (reverted in `5cad0b7` without explanation) using CORRECT Nix syntax:

```nix
# modules/home-manager/hypridle.nix — add to existing Service attrset:
systemd.user.services.hypridle.Service = {
  ExecStartPre = [ ... ];  # already present
  Restart = lib.mkForce "on-failure";  # ADD this line
};
```

The original commit `92a3745` used `systemd.user.services.hypridle.Service = { ... }` which REPLACED the entire Service attrset, wiping out HM's `ExecStart`. The corrected syntax uses individual attribute paths — `Service.Restart` — preserving all other HM defaults.

Also add `lib` to the module signature (`{ pkgs, lib, ... }:` instead of `{ pkgs, ... }:`).

**Effect**: `Restart=on-failure` only restarts hypridle on crash (non-zero exit), not after explicit `systemctl stop`. The toggle script's `screensaver-off` flag persists, and hypridle stays stopped.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `omarchy-nix/modules/home-manager/hypridle.nix` | Modified | Add `lib` to signature; add `Restart = lib.mkForce "on-failure"` |
| `nixos-hosts/flake.lock` | Modified | Bump omarchy-nix input to commit with fix |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Revert reason unknown — possible hidden dependency on Restart=always | Low | `on-failure` is the upstream hypridle package default; HM overrides it to `always`. No code depends on the override. |
| HM module changes default in future | Low | `lib.mkForce` already handles any HM default. |
| Breakage on other omarchy-nix hosts | Low | `on-failure` is the package's intended behavior. Only t14 tests the toggle, but the change is safe for all hosts. |

## Rollback Plan

1. Revert the hypridle.nix commit in omarchy-nix: remove `Restart` line, drop `lib` from signature
2. Bump nixos-hosts flake.lock back to previous omarchy-nix rev
3. `nixos-build build` on t14 to confirm hypridle starts normally

## Dependencies

- Write access to `github:glats/omarchy-nix` (confirmed per AGENTS.md)
- `~/.git-credentials` for auth (confirmed per launch instructions)

## Success Criteria

- [ ] `omarchy-toggle-idle` stops hypridle and it stays stopped (no auto-restart)
- [ ] `screensaver-off` flag persists after toggle (not cleared by ExecStartPre restart)
- [ ] Hypridle still restarts on legitimate crashes (non-zero exit)
- [ ] `nix flake check --no-build` passes on nixos-hosts
- [ ] Hypridle service starts correctly on system boot / login
