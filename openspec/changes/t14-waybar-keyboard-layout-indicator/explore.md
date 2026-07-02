# Exploration: t14-waybar-keyboard-layout-indicator

> **Topic**: `t14-waybar-keyboard-layout-indicator` (user said: "creo que hay un script para cambiar el keyboard layout a través de waybar. no se si quedo configurado o no, porque no lo veo")
> **Repo**: `/home/glats/.nixos`
> **Date**: 2026-06-28
> **Investigator**: sdd-explore (sub-agent)
> **Status**: complete

## TL;DR (answer to the user)

The **scripts exist and are deployed**, but **the waybar integration is missing**. The keyboard
layout can currently only be switched via `Alt+Shift` (because of an XKB option), not via a
waybar widget. There is no waybar module calling `kb-toggle.sh` or `kb-layout.sh`, and the
user has no visual indicator of the current layout.

The likely reason the user "doesn't see it" is that the **scripts were wired but the
follow-up step — adding a waybar module that consumes them — was never done**. There is
no TODO comment, but the only "waybar" code added in this repo is the iwd-wifi indicator,
which has the exact same TODO note ("follow-up: patch upstream waybar config to include
custom/iwd-wifi"). The keyboard layout work is in the same state but is even less visible
because the scripts have no visual footprint at all.

## Current State (verified by reading the workspace)

### What IS configured (working)

**Layer 1 — Hyprland XKB (active in the running session):**
- `hosts/t14/home/hypr/input.nix:10-11` overrides `kb_layout` and `kb_options`:
  ```nix
  kb_layout  = lib.mkForce "es,latam";
  kb_options = lib.mkForce "grp:alt_shift_toggle,compose:caps";
  ```
- Verified deployed at `~/.config/hypr/hyprland.conf`:
  ```
  kb_layout=es,latam
  kb_options=grp:alt_shift_toggle,compose:caps
  ```
- **The `grp:alt_shift_toggle` option means Alt+Shift does toggle between the two layouts.
  This is the only working switcher.** It is also a wholly unknown affordance to a user
  who is not already aware of it.

**Layer 2 — Helper scripts (deployed but not wired to anything):**
- `hosts/t14/home/scripts/kb-toggle.sh` (20 lines): cycles between group 0 and group 1
  via `hyprctl switchxkblayout keyboard group N`.
- `hosts/t14/home/scripts/kb-layout.sh` (40 lines): prints current layout or sets a
  named one (`kb-layout.sh` → prints "es"|"latam"; `kb-layout.sh latam` → switches).
- Both deployed to **two paths** (from `hosts/t14/home/default.nix:27-56`):
  - `~/.local/share/omarchy/bin/kb-{toggle,layout}.sh` (PATH-exposed, for terminal use)
  - `~/.config/hypr/kb-{toggle,layout}.sh` (for any waybar / hyprland plugin that
    resolves helper scripts at that path)
- Verified live symlinks:
  ```
  /home/glats/.local/share/omarchy/bin/kb-layout.sh -> /nix/store/.../home-manager-files/.local/share/omarchy/bin/kb-layout.sh
  /home/glats/.local/share/omarchy/bin/kb-toggle.sh -> /nix/store/.../home-manager-files/.local/share/omarchy/bin/kb-toggle.sh
  /home/glats/.config/hypr/kb-layout.sh          -> /nix/store/.../home-manager-files/.config/hypr/kb-layout.sh
  /home/glats/.config/hypr/kb-toggle.sh          -> /nix/store/.../home-manager-files/.config/hypr/kb-toggle.sh
  ```
- **The `~/.config/hypr/` copies are documented as "kept for any waybar module / hyprland
  plugin that resolves helper scripts at that path"** (`default.nix:41-46`). The author
  intended waybar / hyprland to call them.

### What is NOT configured (the gap)

1. **No waybar module references either script.** Searched both the deployed
   `~/.config/waybar/config` and the upstream `~/repos/omarchy-nix/config/waybar/config`
   — they are byte-for-byte identical (184 lines each), and **neither contains**:
   - Any `kb-toggle` / `kb-layout` reference
   - Any `custom/keyboard` / `custom/kb` / `custom/layout` module
   - Any module that runs `hyprctl switchxkblayout` or `hyprctl devices` to show the
     current layout
   - The `modules-right` array on the deployed config has only:
     ```
     "group/tray-expander", "bluetooth", "network", "pulseaudio", "cpu", "battery"
     ```
   - The `modules-center` array has: `clock`, `custom/update`, `custom/voxtype`,
     `custom/screenrecording-indicator`, `custom/idle-indicator`,
     `custom/notification-silencing-indicator`. **No layout indicator.**

2. **No hyprland keybind invokes `kb-toggle.sh`.** Searched `~/.config/hypr/hyprland.conf`
   for `kb-toggle`, `kb-layout`, `switchxkblayout` — zero matches. The only
   `switchxkblayout` invocation in the entire t14 stack is the one inside `kb-toggle.sh`
   itself, and the only other one anywhere on the system is `omarchy-system-lock` which
   hardcodes `switchxkblayout all 0` to reset to layout 0 on lock (unrelated).

3. **No upstream omarchy-nix support for a keyboard layout waybar module.** Searched
   `~/repos/omarchy-nix/` (the input the user's repo consumes) for:
   - `kb-toggle` / `kb-layout` / `keyboard-layout` — zero matches in any module or bin
   - `modules/home-manager/waybar.nix` (the HM module that ships the waybar config) has
     no layout-related code
   - `modules/home-manager/hyprland/bindings.nix` — no layout switcher bind
   - `config/waybar/config` — identical to the deployed one, no layout module

4. **No comment in any file flags the gap.** The only TODO-style comment adjacent to
   waybar custom modules is about iwd-wifi, not keyboard layout. The `kb-{layout,toggle}.sh`
   scripts themselves have no "TODO: wire to waybar" comment either.

### Why the user doesn't see it

There is **literally no waybar surface for the keyboard layout**. The only thing the user
could notice is the script files existing in `~/.local/share/omarchy/bin/` and
`~/.config/hypr/` — and those are the only deployed artifacts. No visual indicator, no
clickable widget, no `kb-toggle.sh` invocation from the desktop UI.

The closest the current setup comes to "switching through waybar" is that:
- The scripts are in `~/.local/share/omarchy/bin/` (which is on PATH), so a user can
  `Super+Space` → type "kb-toggle" → Enter to switch. But this is a launcher-mediated
  invocation, **not a waybar widget**.

## Affected Areas

- `hosts/t14/home/default.nix:27-56` — script deployment via `home.file`. **Status quo
  is correct** (the symlink-into-`~/.config/hypr/` pattern is the right scaffolding for
  a waybar module to find the script). No change needed here.
- `hosts/t14/home/scripts/kb-toggle.sh` and `kb-layout.sh` — **the scripts themselves
  are correct** and work. They use `hyprctl switchxkblayout` which is the canonical
  Hyprland way to switch layouts. No change needed.
- `hosts/t14/home/hypr/input.nix:10-11` — **XKB settings are correct** (`es,latam` +
  `grp:alt_shift_toggle`). Alt+Shift is the working toggle. No change needed.
- **MISSING — waybar config in `~/repos/omarchy-nix/config/waybar/config`** — needs a
  new module. Either:
  - `custom/keyboard-layout` with `exec = "~/.config/hypr/kb-layout.sh"` and
    `on-click = "~/.config/hypr/kb-toggle.sh"` (a polling indicator that shows the
    current layout name and toggles on click), OR
  - `hyprland/language` (the upstream waybar module that listens to
    `hyprland::language` events; requires no shell script at all).
- **MISSING — this repo's overlay of waybar.** Omarchy's `modules/home-manager/waybar.nix`
  does a recursive `home.file."source" = ../../config/waybar;` (full dir copy), so any
  edit to `config/waybar/config` upstream flows into t14 automatically. The
  t14-specific `home.file` overlay at `hosts/t14/home/default.nix:67-80` adds only the
  iwd-wifi indicator **script**, not a waybar config patch — so t14 inherits omarchy's
  waybar config verbatim.
- **OPTIONAL — `hosts/t14/home/omarchy.nix`** — would need a new font override if the
  waybar module uses a glyph (e.g. `omarchy.fonts.waybar` is already set to "sans" at
  line 107, which is enough for `󰌌` / `󰌉` Nerd Font icons).

## Approaches

### 1. **Use the built-in waybar `hyprland/language` module** — Effort: Low

Waybar ships a `hyprland/language` module out of the box. It listens to the
`hyprland::language` IPC event (fired automatically on layout switch) and renders the
current layout. No script needed at all. Click handler can be a custom exec.

```jsonc
// add to modules-right (or wherever)
"hyprland/language",
```
With optional styling per layout:
```jsonc
"hyprland/language": {
  "format": "  {}",
  "format-en": "EN",
  "format-es": "ES",
  "format-latam": "LA",
  "on-click": "exec", "exec": "~/.config/hypr/kb-toggle.sh",
  "tooltip": true
}
```

- **Pros**:
  - No script required (the `hyprland/language` module uses the IPC stream directly)
  - Reactive (updates on every layout change with zero polling latency)
  - ~6 lines of config; minimal diff
  - Works with the existing `kb_layout = "es,latam"` setup unchanged
- **Cons**:
  - The `format-<layout>` keys take a layout name; need to confirm what name
    `hyprland/language` reports for "latam" (likely "Latam" or the full name string
    reported by `hyprctl devices`)
  - Touches the upstream `glats/omarchy-nix` repo (the waybar config file lives there
    and is recursively copied into t14). User has push access (per AGENTS.md), so
    doable in a separate commit on that repo, then a flake pin bump here.
- **Effort**: ~15 min in upstream `omarchy-nix/config/waybar/config` + flake pin bump
  + `nix flake check --no-build`.

### 2. **Custom waybar `exec` module polling `kb-layout.sh`** — Effort: Low

Add a `custom/keyboard-layout` module to the waybar config that runs the
already-deployed `kb-layout.sh` script on an interval and uses `on-click` to call
`kb-toggle.sh`:

```jsonc
"custom/keyboard-layout": {
  "exec": "~/.config/hypr/kb-layout.sh",
  "format": "  {}",
  "interval": 1,
  "on-click": "~/.config/hypr/kb-toggle.sh",
  "tooltip": true,
  "return-type": "text"
}
```

- **Pros**:
  - Uses the scripts that are already deployed and tested
  - User-owned — no upstream change required, can live entirely in
    `hosts/t14/home/default.nix` (HM-managed waybar config) without forking omarchy
  - Polling interval is a tunable knob; `interval: 1` (1 second) is fine on a laptop
  - `on-click` is a single-command invocation; matches the waybar convention used by
    other custom modules (`custom/update`, `custom/idle-indicator`, etc.)
- **Cons**:
  - Polling has 1s worst-case latency for the visual to update after a toggle; Alt+Shift
    is instant
  - Adds a `custom/*` module that omarchy doesn't know about — but that's already the
    pattern for iwd-wifi on this exact host (`hosts/t14/home/default.nix:67-80`), so
    it's idiomatic
  - **Touches the upstream `omarchy-nix` config** for the waybar file if we want it
    upstreamed, OR we can override only on t14 by replacing the entire `~/.config/waybar`
    in HM. Replacing the whole dir is heavy; in-place JSON patch via a HM `xdg.configFile`
    would be cleaner.
- **Effort**: ~20 min if done per-host override in this repo (no upstream PR); ~10 min
  in upstream if we add it there.

### 3. **Switch the layout via the iwd-wifi pattern — a custom indicator script in
   `~/.config/waybar/indicators/`** — Effort: Low

Mirror the existing iwd-wifi approach: add a `kb-layout.sh` JSON-emitting script under
`~/.config/waybar/indicators/`, deploy it via `home.file` in
`hosts/t14/home/default.nix`, and add a corresponding `custom/keyboard-layout` module
to the waybar config that runs it.

- **Pros**:
  - Matches the iwd-wifi pattern verbatim (same dir, same `home.file` block, same
    `exec` + `return-type: json` style) — already established as the per-host waybar
    pattern in this repo
  - The script can format text (e.g. `"ES"` / `"LA"`), include tooltips, and toggle
    on click in one place
  - The `~/.config/waybar/indicators/` directory is already included via omarchy's
    recursive dir copy, so no config patch is needed in upstream if the user adds
    the custom module themselves in this repo
  - Cleanly separable: indicator logic in the script, waybar config in a small
    `xdg.configFile."waybar/config"` patch in `hosts/t14/home/default.nix`
- **Cons**:
  - Slightly more code than Approach 1 (script + module vs. just a module)
  - Still has the 1s polling latency of Approach 2
- **Effort**: ~30 min; a single `hosts/t14/home/default.nix` change + one new
  script file.

### 4. **Add a Hyprland keybind for `kb-toggle.sh`, no waybar change** — Effort: Low

Add a Hyprland keybind that invokes `kb-toggle.sh` directly:

```nix
# hosts/t14/home/hypr/bindings.nix (new file or appended to input.nix)
wayland.windowManager.hyprland.settings = {
  bind = [
    ", Caps_Lock, exec, ~/.config/hypr/kb-toggle.sh"  # remap Caps → toggle
    # or keep Alt+Shift from kb_options AND add an explicit Super+Shift bind
  ];
};
```

- **Pros**:
  - The scripts already exist; this just exposes them via a keybind
  - No waybar config changes (avoids the upstream fork problem)
  - Combines with the existing XKB Alt+Shift toggle (both work)
- **Cons**:
  - **Does not satisfy the user's stated request** — they specifically asked about
    a waybar widget, not a keybind. They'd see the same "no waybar indicator" gap
  - Doesn't add a visual indicator of the current layout
  - Conflicts with `kb_options = "...compose:caps"` which remaps Caps_Lock to Compose.
    A Caps-based bind would need to be re-thought (e.g. Right Alt + Shift, or
    Super + Space)
- **Effort**: ~5 min, but doesn't address the request.

### 5. **Accept the current state (Alt+Shift is enough)** — Effort: None

Document in `hosts/t14/home/hypr/input.nix` that Alt+Shift toggles, and tell the user
that's how it works.

- **Pros**: zero work, zero risk
- **Cons**: doesn't address the user's actual ask (waybar widget)
- **Effort**: zero

## Recommendation

**Approach 1 (`hyprland/language` module) is the right answer** if the user is willing
to land a small upstream change in `glats/omarchy-nix`. It's the smallest possible diff,
the most reactive (no polling), the most idiomatic (waybar's first-party way to expose
Hyprland layout state), and it doesn't need any custom shell script.

**Approach 3 (per-host indicator script in `~/.config/waybar/indicators/`)** is the
right answer if the user wants to keep the work entirely in this repo (matching the
existing iwd-wifi pattern). It's slightly more code but no upstream PR is needed.

**Approach 2 (custom `exec` module without a separate script) is fine but
redundant** with the already-deployed scripts — Approach 3 reuses them, Approach 2
duplicates the call to `hyprctl`.

I would **not recommend Approach 4** (the user's question is specifically about waybar,
not about adding another keybind), and **not Approach 5** (the user said they don't
see anything; telling them "Alt+Shift works" is technically true but does not address
the visual gap).

### Concrete change shape (Approach 1)

In `~/repos/omarchy-nix/config/waybar/config`, add to `modules-right` (between
`battery` and the closing bracket):
```jsonc
"hyprland/language"
```
And add a module block:
```jsonc
"hyprland/language": {
  "format": "  {}",
  "format-en": "EN",
  "format-es": "ES",
  "format-latam": "LA",
  "on-click": "~/.config/hypr/kb-toggle.sh",
  "tooltip": true
},
```

In this repo, the only follow-up is `nix flake update omarchy-nix` to pull the new
commit, then `nix flake check --no-build` to verify.

### Concrete change shape (Approach 3, per-host)

Two new things in `hosts/t14/home/default.nix`:

1. A `home.file` entry for `~/.config/waybar/indicators/kb-layout.sh` (text form, JSON
   output) — same pattern as the iwd-wifi block on lines 67-80.
2. A `xdg.configFile."waybar/config.json".text` (or similar) that **patches** the
   deployed waybar config to add `"custom/keyboard-layout"` to `modules-right` and a
   corresponding module block. This is the new bit — currently the t14 host does not
   override the waybar config at all (it inherits omarchy's verbatim via the recursive
   `home.file."source" = ../../config/waybar` in `~/repos/omarchy-nix/modules/home-manager/waybar.nix:10-13`).
   A clean way: ship a `~/.config/waybar/config.jsonc` from this repo and use HM's
   `xdg.configFile` to write it (and remove the upstream `home.file."source" = ...`
   for t14 by `lib.mkForce`).

The Approach 3 effort is real but bounded.

## Risks

- **Approach 1: upstream-fork coordination.** The waybar config lives in
  `glats/omarchy-nix` (the user owns this repo, so procedural, not blocking). After
  the upstream change, a flake pin bump is required here. Risk: low.
- **Approach 1: `format-<layout>` naming.** `hyprland/language` reports the layout name
  as Hyprland sees it. For "latam", the IPC event payload is the full layout string,
  so `format-latam` may not match exactly. Need to verify the actual payload by running
  `hyprctl devices -j` after enabling a layout. Risk: low (just a name key).
- **Approach 3: waybar config conflict.** Omarchy's `modules/home-manager/waybar.nix`
  does a recursive `home.file."source"` copy, which conflicts with an HM
  `xdg.configFile."waybar/config"` override (HM refuses to clobber). The clean
  override path is `lib.mkForce` on the upstream's `home.file."source"`, or
  moving the config to `xdg.configFile."waybar/config.jsonc"` and pointing waybar
  to that. Risk: medium (config-management complexity).
- **Approach 3: script fragility.** `kb-layout.sh` and `kb-toggle.sh` rely on
  `hyprctl`, which is only present inside an active Hyprland session. The script
  already silently swallows errors (`2>/dev/null || true`). No new risk.
- **Approach 4 keybind conflict.** The existing `kb_options = "...compose:caps"`
  remaps Caps_Lock to Compose. Adding a `bind = ", Caps_Lock, exec, ..."` would
  shadow Compose. Risk: medium (loses Compose key). Not recommended.
- **User communication risk.** The user said "no lo veo" (I don't see it). After the
  fix, the visual indicator (a "ES" or "LA" badge in waybar) will be the proof.
  Approach 5 ("Alt+Shift works, just use that") is technically correct but does not
  visibly demonstrate the fix.

## Key files

In this repo (`/home/glats/.nixos`):
- `hosts/t14/home/default.nix:27-56` — script deployment (correct, no change)
- `hosts/t14/home/scripts/kb-toggle.sh` — the toggle script (correct, no change)
- `hosts/t14/home/scripts/kb-layout.sh` — the layout show/set script (correct, no change)
- `hosts/t14/home/hypr/input.nix:10-11` — XKB layout + Alt+Shift toggle (correct, no change)
- `hosts/t14/home/default.nix:67-80` — the iwd-wifi waybar indicator pattern that
  the keyboard layout should mirror
- `flake.nix:19-23` — `omarchy-nix` input pin (would need a bump if Approach 1 is taken)

Upstream `glats/omarchy-nix` (user-owned):
- `config/waybar/config` — the JSON file that owns the waybar module list (Approach 1
  changes here; Approach 3 leaves it alone)
- `modules/home-manager/waybar.nix:9-14` — the HM module that copies the waybar config
  to `~/.config/waybar/` recursively
- `modules/home-manager/hyprland/input.nix:10-11` — sets `kb_layout = "us"`,
  `kb_options = "compose:caps"`; the t14 override wins via `lib.mkForce`

External (read-only references):
- https://github.com/Alexays/Waybar/wiki/Module:-Hyprland#language — docs for the
  `hyprland/language` module (Approach 1)
- https://wiki.hyprland.org/Configuring/Variables/#input — `kb_layout` and
  `kb_options` reference
- https://wiki.hyprland.org/Useful-Utilities/Hyprctl/#switchxkblayout — the `switchxkblayout`
  subcommand the existing scripts use

## Ready for Proposal?

**Yes — propose a small change.** The user has a clear ask ("script for switching
keyboard layout through waybar"), the scripts already exist, and the only missing
piece is the waybar module. Approach 1 is the cleanest and most reactive; Approach 3
keeps all changes inside this repo.

A clarification question for the user before proposing: **"Do you want the layout
indicator + click-to-toggle as a waybar widget, or just a click-to-toggle keybind?"**
The answer determines Approach 1 vs. Approach 4 (though Approach 1 covers both
needs at once).

If the orchestrator wants to skip clarification, **default to Approach 1**
(`hyprland/language` module + click-to-toggle via `kb-toggle.sh`). It satisfies
both interpretations of the user's request.
