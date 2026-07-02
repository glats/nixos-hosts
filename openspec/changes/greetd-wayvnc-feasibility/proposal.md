# Proposal: greetd + wayvnc — pre-login VNC on t14

## Intent

t14 has greetd + regreet (Hyprland session as `greeter` user) but no VNC at the login screen. User-session wayvnc only starts after login. This enables pre-login VNC so remote users can authenticate without physical console. Pattern is proven (Enzime/dotfiles-nix, tabasco0322/nixbix) and additive — no new dependencies.

## Scope

### In Scope
- `omarchy.greeter.wayvnc` submodule: `enable`, `address` (default `0.0.0.0`), `port` (default `5900`), `enablePam` (default `true`)
- Inject `exec-once = wayvnc ${address} ${port} &` before `exec-once = greetd-regreet-start` in greeter Hyprland config
- Deploy `/var/lib/greeter/.config/wayvnc/config` via `systemd.tmpfiles.rules`
- Opt-in: `omarchy.greeter.wayvnc.enable = true` in `hosts/t14/default.nix`

### Out of Scope
- greetd config, user-session wayvnc, rog/thinkcentre, firewall, lock screen VNC

## Capabilities

> Contract between proposal and specs phases.

### New Capabilities
- `greeter-wayvnc`: Pre-login VNC in the greetd Hyprland session. Covers submodule options, exec-once injection, and tmpfiles config deployment.

### Modified Capabilities
None.

## Approach

**Enzime pattern (Hyprland flavor):**

1. **omarchy-nix** (~30 lines): Add submodule to `config.nix`. In `system.nix`, prepend conditional `exec-once = wayvnc <addr> <port> &` before regreet. Deploy config via tmpfiles.
2. **nixos-hosts** (~5 lines): Opt in on t14.
3. **Verify**: `nix flake check --no-build` + `nixos-build build` + manual cold-boot VNC test.

wayvnc inherits `WAYLAND_DISPLAY`/`XDG_RUNTIME_DIR` from greeter Hyprland. PAM auth via existing `security.pam.services.wayvnc`. Same port 5900 as user-session — Remmina auto-reconnects across ~1s handoff gap.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `omarchy-nix/modules/nixos/config.nix` | Modified | Add `omarchy.greeter.wayvnc` submodule |
| `omarchy-nix/modules/nixos/system.nix` | Modified | Conditional exec-once + tmpfiles |
| `hosts/t14/default.nix` | Modified | Opt-in |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Port conflict (greeter vs user wayvnc) | None | Greeter wayvnc exits before user wayvnc starts |
| 1s VNC disconnect at login | Certain | Remmina auto-reconnect; documented |
| Pre-login network exposure | Low | Trusted-LAN model; PAM + VeNCrypt TLS |
| wayvnc fails to start | Low | Additive — regreet works regardless |

## Rollback Plan

Two independent commits: (1) omarchy-nix submodule + tmpfiles, (2) t14 opt-in. Each `git revert`'d independently. No state, no migration.

## Dependencies

- `omarchy-nix` fork (push access per AGENTS.md)
- `pkgs.wayvnc` and `security.pam.services.wayvnc` already present via omarchy-nix

## Success Criteria

- [ ] `nix flake check --no-build` passes all hosts
- [ ] `/etc/greetd/hyprland.conf` has wayvnc exec-once BEFORE greetd-regreet-start
- [ ] `/var/lib/greeter/.config/wayvnc/config` has correct address/port/enable_pam
- [ ] VNC to t14:5900 pre-login shows regreet; post-login auto-reconnects to desktop
- [ ] Disabling `enable = false` removes all greeter-wayvnc artifacts
