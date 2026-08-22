# Design: Diagnose t14 Hyprland Login Failure

## Technical Approach

Use a proof-first, three-phase diagnosis for t14 only. Phase A collects runtime evidence from the deployed system before edits. Phase B runs one separator experiment only if evidence is unavailable or inconclusive. Phase C records support/refutation and rolls back if the separator does not prove the active candidate. This implements the `t14-hyprland-login-diagnosis` spec without upstream `omarchy-nix`, regreet, or GPU scope.

## Architecture Decisions

| Decision | Choice | Alternatives considered | Rationale |
|---|---|---|---|
| Evidence before edits | Manual `journalctl`, `systemctl --user`, and generated-config inspection | Immediate Nix edit | Zero-code proof is smaller and preserves facts vs hypotheses. |
| Separator scope | Only `hosts/t14/home/omarchy.nix` if needed | `omarchy-nix` change, regreet restore, greeter redesign | The local file owns the current forced `systemd.extraCommands`; changing it is smallest and reversible. |
| No helper script | Paste commands manually and record output | Add diagnosis script/module | One-off diagnosis does not justify a maintained abstraction. |
| Greeter remains fixed | Leave `hosts/t14/omarchy-config.nix` and `hosts/t14/default.nix` unchanged | Restore regreet or remove placeholder | Spec requires keeping `tuigreet`; placeholder is eval-only for `tuigreet`. |

## Data Flow

```text
Failed login attempt
  └─ Phase A: collect facts
       ├─ greetd journal: selected command/auth result
       ├─ user journal: Hyprland/UWSM/systemd target events
       ├─ user systemd state: wayland/graphical/hyprland targets
       └─ generated hyprland.conf: first exec-once commands
          ↓
     conclusive? yes → Phase C record proof/refutation, no edit
          ↓ no
  Phase B: t14-only separator in hosts/t14/home/omarchy.nix
          ↓
  Phase C: login test, record outcome, rollback on refutation/regression
```

## File Changes

| File | Action | Description |
|---|---|---|
| `openspec/changes/diagnose-t14-hyprland-login-failure/design.md` | Create | This design artifact. |
| `hosts/t14/home/omarchy.nix` | Future conditional modify | Phase B only: set `wayland.windowManager.hyprland.systemd.enable = false`; remove the forced `systemd.extraCommands` stop/start override. |
| `hosts/t14/omarchy-config.nix` | Unchanged | Keep `omarchy.greeter.type = "tuigreet"`. |
| `hosts/t14/default.nix` | Unchanged | Keep the `tuigreet` placeholder `/etc/greetd/hyprland.conf`. |

## Interfaces / Contracts

Nix option boundary to use only in Phase B:

```nix
wayland.windowManager.hyprland.systemd.enable = false;
```

No new scripts, modules, packages, or OpenSpec capabilities. Runtime evidence commands are manual operator commands, not repository interfaces.

Phase A command set:

```bash
journalctl -b -u greetd --no-pager
journalctl --user -b --no-pager
systemctl --user status 'wayland-wm@*.service' 'wayland-session@*.target' graphical-session.target hyprland-session.target
grep -n '^exec-once' ~/.config/hypr/hyprland.conf | head -5
```

## Testing Strategy

| Layer | What to Test | Approach |
|---|---|---|
| Static | Phase B config still evaluates | If Phase B edits occur, run `nix fmt -- hosts/t14/home/omarchy.nix` and `nix flake check --no-build`. |
| Runtime evidence | Whether HM `hyprland-session.target` stop/start kills or destabilizes UWSM Hyprland | Compare Phase A logs against generated `exec-once` commands and user unit state. |
| E2E | Stable post-auth t14 Hyprland session | Attempt login after Phase B only if Phase A is inconclusive; success supports candidate locally, failure/refutation triggers rollback. |

## Threat Matrix

Manual shell commands are diagnostic only; no repository-owned command runner is introduced.

| Boundary | Applicability | Design response | Planned RED tests |
|---|---|---|---|
| Documentation-like paths | N/A: no executable-file classification | None | None |
| Git repository selection | N/A: no git automation | None | None |
| Commit state | N/A: no commit automation | None | None |
| Push state | N/A: no push automation | None | None |
| PR commands | N/A: no PR automation | None | None |

## Migration / Rollout

No migration required. Rollout is manual and local to t14. Roll back by reverting the Phase B edit in `hosts/t14/home/omarchy.nix`; if Phase A proves/refutes without edits, rollback is unnecessary.

## Open Questions

- [ ] Can the user access a VT or SSH shell immediately after a failed `greetd` login to collect Phase A logs?
