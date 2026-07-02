# Exploration: wayvnc remote desktop — verify & fix after migration

## Current State

wayvnc is the VNC server on **t14** (Hyprland/Omarchy). It captures the
Wayland screen via the wlroots screencopy protocol and serves it over
VNC/VeNCrypt+PAM. The repo previously had a hand-rolled `hosts/t14/home/wayvnc/`
module, a `connect-wayvnc-t14` shell script on the client, and a separate
`gen-remmina-desktops.sh` helper. After the migration to the upstream
`omarchy-nix` module, **all three of those local implementations were removed
and replaced with upstream modules**. The server side is now supplied by
`omarchy-nix`; the client side is supplied by `home-linux/remote-desktop.nix`
(Remmina profiles + .desktop launchers).

### Flow (current)

1. **t14 (server)** — `omarchy.wayvnc.enable = true` is set in
   `hosts/t14/default.nix` (line 176) and in the standalone HM config in
   `flake.nix` (line 273). The upstream module chain is:
   - `omarchy-nix:modules/nixos/wayvnc.nix` → `programs.wayvnc.enable = true`
     and `pkgs.wayvnc` to `environment.systemPackages`.
   - `omarchy-nix:modules/home-manager/wayvnc.nix` →
     `xdg.configFile."wayvnc/config"` and a `systemd.user.services.wayvnc`
     service that runs under `graphical-session.target`.
2. **rog (client)** — `home-linux/remote-desktop.nix` (304 lines) is imported
   by `hosts/rog/home/modules.nix` (line 8), which is the per-host module
   list consumed by `modules/base/home-manager.nix`. It deploys:
   - `~/.local/share/remmina/vnc-t14.remmina` (server = `172.16.0.109:5900`)
   - `~/.local/share/applications/remote-t14.desktop` (calls
     `remmina -c ~/.local/share/remmina/vnc-t14.remmina`)
   - `remmina` and `libsecret` in `home.packages`.
3. **PATH** — `home.sessionPath = [ "$HOME/.local/bin" ]` is set in
   `home-linux/base.nix:16` (covers rog + thinkcentre via
   `home-linux/shared-modules.nix`) and in `home-darwin/default.nix:38`
   (covers mact2). t14 inherits it transitively because
   `hosts/t14/home/omarchy.nix:62` imports `home-linux/base.nix`. There is
   **no separate `connect-wayvnc-t14` script** in `~/.local/bin/` — the
   client is launched via the .desktop file (app menu) or directly via
   `remmina -c ~/.local/share/remmina/vnc-t14.remmina`.

## Affected Areas

- `home-linux/remote-desktop.nix` — current canonical client module. Contains
  the `vnc-t14.remmina` profile and `remote-t14.desktop` launcher. **No
  changes needed for the migration to "work"**; only doc/comment cleanup may
  be wanted.
- `home-linux/base.nix` (line 14 comment) — references
  `connect-wayvnc-t14, openfang-start, gen-remmina-desktops.sh` as examples
  of scripts that resolve via `$HOME/.local/bin`. **Two of the three no
  longer exist** (`connect-wayvnc-t14` and `gen-remmina-desktops.sh` were
  deleted in commit `57fcf27`). The comment is stale.
- `hosts/rog/home/modules.nix:8` — imports `home-linux/remote-desktop.nix`
  for rog. Correct and current.
- `hosts/thinkcentre/home/modules.nix:8` — same, for thinkcentre.
- `hosts/t14/home/omarchy.nix:78` — same, for t14. (t14 is also the server,
  but the client profile is harmless on the server host and Remmina is
  useful there for connecting outbound to mact2/etc.)
- `flake.nix:273` — standalone-HM `wayvnc.enable = true` in the t14
  `homeConfigurations` block. This is required for `hms` / standalone HM
  builds to enable the wayvnc user service (NixOS path provides it via
  osConfig, standalone HM does not).
- `omarchy-nix` (upstream) — not edited by this repo. The omarchy-nix
  local clone lives at `/home/glats/repos/omarchy-nix/` and is pinned via
  `flake.nix:20` (`github:glats/omarchy-nix/main`).

## What changed during the migration (git archaeology)

| Commit | Date | Effect |
| --- | --- | --- |
| `9795d10` | 2026-06-18 | First attempt: local `hosts/t14/home/wayvnc.nix` + import in `home/default.nix`. |
| `f3e1bfd` | 2026-06-18 | Refactored local module into `hosts/t14/home/wayvnc/{default.nix,config}` + autostart line. |
| `74f03c5` | 2026-06-18 | Added `home.sessionPath = [ "$HOME/.local/bin" ]` to `home-linux/base.nix`; comment example mentions `connect-wayvnc-t14` (later deleted). |
| `60f450c` | 2026-06-18 | Renamed `home-linux/vnc-clients.nix` → `wayvnc-client.nix` (only .desktop launcher — no `~/.local/bin` script). Removed vnc-clients.nix and its import. |
| `57fcf27` | 2026-06-18 | **Deleted** `home-linux/wayvnc-client.nix` and `hosts/t14/home/remmina.nix` (the local 53-line t14 client + `gen-remmina-desktops.sh` helper). **Created** `home-linux/remote-desktop.nix` (82 lines added, became canonical). |
| `4e9c3dd` | 2026-06-27 | **Refactor**: Bumped omarchy-nix to commit `876137e` (added `omarchy.wayvnc` option block + osConfig lazy-eval fix). Replaced the local `hosts/t14/home/wayvnc/default.nix` module and `programs.wayvnc.enable = true` in `hosts/t14/default.nix` with `omarchy.wayvnc.enable = true`. Dropped the osConfig workaround in `flake.nix` (`_module.args.osConfig = mkForce { omarchy = {}; … }`). |

### Why `connect-wayvnc-t14` is gone

`vnc-clients.nix` originally deployed a `~/.local/bin/connect-wayvnc-t14`
shell script that ran `remmina -c vnc://172.16.0.109:5900`. In commit
`60f450c` it was replaced with `wayvnc-client.nix` (only a .desktop file —
no shell script). In commit `57fcf27` the .desktop file was deleted too
and replaced with the much richer `home-linux/remote-desktop.nix`, which
generates a .remmina profile + .desktop launcher per host and is shared
across rog, thinkcentre, and t14. The `connect-wayvnc-t14` shell-script
ergonomic is therefore gone — the user launches the connection via the
app menu (`remote-t14.desktop`) or by name (`remmina -c vnc-t14.remmina`).

## Approaches

1. **Do nothing — confirm working as-is.**
   - Pros: zero risk, zero churn. Server is upstream, client is shared
     Remmina module, PATH is correct.
   - Cons: stale comment in `home-linux/base.nix:14` mentioning
     `connect-wayvnc-t14` and `gen-remmina-desktops.sh` is misleading. If
     the user types `connect-wayvnc-t14` from a shell they get
     "command not found".
   - Effort: **None** (just verify with `nix flake check --no-build` +
     `nixos-build build` on rog).

2. **Restore `connect-wayvnc-t14` as a 5-line shell script in
   `home-linux/remote-desktop.nix`** (or a new tiny `wayvnc-t14-launcher.nix`).
   - Pros: matches the user's mental model from the previous setup, fixes
     the stale comment example, and the script is a one-liner around the
     existing `vnc-t14.remmina` profile.
   - Cons: small bit of churn for cosmetic / ergonomic benefit; the .desktop
     launcher already provides GUI access.
   - Effort: **Low** (single home.file addition).

3. **Update the stale comment in `home-linux/base.nix:14`** to mention
   only scripts that actually exist (e.g. `openfang-start`).
   - Pros: documentation accurate; no functional change.
   - Cons: still doesn't address the "type `connect-wayvnc-t14`" gap.
   - Effort: **Trivial**.

## Recommendation

**Approach 1 (verify) + Approach 3 (fix the stale comment).** The
implementation is **already correct** — the omarchy-nix wayvnc module
replaced the hand-rolled server, and `home-linux/remote-desktop.nix`
provides the client. The only defect is a stale code comment.

If the user wants the `connect-wayvnc-t14` shell command back for
keyboard-driven access (avoids having to open the app menu), add it as
part of `home-linux/remote-desktop.nix` — this is **Approach 2** and is
the only optional functional change. Decision belongs to the user.

## Risks

- **None functional** for the current state. Server is upstream
  (maintained by `omarchy-nix`); client is shared across all Linux hosts
  via the import list; PATH is set on every relevant config.
- The `home-linux/base.nix:14` comment is **stale documentation**, not a
  bug. A new contributor reading the file may be confused.
- If the user types `connect-wayvnc-t14` expecting the old shell script,
  the shell will return "command not found". This is a UX regression vs.
  the pre-`57fcf27` setup but is not a blocker (the .desktop launcher
  does the same job).
- omarchy-nix is pinned to `github:glats/omarchy-nix/main` (a branch ref,
  not a commit). A future upstream change to the wayvnc module
  (modules/home-manager/wayvnc.nix) could affect the deployed service
  behavior. Low risk for this change because the module is small and the
  interface (`omarchy.wayvnc.{enable,port,enable_pam}`) is stable.

## Server side — full module analysis (omarchy-nix)

### Option block (`omarchy-nix/config.nix:528-550`)

```nix
wayvnc = lib.mkOption {
  type = lib.types.submodule {
    options = {
      enable      = mkOption { type = bool; default = false; … };
      port        = mkOption { type = port;  default = 5900; … };
      enable_pam  = mkOption { type = bool; default = true;  … };
    };
  };
  default = { };
};
```

### NixOS module (`omarchy-nix/modules/nixos/wayvnc.nix`, 17 lines)

When `omarchy.wayvnc.enable = true`:
- `programs.wayvnc.enable = true` (NixOS upstream module).
- `environment.systemPackages = [ pkgs.wayvnc ]`.
- Loaded by `omarchy-nix/modules/nixos/default.nix:26`.

### Home Manager module (`omarchy-nix/modules/home-manager/wayvnc.nix`, 60 lines)

When `omarchy.wayvnc.enable = true`:
- `xdg.configFile."wayvnc/config".text`:
  ```
  use_relative_paths=true
  address=0.0.0.0
  port=${port}                # default 5900
  enable_pam=${boolToString}  # default true
  ```
- `systemd.user.services.wayvnc`:
  - `Type = simple`
  - `After = [ "graphical-session.target" ]`
  - `PartOf = [ "graphical-session.target" ]`
  - `PassEnvironment = [ "WAYLAND_DISPLAY" "XDG_RUNTIME_DIR" "DISPLAY" ]`
  - `ExecStartPre = "bash -c 'pkill wayvnc 2>/dev/null || true'"` (kills
    any prior wayvnc)
  - `ExecStart = "${pkgs.wayvnc}/bin/wayvnc"`
  - `Restart = on-failure`, `RestartSec = 5`
  - `WantedBy = [ "graphical-session.target" ]`
- Loaded by `omarchy-nix/modules/home-manager/default.nix:88`.

### Address binding

`address=0.0.0.0` — binds all interfaces. Combined with
`networking.firewall.enable = false` in `hosts/t14/default.nix:68` and
`omarchy.firewall.enable = false` in the `omarchy = { … }` block
(`hosts/t14/default.nix:170`), VNC is reachable from any host on the LAN.
**Anyone on the LAN can attempt to authenticate with any glats unix
password** — the threat model is "trusted LAN only" and the host firewall
being off is explicit per the comments in the file.

### t14 host wiring

- `hosts/t14/default.nix:176` — `omarchy.wayvnc.enable = true;` inside
  the `omarchy = { … }` block. Also sets the canonical defaults (port
  5900, enable_pam true) — they're the upstream defaults but are
  documented inline for clarity.
- `flake.nix:273` — same value in the standalone HM `homeConfigurations.t14`
  block, so `hms` builds evaluate the wayvnc HM module.
- `flake.nix:219-223` — `extraModules = [ inputs.omarchy-nix.nixosModules.default
  inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t14-amd-gen4 ]` wires
  the omarchy-nix NixOS module (which contains the wayvnc NixOS module).

## Client side — current canonical module

### `home-linux/remote-desktop.nix` (304 lines, 1 import path)

- **System-level package**: `remmina` is in
  `modules/base/profiles/core.nix:85` (system-wide, all hosts that import
  the profile — rog, thinkcentre, t14).
- **Home packages** (lines 216-219): `pkgs.remmina`, `pkgs.libsecret`.
  Libsecret is required for the glibsecret plugin to persist
  credentials in the user's default keyring.
- **Global prefs** (lines 183-205): `xdg.configFile."remmina/remmina.pref"`
  with `force = true` — sets view modes, scale quality, default action,
  resolution list, and the `[remmina]` defaults (name=, ignore-tls-errors=1).
- **Per-host .remmina profiles** (lines 222-260):
  - `rdp-rog.remmina` (server 172.16.0.5)
  - `rdp-oneplus5.remmina` (server 172.16.0.12, colordepth 66)
  - `rdp-thinkcentre.remmina` (server 172.16.0.11)
  - `vnc-t14.remmina` (server `172.16.0.109:5900`, protocol VNC)
  - `vnc-mact2.remmina` (server `mact2.local`)
- **Per-host .desktop launchers** (lines 263-302):
  - `remote-rog.desktop`, `remote-oneplus5.desktop`,
    `remote-thinkcentre.desktop`, `remote-t14.desktop`,
    `remote-mact2.desktop`.
  - All call `remmina -c /home/glats/.local/share/remmina/<profile>`.
  - `TryExec = ${pkgs.remmina}/bin/remmina` (so the launcher disappears
    from the menu if remmina is not installed).
- **RDP defaults** (lines 119-127): protocol=RDP, colordepth=99,
  sound=local, audio-output=sys:pulse, username=glats, drive=/home/glats,
  quality=0. Merged on top of `commonDefaults`.
- **VNC defaults** (lines 130-145): protocol=VNC, no sound/drive/username,
  showcursor=0, disableencryption=0, disableserverbell=0,
  disableserverinput=0, tightencoding=0. Merged on top of `commonDefaults`.
- **commonDefaults** (lines 22-116): ~95 Remmina settings with
  sensible values (scale=2, viewmode=1, window_maximize=1, etc.).
- **MkRemminaProfile / MkDesktop** helpers (lines 148-174): convert the
  Nix attrset into a `.remmina` ini file or a `.desktop` entry text.

### Where the client module is imported

- `hosts/rog/home/modules.nix:8` — `../../../home-linux/remote-desktop.nix`
- `hosts/thinkcentre/home/modules.nix:8` — same.
- `hosts/t14/home/omarchy.nix:78` — same (t14 has its own curated import
  list because it does not use `home-linux/shared-modules.nix`; the
  import is intentional and has an inline comment explaining why).
- `home-linux/shared-modules.nix` does **not** import
  `remote-desktop.nix`. The three `home/modules.nix` files (rog,
  thinkcentre) and the t14 `omarchy.nix` import it directly instead. This
  is consistent with the AGENTS.md rule that host-conditional modules
  are appended per host (remote-desktop is *host-conditional* in the sense
  that not every future Linux host will want it).

## PATH state

| File | Line | Value |
| --- | --- | --- |
| `home-linux/base.nix` | 16 | `home.sessionPath = [ "$HOME/.local/bin" ];` |
| `home-darwin/default.nix` | 38 | `home.sessionPath = [ "$HOME/.local/bin" ];` |

- t14 inherits via `hosts/t14/home/omarchy.nix:62`
  (`../../../home-linux/base.nix`).
- Rog/thinkcentre inherit via `home-linux/shared-modules.nix:15`
  (`./base.nix`).
- **No other `home.sessionPath` settings** in the repo
  (verified by `grep -r "sessionPath" /home/glats/.nixos` — 3 matches,
  all 3 are the line above plus a comment reference).
- The line 14 comment in `home-linux/base.nix` lists
  `connect-wayvnc-t14, openfang-start, gen-remmina-desktops.sh` as
  examples. Only `openfang-start` still exists
  (`home-linux/openfang.nix:100`); the other two were deleted in
  commit `57fcf27`.

## Git history (last ~20 commits touching wayvnc/VNC files)

```
4e9c3dd refactor(t14): use upstream omarchy.wayvnc module, drop osConfig workaround
4e9c3dd (also) bump omarchy-nix 876137e, delete hosts/t14/home/wayvnc/default.nix
57fcf27 work  (created home-linux/remote-desktop.nix, deleted wayvnc-client.nix + hosts/t14/home/remmina.nix)
60f450c work  (renamed vnc-clients.nix -> wayvnc-client.nix, removed import)
74f03c5 work  (added home.sessionPath to home-linux/base.nix with connect-wayvnc-t14 example)
f3e1bfd wayvnc  (added hosts/t14/home/wayvnc/{default.nix,config} + autostart)
9795d10 wayvnc  (initial hosts/t14/home/wayvnc.nix + import)
```

The relevant migration timeline is therefore:
- **2026-06-18**: Hand-rolled wayvnc server + Remmina client created and
  iterated. `connect-wayvnc-t14` shell script existed for ~2 hours before
  being deleted in favor of a unified `remote-desktop.nix`.
- **2026-06-27**: Hand-rolled server replaced by upstream
  `omarchy.wayvnc` module (commit `4e9c3dd`).
- **2026-06-28 → present**: T14 Hyprland / monitor / screensaver fixes
  are the only t14-related commits since.

## Ready for Proposal

**Yes.** Recommendation is straightforward:
- Confirm `nix flake check --no-build` passes for all 3 hosts.
- Confirm `nixos-build build` for rog deploys the
  `~/.local/share/remmina/vnc-t14.remmina` and
  `~/.local/share/applications/remote-t14.desktop` files.
- Optional: update the stale comment in `home-linux/base.nix:14`.
- Optional: add a `connect-wayvnc-t14` shell-script launcher in
  `home-linux/remote-desktop.nix` if the user wants shell access back
  (small, low-risk).

If Approach 2 (restore the shell script) is taken, the proposal can be a
single-task change. If only verification is needed, this is a no-code
change and the orchestrator can skip directly to verification.
