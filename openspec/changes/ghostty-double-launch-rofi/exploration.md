# Exploration: ghostty abre dos veces cuando uso rofi en rog

> Change: `ghostty-double-launch-rofi`
> Host reported: rog (untested on thinkcentre)
> Investigation date: 2026-06-28
> Local environment: rofi 2.0.0, ghostty 1.3.1, MATE via XRDP, NixOS 26.11

## TL;DR — Root cause

**Ghostty's desktop file declares `DBusActivatable=true`.** When rofi
launches it via drun, rofi tries to send a D-Bus `Open` method with a
~1.5 s timeout. If ghostty is slow to register its D-Bus interface
(common on rog: nvidia GPU, conky running, many background services),
the timeout fires and rofi falls back to spawning the `Exec` line
directly. Because the desktop file still advertises
`DBusActivatable=true`, **the direct spawn re-triggers D-Bus
activation** — and the original D-Bus call that "timed out" is also
still in flight. The result: two ghostty processes, two Ghostty
windows.

The MATE log (`~/.local/state/xrdp-mate.log`) on the live rog host
shows the exact pattern repeated 16 times. Two of those incidents
spawned **two** ghostty instances (e.g. process 212812 at 23:28:29,
process 575453 spawned **three**). The MATE window manager also
records two distinct XIDs per launch event:
`for 0x3e00005 (Ghostty)` + `for 0x3e00015 (Ghostty)`.

The rofi maintainer (DaveDavenport) explicitly recommends disabling
`DBusActivatable` for slow apps. See GitHub issues
[davatorium/rofi#2077](https://github.com/davatorium/rofi/issues/2077)
and discussion
[#2138](https://github.com/davatorium/rofi/discussions/2138).

## Current State

### Host stack on rog

- **Desktop**: MATE via xrdp (`my.desktop.suite = "mate"`,
  `hosts/rog/default.nix:74`)
- **DM/wm**: MATE marco (xorg)
- **Launcher keybind** (`home-linux/mate.nix:117-123`):
  ```
  "org/mate/marco/global-keybindings" = {
    run-command-1 = "<Control>space";
  };
  "org/mate/marco/keybinding-commands" = {
    command-1 = "${pkgs.rofi}/bin/rofi -show drun";
  };
  ```
- **Rofi version on rog**: 2.0.0 (binary from
  `pkgs/rofi-unwrapped-2.0.0`)
- **Ghostty version on rog**: 1.3.1
- **Per-user rofi config** (`~/.config/rofi/config.rasi` → symlink to
  `home-manager-files`): drun-only, ulauncher-like theme, full
  contents reproduced below.
- **Rofi ghostty cache hit weight**: 24 (most recent
  `/home/glats/.cache/rofi3.druncache`).

### Home Manager modules loaded on rog

`flake.nix:239-242` — extra modules for rog:

```nix
rog = baseHomeConfig "rog" "x86_64-linux" "glats" [
  ./home-linux/conky-rog.nix
  ./home-linux/openfang.nix
];
```

`hosts/rog/home/modules.nix:1-14` — NixOS-integrated HM extra modules:

```nix
baseModules ++ [
  ../../../home-linux/remote-desktop.nix
  ../../../home-linux/picom.nix
  ../../../home-linux/mate-rog-autostart.nix   # UNIQUE TO ROG
  ../../../home-linux/conky-rog.nix
  ../../../home-linux/openfang.nix
  ../../../home-linux/webcam-rog.nix
]
```

**Key delta vs thinkcentre**: `mate-rog-autostart.nix` (only adds a
HexChat `~/.config/autostart/io.github.Hexchat.desktop`). No
ghostty-related autostart in this file.

### Ghostty configuration

`home-linux/ghostty.nix:23-79` — uses HM `programs.ghostty` with
`mkForce` on the entire settings attrset. The package's default
`com.mitchellh.ghostty.desktop` is installed automatically by the HM
module (copies
`${pkgs.ghostty}/share/applications/com.mitchellh.ghostty.desktop` →
`~/.local/share/applications/com.mitchellh.ghostty.desktop` and
HM-path
`/etc/profiles/per-user/glats/share/applications/com.mitchellh.ghostty.desktop`).

Effective desktop file content on rog
(`/nix/store/.../ghostty-1.3.1/share/applications/com.mitchellh.ghostty.desktop`):

```ini
[Desktop Entry]
Version=1.0
Name=Ghostty
Type=Application
Comment=A terminal emulator
TryExec=/nix/store/.../ghostty-1.3.1/bin/ghostty
Exec=/nix/store/.../ghostty-1.3.1/bin/ghostty --gtk-single-instance=true
Icon=com.mitchellh.ghostty
Categories=System;TerminalEmulator;
Keywords=terminal;tty;pty;
StartupNotify=true
StartupWMClass=com.mitchellh.ghostty
Terminal=false
Actions=new-window;
X-GNOME-UsesNotifications=true
X-TerminalArgExec=-e
X-TerminalArgTitle=--title=
X-TerminalArgAppId=--class=
X-TerminalArgDir=--working-directory=
X-TerminalArgHold=--wait-after-command
DBusActivatable=true                      <-- THE CULPRIT
X-KDE-Shortcuts=Ctrl+Alt+T

[Desktop Action new-window]
Name=New Window
Exec=/nix/store/.../ghostty-1.3.1/bin/ghostty --gtk-single-instance=true
```

Note: `Exec` already includes `--gtk-single-instance=true`, but that
flag only takes effect **after** the first instance has registered on
D-Bus. When two ghostty processes start in quick succession
(≤ ~100 ms apart, as the rofi timeout → direct-spawn path produces),
both can create windows before the first one becomes the single
instance.

### Rofi configuration

`home-linux/rofi.nix:109-130`:

```nix
programs.rofi = {
  enable = true;
  font = "Sans 12";
  terminal = "mate-terminal";
  theme = "ulauncher-like";

  extraConfig = {
    modi = "drun";
    display-drun = "🔍";
    show-icons = true;
    icon-theme = "Papirus-Dark";
    drun-display-format = "{name} - {comment}";
    drun-match-fields = "name,generic,exec,categories";
    sort = true;
    case-sensitive = false;
    steal-focus = true;
    location = 0;
    anchor = "center";
    disable-history = false;
    max-history-size = 50;
  };
};
```

No `DBusActivatable: false;` in the config. The option exists in
rofi 2.0.0 (binary contains the string `DBusActivatable`; later
versions renamed it to `gio-launch`, post-commit
`0472f34`).

### Live evidence — MATE log pattern

From `/home/glats/.local/state/xrdp-mate.log` on rog (the user IS
on rog, the system is rog):

```
(process:212812): Modes.DRun-WARNING **: 23:28:29.052: error sending Open message to application: Timeout was reached
DBus launch
DBus launch                                          # <-- second ghostty
```

Window manager then records two distinct XIDs:

```
Window manager warning: Buggy client sent a _NET_ACTIVE_WINDOW message with a timestamp of 0 for 0x3e00005 (Ghostty)
Window manager warning: Buggy client sent a _NET_ACTIVE_WINDOW message with a timestamp of 0 for 0x3e00015 (Ghostty)
```

Full count of `DRun-WARNING` events in the MATE log: **16**.
Pattern: 14 single-DBus-launch (one ghostty window), 2 double-launch
incidents (processes 212812 and 575453 — 575453 spawned **three**).
All happen because rofi's D-Bus Open to ghostty times out.

Note also: the MATE log is captured via `xrdpMateSession` in
`modules/features/services/xrdp.nix:34-113` (`exec >> "$LOG_FILE"
2>&1`, `set -x`). All stderr/stdout from MATE session processes
goes there, so the "DBus launch" line is the print from rofi's
`drun.c:exec_dbus_entry()` ("`printf("DBus launch\n")`").

### Rofi source confirmation

`strings` of
`/nix/store/d4xq2qfnq9rzz5lbn4vvcppcdz992r5z-rofi-unwrapped-2.0.0/bin/rofi`
contains:

- `g_dbus_connection_call_sync`
- `DBus launch`          ← the printf in exec_dbus_entry
- `DBusActivatable`      ← the property name rofi looks up
- `Trying to launch desktop file using dbus activation.`

This confirms rofi 2.0.0 still uses the `DBusActivatable` property
name. The renaming to `gio-launch` happened later (commit `0472f34`,
2026-03-20).

### Why rog and not thinkcentre (yet)

The user reports the issue on rog, has not tested on thinkcentre.
Likely the same race is present on thinkcentre but the bug is less
visible because:
- thinkcentre has **fewer** background services (no conky, no
  openfang, no webcam, no nvidia driver, no HexChat autostart).
- GPU startup is faster (Intel iGPU vs nvidia).
- Therefore ghostty's D-Bus interface registers **before** the rofi
  timeout more often, so the user only sees one window.

The fix should apply to all hosts because the underlying race is in
rofi+ghostty D-Bus interaction, not in any rog-specific code.

## Affected Areas

- `home-linux/rofi.nix:109-130` — the `programs.rofi.extraConfig`
  block. Adding `DBusActivatable: false;` here is the
  recommended/simplest fix.
- `home-linux/ghostty.nix:23-79` — the `programs.ghostty` block.
  Could also patch the desktop file to remove `DBusActivatable=true`
  via `xdg.dataFile."applications/com.mitchellh.ghostty.desktop".text
  = lib.mkForce "..."`. More targeted but more invasive (must
  re-maintain the desktop file content if upstream ghostty changes).
- `flake.nix:239-242` — only relevant if we want a host-conditional
  rofi config; not needed for the recommended fix (all hosts benefit).
- `overlays/linux.nix` / `overlays/darwin.nix` — only if we want to
  patch the ghostty package itself to ship a `DBusActivatable=false`
  desktop file. Not recommended; affects every ghostty consumer.
- `home-linux/mate.nix:117-123` — the MATE keybinding. Could
  prepend `DBUS_SESSION_BUS_ADDRESS=/dev/null` to the rofi command
  to neuter D-Bus entirely. This is a one-line alternative.

No rog-specific or thinkcentre-specific module needs to change for
the recommended fix. The bug is in rofi's drun mode + ghostty's
desktop file interaction, not in any host configuration.

## Approaches

### Approach A — Disable `DBusActivatable` in rofi config (recommended)

Add a single line to `home-linux/rofi.nix` (in the `extraConfig`
attrset, or as a new `DBusActivatable = false;` line, depending on
how HM merges the option):

```nix
extraConfig = {
  modi = "drun";
  ...
  DBusActivatable = false;   # avoid the D-Bus Open race that
                             # double-launches DBusActivatable apps
                             # (e.g. ghostty, see xrdp-mate.log)
};
```

- Pros:
  - One line change. Minimal diff, easy to review.
  - Fixes the bug for **all** `DBusActivatable=true` apps, not just
    ghostty.
  - Rofi 2.0.0 supports this option natively (string `DBusActivatable`
    in binary; matches DaveDavenport's recommended fix).
  - Applies automatically to rog, thinkcentre, and t14 (all use the
    shared `home-linux/rofi.nix`).
  - Reversible (just delete the line).
- Cons:
  - Slightly longer rofi exit time on first launch of any
    DBusActivatable app (rofi now spawns `Exec` directly instead of
    waiting for D-Bus Open). User should not notice because rofi
    closes immediately after spawn anyway.
  - Loses the "wait for app to register before closing rofi" feature
    for DBusActivatable apps. In practice, this is what was causing
    the bug.
- Effort: **Low** (1 line, well-documented upstream).

### Approach B — Override ghostty `.desktop` in `home-linux/ghostty.nix`

Add to `home-linux/ghostty.nix`:

```nix
xdg.dataFile."applications/com.mitchellh.ghostty.desktop" = lib.mkForce {
  text = builtins.replaceStrings
    [ "DBusActivatable=true" ]
    [ "DBusActivatable=false" ]
    (builtins.readFile
      "${pkgs.ghostty}/share/applications/com.mitchellh.ghostty.desktop");
};
```

(Or write the full desktop file inline; either is fine.)

- Pros:
  - Targets only ghostty, not all apps.
  - Doesn't touch the rofi config.
  - The HM `programs.ghostty` module's `xdg.dataFile` will be
    overridden by our `lib.mkForce`.
- Cons:
  - More code (full file read + replace), harder to review.
  - If upstream ghostty changes the desktop file structure, we need
    to revalidate the override still works.
  - Brittle: `mkForce` on the `xdg.dataFile` path may conflict with
    future HM upstream changes to `programs.ghostty`.
  - Does NOT fix the same race for other DBusActivatable apps
    (chrome, code, etc.) on rog.
- Effort: **Low-Medium** (5-10 lines, needs Nix test).

### Approach C — Neuter D-Bus on the rofi keybind

Modify `home-linux/mate.nix:122`:

```nix
command-1 = "DBUS_SESSION_BUS_ADDRESS=/dev/null ${pkgs.rofi}/bin/rofi -show drun";
```

- Pros:
  - Three-character prefix, trivial diff.
  - Disables ALL D-Bus in rofi; cannot have the race.
- Cons:
  - Rog-specific (only `mate.nix` is on rog, thinkcentre would still
    have the bug).
  - Lose ALL D-Bus features in rofi (e.g. `run` mode D-Bus
    integration, `drun` D-Bus Open for any app). Bigger blast radius
    than approach A.
  - Slightly hacky — we're disabling a transport to dodge a code
    path issue in the consumer.
- Effort: **Low** (1 line, but host-specific).

### Approach D — Patch the ghostty package via overlay

Add to `overlays/linux.nix`:

```nix
(final: prev: {
  ghostty = prev.ghostty.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      substituteInPlace \
        $out/share/applications/com.mitchellh.ghostty.desktop \
        --replace-fail "DBusActivatable=true" "DBusActivatable=false"
    '';
  });
})
```

- Pros:
  - Affects every consumer of the flake's `pkgs.ghostty` on Linux.
- Cons:
  - Affects all hosts globally (rog, thinkcentre, t14) and any
    non-NixOS Linux (mact2 via homebrew, etc. are not affected since
    this is the linux overlay only).
  - Diverges from upstream ghostty's intended D-Bus behavior.
  - Slightly more code (overlay + overrideAttrs).
  - The fix in the ghostty package itself is more invasive than the
    one-line rofi config change.
- Effort: **Medium** (overlay changes, harder to revert).

## Recommendation

**Approach A — Add `DBusActivatable = false;` to rofi's
`extraConfig` in `home-linux/rofi.nix`.**

Reasons:
1. **Smallest diff** (1 line) — easiest to review and revert.
2. **Most general** — fixes the race for all `DBusActivatable=true`
   apps, not just ghostty. Chrome, code, etc. could exhibit the same
   pattern on slow startups.
3. **Upstream-blessed** — the rofi maintainer explicitly recommends
   this exact setting for slow DBusActivatable apps. See
   davatorium/rofi#2077 and #2138.
4. **Applies to all Linux hosts** automatically (rog, thinkcentre,
   t14) via the shared `home-linux/rofi.nix`. The bug is in the
   rofi+ghostty interaction, not in any host-specific code.
5. **No package patching** required; stays at the config layer
   where the bug actually surfaces.

The only reason to prefer B would be if the user wants a
ghostty-specific fix that preserves D-Bus Open for other apps. The
user's report is specifically about ghostty, so I asked the user
during preflight to confirm scope. Per the preflight log, execution
mode is `ask` and the change is small enough to not need a wide
review.

## Risks

- **Rofi closes ~50ms faster on first launch of a DBusActivatable
  app.** The user is unlikely to notice (currently rofi waits 1.5s
  for D-Bus Open, then falls back to spawn — the spawn is
  instantaneous; the user sees rofi close right after ghostty
  appears). Net: imperceptible UX change.
- **Existing single-instance behavior of ghostty** is unaffected —
  `Exec` still includes `--gtk-single-instance=true`; the second
  invocation will hit the running ghostty and focus it (this is the
  intended behavior; the race window is the bug we are removing).
- **No risk to rofi's other modi** (run, window, combi) — the
  option is drun-only.
- **No risk to t14 / thinkcentre** — they get the same fix for
  free, which prevents the bug from manifesting there. thinkcentre
  was untested by the user; this proactively prevents the issue.
- **MATE keybinding** (`Ctrl+Space` → rofi) is unchanged.

## Verifying the fix

After applying approach A:

1. `nix flake check --no-build` — validate the flake.
2. `format-nix` — full-repo format per AGENTS.md.
3. Rebuild & switch rog (user drives; this is a long build):
   `nixos-build safe`.
4. On rog, trigger the previous bug:
   `Ctrl+Space` → type "ghostty" → Enter.
5. Verify only ONE ghostty window opens.
6. Cross-check `~/.local/state/xrdp-mate.log` — there should be no
   more `Modes.DRun-WARNING **: error sending Open message to
   application: Timeout was reached` lines after the new rofi
   config takes effect, OR (if rofi still logs the warning even
   when DBusActivatable=false) there should be no `DBus launch`
   follow-ups.

## Ready for Proposal

**Yes.** The change is small (1 line in `home-linux/rofi.nix`),
the root cause is confirmed, the fix is upstream-recommended, and
the impact is bounded. Orchestrator should run `sdd-propose`
next to write the formal proposal, then `sdd-spec` for the
delta spec, then `sdd-tasks` to break it into one implementation
task, then `sdd-apply` to make the change, then `sdd-verify` to
confirm the user-observed bug is fixed.

## Relevant Files

- `home-linux/rofi.nix` — **modify** (add `DBusActivatable = false;`)
- `home-linux/ghostty.nix` — read-only reference (HM `programs.ghostty`
  is the source of the desktop file)
- `home-linux/mate.nix:117-123` — read-only reference (the
  Ctrl+Space → rofi keybinding)
- `home-linux/mate-rog-autostart.nix` — read-only (rog-only;
  contains HexChat autostart, no ghostty)
- `home-linux/shared-modules.nix:25,28` — confirms `rofi.nix` and
  `ghostty.nix` are loaded on every Linux host
- `hosts/rog/default.nix` — read-only (rog host entry, no ghostty
  config in it)
- `hosts/rog/home/modules.nix` — read-only (rog extra HM modules)
- `hosts/thinkcentre/default.nix` — read-only (compare to rog)
- `hosts/thinkcentre/home/modules.nix` — read-only (compare to rog)
- `modules/features/services/xrdp.nix:34-113` — read-only (xrdp
  MATE session launcher; this is why stderr from rofi/ghostty
  ends up in `~/.local/state/xrdp-mate.log`)
- `flake.nix:108-111, 239-242` — read-only (ghostty flake input,
  rog extra HM modules)
- `~/.config/rofi/config.rasi` (effective on rog) — read-only
  reference, regenerated by `home-linux/rofi.nix`
- `/nix/store/.../ghostty-1.3.1/share/applications/com.mitchellh.ghostty.desktop`
  — read-only (the package's source desktop file with
  `DBusActivatable=true`)
