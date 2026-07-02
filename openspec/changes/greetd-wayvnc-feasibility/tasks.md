# Tasks: greetd + wayvnc — pre-login VNC on t14

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~35 (omarchy-nix: ~30, nixos-hosts: ~5) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | 2 PRs: PR 1 (omarchy-nix, 2 commits) → PR 2 (nixos-hosts, 1 commit) |
| Delivery strategy | single-pr (per repo) |
| Chain strategy | n/a |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | omarchy-nix module: option surface + injection + tmpfiles | PR 1 to `omarchy-nix` | 2 commits; no host enable; flake still evaluates |
| 2 | t14 opt-in to `omarchy.greeter.wayvnc.enable` | PR 2 to `nixos-hosts` | 1 commit; depends on PR 1 (flake input must be updated); only host affected |

## Phase 1: Option surface (omarchy-nix, commit 1 of 2)

- [x] 1.1 Add `omarchy.greeter.wayvnc` submodule to `/home/glats/repos/omarchy-nix/config.nix` after the `cursor` submodule (line 348). Options: `enable` (bool, default `false`), `address` (str, default `"0.0.0.0"`), `port` (port, default `5900`), `enablePam` (bool, default `true`). Verify: `nix flake check --no-build` inside omarchy-nix passes (options parse, no host references the new options yet).

## Phase 2: Wire behavior (omarchy-nix, commit 2 of 2)

- [x] 2.1 In `/home/glats/repos/omarchy-nix/modules/nixos/system.nix`: (a) add a `wayvncExec` let-binding inside the `environment.etc."greetd/hyprland.conf".text` let-block (lines 172–199) using `lib.optionalString cfg.greeter.wayvnc.enable`, then prepend `${wayvncExec}` to the `exec-once = ${greeterScript}` line (line 201); (b) add a `systemd.tmpfiles.rules` entry gated by `lib.mkIf cfg.greeter.wayvnc.enable` (append to list at line 54) that deploys `/var/lib/greeter/.config/wayvnc/config` (type `f`, mode `0640`, owner `greeter:greeter`) using a `wayvncConfigContent` let-binding built from `address`/`port`/`enablePam`. Verify: `nix flake check --no-build` inside omarchy-nix passes; no host has `enable = true` so no artifacts should appear.

## Phase 3: Enable on t14 (nixos-hosts)

- [x] 3.1 In `/home/glats/.nixos/hosts/t14/default.nix`, add `wayvnc = { enable = true; };` inside the existing `greeter = { ... }` block (after line 198). Update the `omarchy-nix` flake input lock to point at the new commit (PR 1). Verify: `nix flake check --no-build` (all hosts evaluate) and `nixos-build build` for t14 succeed.

## Phase 4: Manual verification (post-switch on t14)

- [ ] 4.1 Inspect `/etc/greetd/hyprland.conf` — confirm wayvnc `exec-once` line appears BEFORE the `greetd-regreet-start` line (req 1, scenario 1; req 5, scenario 2).
- [ ] 4.2 Inspect `/var/lib/greeter/.config/wayvnc/config` — confirm `address`, `port`, `enable_pam` match the configured values, owned by `greeter:greeter`, mode `0640`, readable by greeter (req 3, scenarios 1–2).
- [ ] 4.3 Cold-boot E2E — connect VNC client (Remmina) to t14:5900 pre-login, confirm regreet visible, authenticate, confirm auto-reconnect to user desktop during the ~1 s handoff (req 1, req 2 scenarios 1–2, req 4 scenarios 1–2).
- [ ] 4.4 Custom port test — set `omarchy.greeter.wayvnc.port = 5901`, rebuild + switch, confirm wayvnc listens on 5901 and the deployed config reflects port 5901 (req 6, scenario 1).
- [ ] 4.5 Negative test — set `omarchy.greeter.wayvnc.enable = false`, rebuild, confirm no wayvnc `exec-once` in `/etc/greetd/hyprland.conf` and no `/var/lib/greeter/.config/wayvnc/config` file (req 5, scenario 1).
