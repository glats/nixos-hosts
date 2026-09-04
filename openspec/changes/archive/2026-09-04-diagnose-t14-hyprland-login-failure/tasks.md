# Tasks: Diagnose t14 Hyprland Login Failure

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 10-30 if the separator is needed |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Capture proof on t14 before edits | PR 1 | `journalctl -b -u greetd --no-pager`; `journalctl --user -b --no-pager` | Failed `tuigreet` login, then immediate shell/SSH inspection | None; evidence only |
| 2 | Apply one local separator only if proof is missing | PR 1 | `format-nix`; `nix flake check --no-build` | Rebuild/deploy the t14 generation, then retry `tuigreet` login | Revert only `hosts/t14/home/omarchy.nix` separator lines |
| 3 | Decide keep, rollback, or future follow-up | PR 1 | `nix flake check --no-build` after any edit | Final login result and log review | Keep or revert; no upstream change yet |

## Phase 1: Runtime Evidence

- [x] 1.1 On deployed t14, capture `journalctl -b -u greetd --no-pager`, `journalctl --user -b --no-pager`, `systemctl --user status 'wayland-wm@*.service' 'wayland-session@*.target' graphical-session.target hyprland-session.target`, and `grep -n '^exec-once' ~/.config/hypr/hyprland.conf | head -5` after a failed `tuigreet` login.
- [x] 1.2 Record only observed facts: whether the user journal shows `hyprland-session.target` stop/start behavior, whether the generated config matches the suspect path, and whether the evidence is conclusive.

## Phase 2: Minimal Separator (only if Phase 1 is insufficient)

- [x] 2.1 Edit `hosts/t14/home/omarchy.nix` to set `wayland.windowManager.hyprland.systemd.enable = false;` and remove the rescue `extraCommands` override that stops/starts `hyprland-session.target`.
- [x] 2.2 Run `format-nix` on the edited file, then run `nix flake check --no-build`.

Observed during apply: generated `~/.config/hypr/hyprland.conf` still contained `uwsm finalize ... && systemctl --user stop hyprland-session.target && systemctl --user start hyprland-session.target`; source tree no longer contained a local `systemd.extraCommands` override, so the separator edit only added `wayland.windowManager.hyprland.systemd.enable = false;`.

## Phase 3: Local Proof

- [x] 3.1 Deploy the t14 generation with the normal host flow, then test a fresh login and confirm whether the Hyprland session stays alive after auth.
- [x] 3.2 If login still fails or regresses, revert only the separator lines in `hosts/t14/home/omarchy.nix` and stop; do not expand scope.

Observed after deploy/reboot: user reported the laptop opened ReGreet and login succeeded. No rollback needed.

## Phase 4: Decision

- [x] 4.1 Decide and record one outcome: keep the separator, rollback the separator, or open a later upstream follow-up for `omarchy-nix`.
- [x] 4.2 If local proof holds, keep the change local for now; if it fails, preserve the logs and leave upstream work as a future optional follow-up only.

Decision: keep the local separator for now. Upstream `omarchy-nix` follow-up remains optional and separate.
