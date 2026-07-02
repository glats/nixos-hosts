# Exploration: greetd + wayvnc feasibility (pre-login VNC on t14)

## TL;DR

**Feasibility: HIGH.** The t14 host is already wired to `greetd` +
`regreet-in-Hyprland` (via `omarchy.greeter.type = "regreet"` in
`hosts/t14/default.nix`). The greeter already runs inside a Hyprland
session owned by the system user `greeter`. Adding wayvnc to that same
session is a known pattern, with **multiple working NixOS examples** in
the wild (Enzime/dotfiles-nix, tabasco0322/nixbix). The change is
**additive and small** (≈10 lines of Nix): a single `exec-once = wayvnc
&` in the greeter Hyprland config, plus a config file for the greeter
user. No new package, no new service manager, no new dependency.

This change is **scoped to t14 only** — rog and thinkcentre do not use
greetd at all (MATE via XRDP), and mact2 is nix-darwin (no greetd).

## Current state

### Host inventory (this repo)

| Host | Display manager | Greeter | wayvnc | Source |
|------|-----------------|---------|--------|--------|
| **rog** | XRDP (MATE) | none (XRDP login screen) | no | `hosts/rog/default.nix` — no greetd/regreet references |
| **thinkcentre** | XRDP (MATE) | none (XRDP login screen) | no | `hosts/thinkcentre/default.nix` — no greetd/regreet references |
| **t14** | **greetd** | **regreet** (inside Hyprland) | **yes** (user session, port 5900) | `hosts/t14/default.nix:178-199` (greeter) + `hosts/t14/default.nix:172-176` (wayvnc) |
| mact2 | nix-darwin (loginwindow) | n/a | no | not relevant |

`grep` of the entire repo for `greetd|regreet|tuigreet|greeter` returns
**5 matches, all in `hosts/t14/default.nix`**. t14 is the only host
where this is in scope.

### t14 greetd + regreet setup (canonical)

Defined in `omarchy-nix/modules/nixos/system.nix` (forked module, not
vendored here — pinned in `flake.nix:20` to `github:glats/omarchy-nix/main`).
Key file: `/home/glats/repos/omarchy-nix/modules/nixos/system.nix`.

What omarchy-nix does on t14 (with `omarchy.greeter.type = "regreet"`):

1. **Enables greetd** and sets
   `services.greetd.settings.default_session` to:
   ```nix
   command = lib.mkForce "${pkgs.hyprland}/bin/start-hyprland -- --config /etc/greetd/hyprland.conf";
   user = "greeter";
   ```
   This starts a Hyprland compositor running as the system user
   `greeter`, reading the config at `/etc/greetd/hyprland.conf`.
2. **Enables programs.regreet** (`programs.regreet.enable = true`).
3. **Creates the greeter user**:
   `users.users.greeter` with `extraGroups = [ "video" ]`, home
   `/var/lib/greeter`. The `video` group is required for Hyprland's KMS
   access.
4. **Generates `/etc/greetd/hyprland.conf`** from
   `omarchy.greeter.{monitors,keyboard,cursor}` plus a wrapper script
   `greetd-regreet-start` that:
   - Disables `eDP-1` if any external monitor is connected (so the
     laptop panel doesn't fight the dock monitor for the greeter window).
   - Launches `${pkgs.regreet}/bin/regreet`.
   - Calls `hyprctl dispatch exit` after regreet returns.
5. **Configures the Hyprland session for the greeter** with the user's
   keyboard layouts (`omarchy.greeter.keyboard.layouts/options`),
   monitor block, and cursor env vars (XCURSOR_THEME/HYPRCURSOR_THEME/
   XCURSOR_SIZE/HYPRCURSOR_SIZE) on a `greeter` user Hyprland instance.

The greeter session is **a real Hyprland instance** with its own
Wayland socket at
`/run/user/<greeter-uid>/hypr/<instance-signature>/.socket.sock` and
its own `WAYLAND_DISPLAY=wayland-1` (the user session is
`wayland-0`).

### t14 wayvnc setup (current — user session only)

Defined in `omarchy-nix/modules/{nixos,home-manager}/wayvnc.nix`,
gated by `omarchy.wayvnc.enable = true` (set in
`hosts/t14/default.nix:176` and `flake.nix:273` standalone-HM).

What it does today:
- `programs.wayvnc.enable = true` (NixOS module adds package + PAM
  service).
- `environment.systemPackages = [ pkgs.wayvnc ]` (provides
  `wayvnc` and `wayvncctl`).
- `xdg.configFile."wayvnc/config"` (HM) with `use_relative_paths=true`,
  `address=0.0.0.0`, `port=5900`, `enable_pam=true`.
- `systemd.user.services.wayvnc` (HM) bound to
  `graphical-session.target`, with `PassEnvironment` for
  `WAYLAND_DISPLAY`, `XDG_RUNTIME_DIR`, `DISPLAY`. ExecStart =
  `${pkgs.wayvnc}/bin/wayvnc`. Restart on failure.

This is the **post-login user session** wayvnc. It does **not** run at
the greetd login screen — when the user logs out, the user systemd
manager tears down, the service stops, and the VNC port becomes
unreachable until the user re-logs in.

### What the existing wayvnc setup can NOT do today

There is no VNC access at the login screen. Specifically:
- **Pre-login** (greetd is showing regreet) — no VNC.
- **Lock screen** (hyprlock, after `omarchy-system-lock`) — no VNC. The
  user systemd manager is still running, but `wayvnc` is bound to
  `graphical-session.target` and Hyprland's wlroots screencopy will
  show the lock screen, NOT the greeter. (Note: this is acceptable
  for the lock screen — VNC into a lock screen is normally what users
  want — but it's a different concern from the greeter.)
- **Reboot / disk-encryption password prompt** (plymouth / initrd
  Dropbear) — out of scope for any VNC approach; this is a network
  pre-boot problem solved by initrd SSH (Dropbear) or Clevis/Tang.

This exploration is about closing the **greetd** gap: enabling VNC
access to the regreet login screen.

## wayvnc capabilities (architecture)

### Hard requirements (from the wayvnc manpage + upstream README)

- **Must attach to a running wlroots-based Wayland compositor.** It
  uses the `wlroots` `wlr-screencopy-unstable-v1` and
  `zwlr-virtual-pointer-v1` / `zwlr-input-method-v2` protocols.
  wlroots compositors: Sway, Hyprland, Wayfire, river, cage. **NOT
  supported: Gnome, KDE, Weston.**
- **Reads the Wayland socket from `$WAYLAND_DISPLAY` (default
  `wayland-0`)** and `$XDG_RUNTIME_DIR` (default
  `/run/user/$UID`). If either is missing, wayvnc exits with
  "Failed to initialise wayland".
- **No X11 fallback** — this is a Wayland-only VNC server. For X11
  you need `x11vnc` / `Xvnc`.
- **No built-in display** — wayvnc is a *VNC server* that
  re-broadcasts an existing compositor's output. It does not run its
  own compositor and cannot create its own Wayland display from
  scratch.

### Headless mode (FAQ + manpage)

> "The Wayland session may be a headless one, so it is also possible
> to run wayvnc without a physical display attached."

Headless mode is achieved by **launching the compositor with
`WLR_BACKENDS=headless` and `WLR_LIBINPUT_NO_DEVICES=1`** before
starting wayvnc. The compositor still runs and creates a virtual
output; wayvnc attaches to that virtual output via the Wayland
screencopy protocol. This is exactly the pattern used by
`tabasco0322/nixbix` (a headless `HyprlandVNC` session with
`hyprctl output create headless`).

For our use case (greetd Hyprland), we do **not** need headless mode
because the greeter Hyprland instance is already attached to a real
display — but the headless mode is the escape hatch if the user
ever wants to access the greeter over VNC from a remote machine
without a monitor connected to t14 at all.

### Systemd socket activation (wayvnc ≥ 0.9.0)

wayvnc has an "external listener fd" feature (`-x 3` flag) that
accepts a pre-opened file descriptor from systemd's socket
activation. This is **not** what we need here (we want wayvnc to
share a Hyprland session, not be a standalone listener), but it's
useful to know for the alternatives section.

### Can it run as a system (non-user) service?

**Yes, technically, but not without a Wayland session to attach to.**
wayvnc can run as any user — it only needs `WAYLAND_DISPLAY` and
`XDG_RUNTIME_DIR` pointing at a real compositor's socket. The
greeter user has both (`/run/user/<greeter-uid>` is created by
systemd-logind automatically since NixOS 21.11+). The challenge is
*whose session* it attaches to. Options:

| Approach | Service owner | Attach target | Feasible? |
|----------|---------------|---------------|-----------|
| A. Add `exec-once = wayvnc &` to greeter Hyprland config (Enzime pattern) | `greeter` (regreet's Hyprland) | greeter Hyprland | **Yes — best fit** |
| B. Run wayvnc as `greeter` user with `PassEnvironment=...` and an override systemd user service | `greeter` | greeter Hyprland | **Yes** — but you have to manage a separate systemd user instance for `greeter` (not standard; doesn't exist in t14 today) |
| C. Run wayvnc as `root` (systemd system service) and set `WAYLAND_DISPLAY=/run/user/<greeter-uid>/...` and `XDG_RUNTIME_DIR=/run/user/<greeter-uid>` | `root` | greeter Hyprland | **Hacky** — works but bypasses PAM per-user security model, exposes the auth socket to root |
| D. Separate wayvnc service that spawns its own headless Hyprland with `WLR_BACKENDS=headless` (tabasco0322 pattern) | `greeter` or `root` | its own headless Hyprland | **Yes** — but you get a second Hyprland instance just for the greeter, with no real benefit vs. attaching to the existing one |
| E. wayvnc in the post-login user session (current state) | `glats` | user Hyprland | **Already done** — does NOT cover the pre-login gap |

**Approach A is the standard, clean pattern** and is the one we
recommend.

## Web findings

### wayvnc upstream documentation (any1/wayvnc)

- **README.md** — explicitly says: "The Wayland session may be a
  headless one, so it is also possible to run wayvnc without a
  physical display attached." Confirms wlroots-only dependency
  (Gnome, KDE, Weston are not supported).
- **FAQ.md** — headless mode recipe: `WLR_BACKENDS=headless
  WLR_LIBINPUT_NO_DEVICES=1` set on the *compositor* (not on
  wayvnc). wayvnc needs `WAYLAND_DISPLAY=wayland-1` (older Sway) or
  whatever the compositor publishes.
- **wayvnc(1) manpage** — full list of options including
  `enable_pam`, `address`, `port`, `--render-cursor`,
  `--keyboard=<layout>`, `enable_auth`, `private_key_file`,
  `certificate_file` (for VeNCrypt + TLS).

### Working example: Enzime/dotfiles-nix (Sway + regreet + wayvnc)

Source:
[`github.com/Enzime/dotfiles-nix/blob/main/modules/greetd.nix`](https://github.com/Enzime/dotfiles-nix/blob/main/modules/greetd.nix).
This is the closest match to what we want — Sway as the greeter
compositor, regreet in the Sway session, wayvnc sharing the same
session. Full pattern:

```nix
services.greetd.settings.default_session.command =
  "${lib.getExe' pkgs.dbus "dbus-run-session"} ${lib.getExe pkgs.sway} --config ${pkgs.writeText "greetd-sway-config" ''
    exec "${lib.getExe pkgs.wayvnc} &"
    exec "${lib.getExe pkgs.regreet}; swaymsg exit"
    include /etc/sway/config.d/*
  ''}";

users.users.greeter.home = "/var/greeter";
users.users.greeter.createHome = true;

home-manager.users.greeter = {
  xdg.configFile."wayvnc/config".text = ''
    address=0.0.0.0
  '';
  home.stateVersion = "26.05";
};
```

The key insight: **wayvnc is `exec`'d from the sway config BEFORE
regreet.** This means wayvnc is a child of the sway process,
inheriting its `WAYLAND_DISPLAY` and `XDG_RUNTIME_DIR` automatically.
When regreet exits and sway exits, wayvnc also exits (so the VNC
session tears down cleanly at the moment the user successfully
authenticates and the user session is about to start). Note the `&`
at the end of the wayvnc exec — the `&` backgrounds it so sway
doesn't block on it. The semicolon on the regreet line keeps regreet
in the foreground so swaymsg exit runs after regreet returns.

**Adapting this to t14 (Hyprland instead of Sway):** the equivalent
Hyprland config (already generated by
omarchy-nix `system.nix:171-209` at `/etc/greetd/hyprland.conf`)
just needs an `exec-once = wayvnc 0.0.0.0 &` line before the
existing `exec-once = greetd-regreet-start` line. No new
compositor, no new Hyprland instance.

### Working example: tabasco0322/nixbix (Hyprland + initial_session + headless VNC)

Source:
[`github.com/tabasco0322/nixbix/blob/main/profiles/greetd.nix`](https://github.com/tabasco0322/nixbix/blob/main/profiles/greetd.nix).
This is more complex: it uses `services.greetd.initial_session` to
auto-login to a dedicated `HyprlandVNC` session that starts Hyprland
in headless mode (`hyprctl output create headless`), then
`default_session` shows the tuigreet text greeter. The headless
Hyprland is the VNC target; wayvnc is a separate HM user service
inside that session.

**For our case (regreet, not auto-login), the nixbix pattern is
overkill.** We want a graphical greeter (regreet) AND VNC; the
Enzime pattern handles that in a single Hyprland instance.

### Forum: Hyprland remote desktop with greetd + regreet (forum.hypr.land/t/270)

A user reports running exactly this setup:

> "I use greetd to start ReGreet within a Hyprland instance as a
> compositor ... I can just `exec-once` sunshine within this
> Hyprland instance (which means that I have two different
> configurations of sunshine, one for the greeter user and one for
> my regular user account)."

The same person notes:

> "The only issue I have with this setup is that it requires me to
> connect to the sunshine of my login manager, log in, disconnect
> from the login manager and then connect to the sunshine of the
> real Hyprland instance every time I restart my PC or log out of
> the Hyprland session (only while being connected remotely, of
> course)."

**This caveat applies to us too**: with the Enzime pattern, the
VNC session is bound to the greeter Hyprland instance. When the
user authenticates, the greeter instance exits, the wayvnc
process exits, and the VNC viewer gets disconnected. The user
will see a brief "connection closed" pop-up in their VNC client,
and must reconnect to the user-session wayvnc (which is on the
same port 5900 but is now backed by the user Hyprland). For
t14 this is mitigated by the fact that **the user-session wayvnc
is already on 0.0.0.0:5900** — Remmina auto-reconnects on the
next VNC handshake, and the disconnect window is ~1 second during
the Hyprland session switch. Practical UX is "click button, see
login screen, type password, watch VNC reconnect, see desktop."
This is the same UX as if you were sitting at the physical
console: log in, session switch happens, you're in.

### Other relevant docs

- **NixOS Wiki — Greetd**: confirms the basic regreet + Sway/Hyprland
  setup. Does not cover VNC at the greeter specifically.
- **wayvnc issue #357** (systemd socket activation): documents
  the `-x 3` external fd feature, which we don't need but which
  proves wayvnc has flexible socket-binding options for advanced
  setups.
- **schmonz/gatherd** (`docs/vnc.md`): a postmortem explicitly
  stating "Sway + greetd still has no clean way to share the
  greeter session over VNC and seamlessly continue into the user
  session — fundamental to ... run an SDDM-with-sway-as-greeter
  setup with its own wayvnc instance and accept the two-step
  handoff at login. Hasn't been necessary so far." This validates
  the disconnect-on-login caveat as a known limitation in the
  ecosystem, not a defect of our approach.

## GitHub findings

Searches: `greetd wayvnc` (207 hits, mostly incidental), `greetd
regreet wayvnc` (33 hits, mostly incidental), `services.greetd
programs.regreet enable` (351 hits, mostly regreet configs).

The two relevant hits for our use case:

1. **Enzime/dotfiles-nix** (Sway + regreet + wayvnc, see above) —
   exact pattern, working since 2024. URL:
   <https://github.com/Enzime/dotfiles-nix/blob/main/modules/greetd.nix>
2. **tabasco0322/nixbix** (Hyprland + initial_session + headless
   VNC, see above) — more complex, for auto-login use case. URL:
   <https://github.com/tabasco0322/nixbix/blob/main/profiles/greetd.nix>

Other hits were either:
- Just colocated package lists (greetd + wayvnc in `pacman.txt`
  or similar) — not configurations.
- Disambiguation noise (e.g. "greetd" as a person name, or
  `wayvnc.service` mentions unrelated to greetd).
- The NixOS module-list itself (`nixos/modules/module-list.nix`).
- A known-good config that uses greetd for one purpose and wayvnc
  for another (e.g. `gvolpe/nix-config` uses Hyprland +
  greetd-as-VNC, but wayvnc is not involved in the greeter).

**No production-grade Hyprland + regreet + wayvnc (pre-login VNC)
NixOS config was found.** The Enzime Sway + regreet + wayvnc config
is the closest precedent and translates 1:1 to Hyprland.

## NixOS option inventory

Confirmed via `nixos_nix` MCP `action=info`:

### `services.greetd` options

```
services.greetd.enable           : bool
services.greetd.package          : package (default pkgs.greetd)
services.greetd.restart          : bool (default true; disable when
                                   using initial_session autologin)
services.greetd.useTextGreeter   : bool (tui greeter hygiene — kernel
                                   console=quiet handling)
services.greetd.settings         : TOML value (greetd config.toml
                                   schema: {default_session, initial_session,
                                   terminal, ...})
```

Currently NOT set on t14 — t14's greetd config is owned by
`omarchy-nix` (it sets `services.greetd.settings.default_session`
via `mkForce` in `modules/nixos/system.nix:136-141`). This is
fine; we won't conflict with omarchy's `mkForce`.

### `programs.regreet` options

```
programs.regreet.enable          : bool
programs.regreet.package         : package
programs.regreet.settings        : TOML value (regreet config)
programs.regreet.cageArgs        : list of str (passed to cage, but
                                   overridden by omarchy Hyprland path)
programs.regreet.theme.{name,package}
programs.regreet.iconTheme.{name,package}
programs.regreet.font.{name,size,package}
programs.regreet.cursorTheme.{name,package}
programs.regreet.extraCss        : path or lines
```

Already set by omarchy-nix (`programs.regreet.enable = true`,
`settings = { GTK = { application_prefer_dark_theme = true; }; }`).
We don't need to add anything here for the VNC feature.

### `programs.wayvnc` options (NixOS upstream)

```
programs.wayvnc.enable           : bool
programs.wayvnc.package          : package
```

That's it. **The NixOS `programs.wayvnc` module is minimal**: it
adds the package and a `security.pam.services.wayvnc` entry
(`/etc/pam.d/wayvnc` with PAM auth enabled, used by the
`enable_pam=true` config). It does NOT generate
`~/.config/wayvnc/config`, does NOT create a systemd service, does
NOT manage `XDG_RUNTIME_DIR`. All of that is up to the consumer
module (which is why omarchy-nix's HM module exists).

### `services.wayvnc` (nix-community/home-manager)

```
services.wayvnc.enable           : bool
services.wayvnc.package          : package
services.wayvnc.autoStart        : bool (default false)
services.wayvnc.systemdTarget    : str (default
                                   config.wayland.systemd.target)
services.wayvnc.settings         : freeform (address, port, ...)
```

HM-only. This module would be the right place to declare the
*greeter's* wayvnc systemd user service — but the `greeter` user
is a system user, not a HM user, and creating a HM instance for
`greeter` would be a significant expansion of the
`home-manager.users` config surface. The
`xdg.configFile."wayvnc/config"` for the greeter user can be
deployed by an `environment.etc` entry at the system level (same
path, deployed for all users) or by a small `systemd.tmpfiles`
rule, since `~/.config/wayvnc/config` is the default path wayvnc
reads.

## Feasibility assessment

**Feasibility: HIGH.** The technical path is well-trodden, the
NixOS modules exist, the regreet-in-Hyprland pattern is already
proven in the wild, and the security model is identical to the
existing post-login wayvnc.

### Required architecture (Approach A — Enzime pattern, Hyprland flavor)

1. **Modify the greeter Hyprland config** to add an
   `exec-once = wayvnc 0.0.0.0 &` line **before** the existing
   `exec-once = greetd-regreet-start` line. The greeter Hyprland
   config is generated by omarchy-nix at
   `/etc/greetd/hyprland.conf` (file:
   `omarchy-nix/modules/nixos/system.nix:171-209`). Two ways to
   inject the line:
   - **Fork omarchy-nix's `system.nix`** and modify the
     `greetd-regreet-start` script to launch wayvnc before
     regreet. This is the cleanest approach but requires
     committing to the fork workflow. Given that the repo
     already owns `github.com/glats/omarchy-nix` (full push
     access per AGENTS.md), this is acceptable.
   - **Append a second `exec-once` via an `environment.etc`
     override.** Hyprland's `exec-once` is repeatable — multiple
     `exec-once = ...` lines in the same config all run. So an
     `environment.etc."greetd/hyprland.conf.d/10-wayvnc.conf"`
     drop-in that adds an extra `exec-once` line is feasible.
     Cleaner: use Hyprland's `source =` directive from the main
     config (already does this for monitor block) — but the main
     config doesn't `source=` anything; it would need a fork
     change.
   - **Tweak the omarchy-nix `omarchy.greeter` submodule** to
     accept an `execBeforeRegreet` attrset (e.g.
     `omarchy.greeter.preRegreetExec = [ "wayvnc 0.0.0.0 &" ];`).
     Most invasive but most reusable.
2. **Deploy a `wayvnc/config` for the `greeter` user.** Two
   options:
   - System-wide `environment.etc."wayvnc/config"` — read by
     all users. Risks: would also affect the user session
     (where we already have a per-user config from omarchy-nix).
     Probably not a problem in practice (the per-user config
     wins) but inelegant.
   - Per-user `xdg.configFile."wayvnc/config"` for the greeter
     home, deployed via `home-manager.users.greeter` or via
     `systemd.tmpfiles` + `/var/lib/greeter/.config/wayvnc/config`.
     The Enzime pattern uses `home-manager.users.greeter` for
     this. To avoid pulling in HM for a system user, a small
     `systemd.tmpfiles` rule is simpler.
3. **PAM auth for the greeter session.** The
   `security.pam.services.wayvnc` PAM service is already
   provided by `programs.wayvnc.enable = true` (NixOS upstream
   module, see source at
   `/nix/store/.../nixos/modules/programs/wayland/wayvnc.nix:21`).
   So `enable_pam=true` in the greeter's wayvnc config will
   authenticate against the same PAM stack as the user session.
   **The greeter's PAM auth means: anyone with any glats user
   password (or any local account) can unlock the VNC login
   screen.** This is the same threat model as the existing
   post-login wayvnc, but with one important difference: at the
   greeter, there is no logged-in user yet, so the VNC client
   has free access to enter *any* username and *any* password.
   The user-session wayvnc limits authentication to the
   currently-logged-in user's password.

### Security considerations

| Concern | Current state (user session) | With greetd wayvnc (Approach A) | Mitigation |
|---------|------------------------------|----------------------------------|------------|
| **Auth scope** | `enable_pam=true` validates against any glats password (per `security.pam.services.wayvnc`). The wayvnc PAM service does NOT restrict to "the user currently logged in to this Wayland session" — it just checks `/etc/shadow` or PAM. | Same auth, but reachable pre-login — anyone on the network can attempt any glats password at the regreet screen. | Trust-LAN assumption (already in t14: `firewall.enable = false`, comment in `hosts/t14/default.nix:65-68` says "Defense-in-depth: keep host firewall off"). For untrusted networks, recommend SSH tunnel or Tailscale. |
| **Network exposure** | `0.0.0.0:5900` + firewall off. | Same — same port, same binding. No new attack surface. | Already mitigated by the trusted-LAN / Tailscale model. |
| **Auth brute force** | wayvnc does not implement rate limiting. PAM does not enforce per-IP limits by default (without `pam_faillock` configured). | Same. | Optional: enable `services.fail2ban` with a wayvnc filter, or use Tailscale ACLs to restrict the source IP. |
| **VNC encryption** | `enable_pam=true` enables VeNCrypt (TLS). Password is sent over TLS, not in cleartext. | Same. | Document the requirement: clients must support VeNCrypt (TigerVNC yes, macOS Screen Sharing no). Already documented in `omarchy-nix/modules/home-manager/wayvnc.nix:8`. |
| **greeter user password** | n/a | The greeter is a system user with no password. The PAM auth will fall through to `/etc/shadow` — wayvnc auth will validate against any local account with a real password. To prevent an attacker from authenticating as `greeter` (which has no password and would fail cleanly), the PAM service must reject empty/null passwords. The default `security.pam.services.wayvnc` does NOT include `pam_unix` with `nullok` — it uses the default PAM auth stack, which respects `nullok` from `/etc/pam.d/login` if linked. **Verification needed** during proposal phase. | During proposal: read `/etc/pam.d/wayvnc` after rebuild, ensure no `nullok` line, document. |
| **Handoff race** | n/a | When regreet returns (user authenticated), greeter Hyprland exits, wayvnc process is killed, VNC client disconnects. The user-session wayvnc on the same port is starting up. The window is ~1 second. | Acceptable. Document the disconnect behavior so user knows. |
| **Lock screen** | wayvnc shows Hyprland desktop (with hyprlock as overlay if locked). | Same — lockscreen VNC continues working (greeter wayvnc only runs at the regreet screen, not at hyprlock). | No new exposure. |

### Known NixOS patterns

The closest pattern is Enzime's Sway + regreet + wayvnc config (see
Web findings). Adapting to Hyprland means changing `sway` to
`Hyprland` and the config DSL from Sway `exec` lines to Hyprland
`exec-once` lines.

**Idiomatic placement in this repo:**
- If changing the greeter config in `omarchy-nix`: edit
  `omarchy-nix/modules/nixos/system.nix` (the `greetd-regreet-start`
  script + the `environment.etc."greetd/hyprland.conf"` builder).
  Push to `github:glats/omarchy-nix/main`. This is the existing
  workflow (`greeter-monitor-select` change is doing exactly this).
- If adding a per-greeter wayvnc config: add a small NixOS module in
  `modules/features/wayvnc-greeter.nix` (or fold into an existing
  file) imported by `hosts/t14/default.nix`. Use
  `environment.etc."wayvnc-greeter.conf".text` + a
  `systemd.tmpfiles` rule to deploy it to
  `/var/lib/greeter/.config/wayvnc/config`, **or** use
  `home-manager.users.greeter` if HM is the chosen deployment
  surface. The HM route is cleaner but expands the HM surface
  (one more user to manage). The `systemd.tmpfiles` route is
  ~5 lines and requires no HM change.

### Affected areas (proposal)

- `omarchy-nix/modules/nixos/system.nix` — modify
  `greetd-regreet-start` script (add `wayvnc 0.0.0.0 &` before
  `${pkgs.regreet}/bin/regreet`) **OR** add a new submodule option
  `omarchy.greeter.preRegreetExec` to the `omarchy` config block.
- `hosts/t14/default.nix` — opt in to the new option (e.g.
  `omarchy.greeter.preRegreetExec = [ "wayvnc 0.0.0.0 &" ];`).
- New `modules/features/wayvnc-greeter.nix` (or inline in
  `hosts/t14/default.nix`) — deploy a `wayvnc/config` for the
  greeter user, gated on a new `my.wayvncGreeter.enable` option or
  on the existing `omarchy.greeter.type == "regreet"`.
- `flake.nix` standalone-HM block (line 273) — no change needed;
  the change is NixOS-side, not HM-side.

### Open questions for proposal phase

1. **Same port or different port?** The user-session wayvnc is on
   0.0.0.0:5900. Using the same port for the greeter wayvnc means
   the user VNC client sees a "connection lost" pop-up at login
   (because the listener process restarts). Using a different
   port (e.g. 5901) means the user must remember which port is
   which. Recommend **same port** — the reconnect is automatic
   and the UX is cleaner.
2. **Greeter wayvnc config — where to source the address?** If
   `0.0.0.0`, the security model matches the user-session wayvnc
   (LAN-only). If `127.0.0.1`, the user must SSH-tunnel to access
   the greeter (defeats the purpose if the user is remote). If
   there's a Tailscale interface IP, that's another option. **Default
   to `0.0.0.0`** for consistency with user-session.
3. **PAM auth for greeter — explicit per-host opt-in or always on?**
   Recommend **always on** (matches the `enable_pam=true` default
   in omarchy's wayvnc HM module) but expose
   `omarchy.greeter.wayvnc.enablePam` as an option for hosts that
   want to disable.
4. **Should the pre-login wayvnc be its own `omarchy.greeter.wayvnc`
   submodule (port, address, enablePam, command-line flags), or a
   minimal `omarchy.greeter.preRegreetExec` list of arbitrary
   shell commands?** A submodule is more discoverable and
   self-documenting; a freeform list is more flexible (can launch
   other daemons like `tmux new-session` for log access, or
   `sunshine` instead of wayvnc). **Recommend a focused
   `omarchy.greeter.wayvnc` submodule** — `wayvnc` is a known,
   specific use case and a freeform list invites cargo-culting.
5. **Should this be t14-only, or general for any host that uses
   greetd + regreet?** Recommend **t14-only initially** (single
   consumer, can generalize later if rog/thinkcentre ever
   migrate to greetd). The omarchy submodule is reusable; the
   `hosts/t14/default.nix` opt-in is the gating point.
6. **Escape hatch for the regreet startup race.** The current
   `greetd-regreet-start` script does the eDP-1 disable
   **before** regreet launches (then calls `hyprctl dispatch
   exit` after regreet returns). Inserting `wayvnc &` between
   those is safe because wayvnc doesn't interact with
   monitor state. But if wayvnc fails to start (e.g. port
   already bound — but only the user-session wayvnc would
   be on 5900, and that doesn't exist pre-login), the
   regreet startup doesn't fail. **Safe to add without
   additional error handling.**

## Risks

- **Catastrophic**: none. The change is additive. If wayvnc
  fails to start, regreet still launches normally and the
  user can log in at the physical console.
- **Operational**: the VNC port becomes reachable **earlier**
  in the boot sequence (right after greetd starts, instead
  of after the user logs in). On t14 with firewall off, this
  is a ~10-second wider window. Trust-LAN model already
  accepts this.
- **User confusion**: the VNC client may pop up a "connection
  closed" dialog at login (because the greeter Hyprland exits
  and the user Hyprland takes ~1s to start wayvnc). Document
  this so the user knows it's expected.
- **omarchy-nix coupling**: the change lives in
  `omarchy-nix/modules/nixos/system.nix`, not in
  `nixos-hosts`. If the user wants to upstream the change to
  the upstream `mrosseel/omarchy-nix`, it becomes a PR
  dependency. If they keep it in the fork, it survives
  upstream rebases because the fork is fast-forwarded
  (per the AGENTS.md note "fork tracks mrosseel/omarchy-nix,
  rebase-only").
- **Disabling the wayvnc in the greeter** if the security
  model ever changes: a kernel command-line parameter
  `systemd.mask=greetd.service` already exists as an escape
  hatch (per the comment in `omarchy-nix/modules/nixos/system.nix:104-108`).
  The wayvnc change does not affect that.

## Recommended approach

**Go with Approach A (Enzime pattern, Hyprland flavor), implemented
in two steps:**

### Step 1 — omarchy-nix: add `omarchy.greeter.wayvnc` submodule

In `/home/glats/repos/omarchy-nix/`:

1. **`config.nix`** (around the existing `greeter` submodule at
   line 284): add a new submodule inside `greeter`:
   ```nix
   wayvnc = lib.mkOption {
     type = lib.types.submodule {
       options = {
         enable = lib.mkEnableOption "run wayvnc inside the greeter Hyprland session";
         address = lib.mkOption { type = lib.types.str; default = "0.0.0.0"; };
         port   = lib.mkOption { type = lib.types.port; default = 5900; };
         enablePam = lib.mkOption { type = lib.types.bool; default = true; };
         extraArgs = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; };
       };
     };
     default = { };
     description = "wayvnc configuration for the greeter login screen";
   };
   ```
2. **`modules/nixos/system.nix`**: in the
   `environment.etc."greetd/hyprland.conf"` builder (line
   171-209), prepend an `exec-once` line to the existing
   `exec-once = ${greeterScript}`:
   ```nix
   wayvncExec = lib.optionalString cfg.greeter.wayvnc.enable
     "exec-once = ${pkgs.wayvnc}/bin/wayvnc ${lib.escapeShellArgs ([
       cfg.greeter.wayvnc.address
       (toString cfg.greeter.wayvnc.port)
     ] ++ cfg.greeter.wayvnc.extraArgs)} &\n";
   ```
   And concatenate `wayvncExec` before the existing `exec-once`
   line. This puts wayvnc ahead of regreet in the same Hyprland
   instance.
3. **Deploy the per-greeter wayvnc config** via a `systemd.tmpfiles`
   rule that creates `/var/lib/greeter/.config/wayvnc/config` at
   boot with the matching `address`, `port`, `enable_pam` (or via
   a small `xdg.configFile` if a HM user for `greeter` is
   preferred).

### Step 2 — nixos-hosts: opt in on t14

In `hosts/t14/default.nix`, inside the `omarchy = { ... }` block
next to the existing `greeter = { ... }` (around line 180):

```nix
omarchy.greeter.wayvnc = {
  enable   = true;
  address  = "0.0.0.0";     # same as user-session wayvnc (LAN-only)
  port     = 5900;          # same port — auto-reconnect on session switch
  enablePam = true;         # VeNCrypt + PAM, matches user-session
};
```

If the user wants a different port for the greeter (to avoid the
1-second disconnect blip), set `port = 5901` and add a second
`vnc-t14-greeter.remmina` profile to `home-linux/remote-desktop.nix`.

### Step 3 — verify

`nix flake check --no-build` to confirm all hosts evaluate, then
`nixos-build build` on t14 to confirm the resulting
`/etc/greetd/hyprland.conf` contains the `exec-once = ... wayvnc
&` line **before** the `exec-once = ... greetd-regreet-start`
line. Manual: reboot t14, attempt VNC connect on port 5900
**before** logging in (should show regreet), enter password (VNC
disconnects briefly), reconnect (should show user Hyprland
desktop).

### Effort: **Low**. ~30 lines of Nix in omarchy-nix + ~5 lines
of opt-in in `hosts/t14/default.nix`. No new package, no new
service manager, no new kernel module, no new dependency.

## Alternatives considered

1. **Use `services.xserver.displayManager.lightdm` with
   `lightdm-gtk-greeter` instead of greetd+regreet.** Rejected:
   massive migration (rog/thinkcentre/MATE → lightdm is a
   separate decision and out of scope). greetd is already wired
   on t14.
2. **Use `sunshine` instead of wayvnc.** Rejected: sunshine is
   for game streaming (low-latency, GPU-encoded). wayvnc is
   purpose-built for desktop VNC. The forum.hypr.land user
   quoted above uses sunshine, but that's their personal
   preference; for a single-stream VNC-on-login-screen use
   case, wayvnc is the canonical tool.
3. **Run wayvnc in the user systemd manager with
   `WantedBy=greeter-session.target`** (systemd's name for the
   greetd-launched user session). Rejected: this target name
   doesn't exist in t14's greeter setup (greetd just runs the
   Hyprland process directly as the `greeter` user; no systemd
   user instance is spawned for the greeter). Enzime's
   `exec`-from-sway-config pattern is the equivalent and
   simpler.
4. **Use `xdg-desktop-portal` + `pipewire` + `gnome-remote-desktop`.**
   Rejected: requires gnome-remote-desktop, not compatible with
   the Hyprland-only environment.
5. **Run wayvnc as a `root` system service pointing at the
   greeter's Wayland socket via
   `WAYLAND_DISPLAY=/run/user/<greeter-uid>/...`.** Rejected:
   requires hardcoding the greeter UID, bypasses the PAM
   per-user security model, and creates a confusing service
   topology. Approach A is simpler and more correct.

## Ready for proposal

**Yes.** The technical path is clear, the security model is
documented, the affected files are listed, and the open questions
are scoped. The user (orchestrator) can propose:

- The omarchy-nix submodule change (the reusable, upstream-able
  part).
- The t14 opt-in (the host-specific part).
- A verification step (`nix flake check --no-build` +
  `nixos-build build` + manual VNC-from-cold-boot).

Proposal is single-track (no chained PRs needed — total diff is
~35 lines across 2-3 files). The omarchy-nix change can be a
separate commit from the nixos-hosts opt-in (commit 1: upstream
the submodule, commit 2: enable on t14) so either can be reverted
independently.
