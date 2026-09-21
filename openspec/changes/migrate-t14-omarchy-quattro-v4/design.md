# Design: Migrate T14 Omarchy to Quattro v4

## Technical Approach

Port Quattro as a breaking portable v4 runtime in `omarchy-nix`, then consume its pin only from `t14`. Build t14 NixOS/HM from one newer nixpkgs/Home Manager/Hyprland/Quickshell boundary; global 26.05 still builds `rog`, `thinkcentre`, and Intel `mact2`. Quickshell begins only after successful user login; it does not replace the pre-login display-manager path.

`omacom/omarchy` is the design reference. Nix deviations need adjacent comments. Portable work commits directly to `omarchy-nix/main`; the consumer input bump follows.

## Architecture Decisions

| Decision | Choice | Alternatives considered | Rationale |
|---|---|---|---|
| Package boundary | Add t14 nixpkgs, HM, and v4 omarchy inputs; parameterize `mkNixosHost` and standalone HM to use that boundary and Linux overlay once. V4 follows t14 nixpkgs/HM. | Global upgrade; newer Quickshell on 26.05. | Keeps Qt, Hyprland, Quickshell, and HM coherent without moving mact2. |
| Ownership | `omarchy-nix` owns Quickshell/QML/assets, Lua, IPC, themes, NM, PAM, and polkit. `.nixos` owns t14 policy, HDM, WayVNC, Edge, SOPS, hardware, and networking. | Consumer-owned portable runtime. | Reusable desktop, local workarounds. |
| Runtime | Lua autostart launches one `omarchy-shell`; its services replace v3 UI daemons. | Parallel selected v3 daemons. | Prevents duplicate UI and authentication owners. |
| Configuration | Package defaults are immutable; HM creates only writable `~/.config/omarchy/` overrides, including `shell.toml`. | Store mutable state; v3 watcher. | Reproducible builds and native Quattro overrides. |
| Pre-login path | Retain `greetd` with ReGreet in its minimal Hyprland greeter session; start Quickshell only in the post-login UWSM user session. | Start Quickshell in the greeter; replace ReGreet. | Quattro is the logged-in desktop shell and must not take ownership of login or pre-login WayVNC. |
| Monitor-profile ownership | Retain HDM as the sole dock/lid monitor-profile writer, using UPower D-Bus lid events and Hyprland IPC. Preserve its `config.toml` and all static `.conf` profiles. | Quattro Lua or monitor hooks writing layouts; concurrent HDM and Quattro writers. | One writer prevents layout races while retaining the proven T14 docked/undocked and lid-open/lid-closed behavior. |

## Data Flow

    NixOS ──→ greetd → ReGreet + minimal Hyprland (pre-login)
       │                         │
       │                         └─→ pre-login WayVNC
       └─→ UWSM → user login → Lua → Quickshell (post-login only)
                                      │
    UPower lid events + Hyprland IPC → HDM → static .conf profile → monitors.conf

Quickshell uses Hyprland IPC, NetworkManager D-Bus, and NixOS PAM; it never writes `/etc/pam.d` imperatively. HDM remains independent of Quickshell and is the only component that applies monitor profiles.

## File Changes

| File | Action | Description |
|---|---|---|
| `flake.nix`, `lib/mkHost.nix` | Modify | Isolate and route the t14 package boundary without changing global outputs. |
| `hosts/t14/{default.nix,omarchy-config.nix}` | Modify | Select v4/NM and retain policy, including greetd/ReGreet and disabled competing Omarchy lid handling. |
| `hosts/t14/home/{default.nix,omarchy.nix}` | Modify | Use matching HM packages; adapt post-login Lua; retain HDM, WayVNC, Edge, and SOPS. |
| `hosts/t14/hdm/{config.toml,hyprconfigs/*.conf}` | Preserve | Keep the existing UPower/IPC profile selection and static docked/undocked, lid-open/lid-closed, and fallback layouts. |
| `modules/nixos/{default.nix,system.nix,quattro.nix}` | Modify/Create in `omarchy-nix` | Declarative Quattro, PAM/polkit, and NM. |
| `modules/home-manager/{default.nix,quattro.nix,hyprland-lua.nix,quattro-theme.nix}` | Modify/Create in `omarchy-nix` | Package runtime, deploy Lua/XDG overrides, replace v3 imports. |
| `modules/home-manager/{waybar,walker,mako,swayosd,swaybg,hyprlock,hypridle,theme-generator}.nix` | Delete/stop importing in `omarchy-nix` | Retire v3 runtime after acceptance. |

## Interfaces / Contracts

```nix
omarchy = {
  quattro.enable = true;
  shell = { package = /* boundary Quickshell */; config = /* XDG path */; };
  wifi.backend = "networkmanager"; # standalone-iwd is removed
  lock = { pamService = "omarchy-lock"; fingerprint.enable = false; };
  hyprland.lua = { enable = true; userOverrides = /* Lua files */; };
};
```

`omarchy.quattro.enable` gates v4. V3 standalone-iwd, daemon fonts, Hyprlock overrides, and Waybar have no shim: consumers replace them atomically. Shell, Qt, Hyprland, and HM MUST derive from the same t14 boundary.

## Testing Strategy

| Layer | What to Test | Approach |
|---|---|---|
| Evaluation | Boundary and option removal | Evaluate t14 plus standalone HM; evaluate mact2 from global 26.05. |
| Integration | Lua/shell, PAM/polkit, NM, theme | Fresh session: IPC/restart, panels/OSD, lock recovery, `pkexec`, connect/reconnect, DHCP/DNS, resume, persistent `shell.toml`. |
| Host acceptance | Login separation and monitor-writer exclusivity | Verify ReGreet before login and Quickshell only after user login; test HDM dock/lid profiles, greeter/user WayVNC handoff, Edge binding/MIME, and SOPS; inspect units/processes/generated configs for no v3 daemon or competing monitor writer. |
| Live integration gate | HDM and Quattro monitor interaction | Exercise dock/undock and lid transitions with Quattro Lua and any Quattro monitor hooks enabled. The unchanged HDM `.conf` profiles must apply correctly with no race, duplicate layout write, or monitor oscillation; otherwise block activation. |

## Threat Matrix

| Boundary | Applicability | Design response | Planned RED tests |
|---|---|---|---|
| Documentation-like paths | N/A — no executable classification | N/A | N/A |
| Git repository selection | N/A — no runtime Git selection | N/A | N/A |
| Commit state | N/A — manual delivery workflow | N/A | N/A |
| Push state | N/A — no push automation | N/A | N/A |
| PR commands | N/A — direct fork commits, no PR automation | N/A | N/A |

## Migration / Rollout

1. Retain v3 input/configuration and a bootable generation. Evaluate t14 without altering mact2 inputs or closure.
2. Commit portable v4 first. Before the consumer bump, inspect rendered PAM service names and includes; they must be NixOS semantics, not Arch `system-local-login`. Validate lock recovery and polkit.
3. Bump t14 only once NetworkManager exclusively owns Wi-Fi—no standalone iwd DHCP/DNS or unmanaged `wlan0`. Retain greetd + ReGreet as the pre-login path and validate it, including greeter WayVNC, independently of post-login Quickshell and user-session WayVNC.
4. Treat HDM's existing `config.toml` and static `.conf` profiles versus Quattro Lua and any Quattro monitor hooks as a no-race live validation gate. HDM remains the sole monitor-profile writer through UPower and Hyprland IPC; block activation on any competing write or oscillation.
5. Then remove v3 imports, user unit, PATH assets, and autostart references together. Acceptance requires no `waybar`, `walker`, `mako`, `swayosd-server`, `swaybg`, `hypridle`, `hyprlock`, or `hyprpolkitagent` launched by v4. Roll back to v3 pin/configuration or the retained generation, never individual daemon re-enablement.

## Open Questions

- [ ] Confirm NixOS PAM includes and QML service names on the pinned Quattro revision.
- [ ] Lock newer nixpkgs, Home Manager, Hyprland, and Quickshell as one t14 boundary.
- [ ] Confirm whether the deferred ReGreet keyboard indicator remains independent of Quickshell.
