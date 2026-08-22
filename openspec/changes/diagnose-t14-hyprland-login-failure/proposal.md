# Proposal: Diagnose t14 Hyprland Login Failure

## Intent

Prove why t14 returns/fails after `greetd` authentication without assuming root cause. Prior fixes were too broad; this change keeps facts, hypotheses, and reversible experiments separate.

## Proposal question round

- Assumption: a narrow diagnosis/proof change is preferred over restoring final greeter UX now.
- Assumption: if runtime logs are available, collect proof before editing.
- Assumption: if logs are unavailable, one local t14-only separator experiment is acceptable.

## Scope

### In Scope
- Collect runtime proof from `greetd`, user journal, user systemd units, and generated Hyprland config.
- If proof cannot be collected, run the smallest reversible t14-only separator: disable Home Manager Hyprland systemd integration and remove the local `extraCommands` rescue override.
- Keep `tuigreet` as the active greeter during diagnosis.

### Out of Scope
- No upstream `omarchy-nix` change until local proof succeeds.
- No regreet restoration or greeter redesign.
- No GPU/aquamarine fixes unless logs prove that path.

## Capabilities

### New Capabilities
- None — diagnosis/proof only.

### Modified Capabilities
- None — no existing OpenSpec requirement changes yet.

## Approach

1. Prefer zero-code proof: capture logs around a failed login and inspect the generated first `exec-once` command.
2. If runtime proof is unavailable, apply one t14-local separator experiment in `hosts/t14/home/omarchy.nix`: set `wayland.windowManager.hyprland.systemd.enable = false` and remove the forced `systemd.extraCommands` stop/start override.
3. Treat success as local proof only; then decide separately whether to promote behavior to `omarchy-nix`.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `hosts/t14/home/omarchy.nix` | Modified only if logs unavailable | Separator experiment for HM/UWSM systemd interaction. |
| `hosts/t14/omarchy-config.nix` | Unchanged | Keep `tuigreet` during diagnosis. |
| `hosts/t14/default.nix` | Unchanged | Do not change greeter placeholder in this slice. |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Logs reveal a different root cause | Medium | Stop and revise; do not apply separator blindly. |
| Disabling HM systemd integration affects session-bound services | Medium | Keep change t14-only and reversible. |
| Local success gets mistaken for upstream proof | Medium | Require local proof before any `omarchy-nix` proposal. |

## Rollback Plan

Revert only the t14-local separator lines in `hosts/t14/home/omarchy.nix`; leave `tuigreet` unchanged. If no edit is made, rollback is unnecessary.

## Dependencies

- Shell/SSH access after a failed login attempt, if runtime proof is collected first.

## Success Criteria

- [ ] Runtime evidence identifies whether `hyprland-session.target` stop/start terminates or destabilizes the UWSM session.
- [ ] If logs are unavailable, the t14-only separator either restores login or clearly fails without additional scope.
- [ ] Facts and hypotheses remain separated before any upstream change is proposed.
