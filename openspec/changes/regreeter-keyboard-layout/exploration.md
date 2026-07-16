# Exploration: regreeter-keyboard-layout

## Current State

### Greeter Architecture (t14 host)

- **Display manager**: greetd with Hyprland as the greeter compositor (NOT cage, NOT standard ReGreet/session-file path).
- **Why Hyprland**: explicitly chosen so the keyboard layout toggle (Alt+Shift between es and latam) works at the login screen. See `hosts/t14/home/omarchy.nix:32-46` for the decision record.
- **Config chain**: `hosts/t14/default.nix` → `omarchy.greeter = { type = "regreet"; ... }` → `omarchy-nix/modules/nixos/system.nix` → generates `/etc/greetd/hyprland.conf` at build time.

### Keyboard Layout Configuration

| Layer | Layouts | Toggle Option | File |
|-------|---------|---------------|------|
| NixOS default | `es` (xkb.layout) | None | `modules/desktop/i18n.nix:18` |
| t14 host override | `latam` (xkb.layout forced) | None | `hosts/t14/default.nix:143-144` |
| Hyprland user session | `es,latam` | `grp:alt_shift_toggle` | `hosts/t14/home/hypr/input.nix:15-16` |
| Greeter Hyprland session | `es,latam` | `grp:alt_shift_toggle` | `hosts/t14/default.nix:208-217` |

**Discrepancy**: User mentioned "Ctrl+Shift to change layout" but the codebase uses `grp:alt_shift_toggle` everywhere. The `grp:ctrl_shift_toggle` XKB option exists but is not configured anywhere. This may be a user misremembering, or a separate run-time config not captured in Nix.

### Greeter Hyprland Config (generated at build time)

The generated `/etc/greetd/hyprland.conf` (from `omarchy-nix/modules/nixos/system.nix:282-291`):

```
{monitor lines}
env = XCURSOR_THEME,...
env = HYPRCURSOR_THEME,...
{optional wayvnc exec-once &}
exec-once = /nix/store/<hash>-greetd-regreet-start/bin/greetd-regreet-start
input {
    kb_layout = es,latam
    kb_options = grp:alt_shift_toggle
}
misc {
    disable_hyprland_logo = true
    disable_splash_rendering = true
    disable_hyprland_guiutils_check = true
}
```

The `greetd-regreet-start` script (lines 196-257) runs three phases:
1. Monitor selection (focusMonitor matching)
2. eDP-1 disable when external monitors connected
3. Launch `regreet`; on exit, `hyprctl dispatch exit`

There is currently **no** keyboard layout indicator in the greeter. The toggle works but there is zero visual feedback about which layout is active.

### User Session Layout Scripts

Two helper scripts exist for the user session (NOT the greeter session):
- `kb-toggle.sh`: Toggles between es (index 0) and latam (index 1) via `hyprctl switchxkblayout`
- `kb-layout.sh`: Reads active layout via `hyprctl devices` awk parsing, or sets it

Both use `hyprctl devices` which queries the compositor's input state — this same approach works in the greeter session if Hyprland is running.

## Capability Analysis

### ReGreet Capabilities

**ReGreet has NO built-in keyboard layout indicator.**

- Sample TOML (`regreet.sample.toml`): only `[widget.clock]`, `[appearance]`, `[GTK]`, `[background]`, `[commands]`, `[env]` sections. No keyboard/layout widget.
- README explicitly states: "For configuring other essential features, such as the keyboard layout/mapping, the choice of monitor to use, etc., please check out the configuration options for the wayland compositor that you are using to run ReGreet."
- No custom widget plugin system in ReGreet.
- `extraCss` only applies static GTK CSS — no runtime layout state injection.
- ReGreet is a GTK4 app with no IPC/DBus interface for external layout querying.

### Hyprland (Compositor) Capabilities

**Hyprland runs the greeter session, so it can be extended.**

- `exec-once` lines can be added to the greeter Hyprland config BEFORE the regreet launch.
- `hyprctl devices -j` returns JSON with keyboard info including active layout index (the same mechanism used by `kb-layout.sh`).
- Hyprland window rules can position floating overlay windows (pinned, no borders, ignore input).
- Layer-shell is available in the compositor (waybar, etc. can run).
- Variables like `$mainMod` are NOT available in greeter session (no user config loaded).
- `misc:disable_hyprland_logo` and `disable_splash_rendering` suppress Hyprland's own indicators.

### GTK Layer Considerations

- ReGreet uses GTK4 portals for session management (logind, etc.).
- `GTK_USE_PORTAL=0` may be needed for GTK apps launched in the greeter session to avoid portal deadlocks.
- The greeter session runs as the `greeter` system user (no `$HOME` for user configs).

## Options Found

### Option A: EWW/AGS Overlay Widget

Launch a small EWW (Elkowar's Wacky Widgets) or AGS (Aylur's GTK Shell) bar/window as `exec-once` in the greeter Hyprland config before regreet. The widget polls `hyprctl devices -j` every 500ms and displays "ES" or "LATAM".

- **Effort**: High
- **Complexity**: High — EWW/AGS require their own config language (yuck/TypeScript), theming, and packaging into a Nix derivation.
- **Feasibility**: Yes, but over-engineered for showing two letters.

### Option B: Simple Shell Script with YAD/Zenity

Add an `exec-once` line that runs a shell script which:
1. Polls `hyprctl devices -j` for active layout index (0=es, 1=latam)
2. Displays/updates a `yad --no-buttons` or `zenity --notification` window
3. Uses Hyprland window rules to position it (e.g., top-right corner, floating, pinned, no focus)

- **Effort**: Medium
- **Complexity**: Medium — needs GTK deps (yad is ~3 MiB), polling loop, window rule coordination.
- **Risk**: yad/zenity may not render correctly in minimal Hyprland session; may steal focus from regreet password field.
- **YAD availability**: `pkgs.yad` exists in nixpkgs (GTK3 dialog utility).

### Option C: Hyprland `exec-once` + `wlr-which-key` style overlay

Use Hyprland's `submap` mechanism — when user presses the toggle key, briefly show an overlay. This would require the toggle to go through Hyprland binds rather than XKB `grp:` options.

- **Effort**: Medium
- **Complexity**: Medium — would need to replace `grp:alt_shift_toggle` with custom Hyprland keybinds + `switchxkblayout` dispatch, then show an overlay on toggle.
- **Risk**: XKB-level toggle is more reliable; replacing it with compositor binds could break in edge cases.

### Option D: PATCH ReGreet Source

Fork ReGreet, add a keyboard layout widget to the GTK UI by reading the compositor's layout state via the wlr-layer-shell or wayland protocol.

- **Effort**: Very High
- **Complexity**: Very High — requires Rust/GTK4 development, understanding ReGreet's internal architecture, maintaining a fork, upstreaming.
- **Feasibility**: Technically possible but disproportionate to the value.

### Option E: Do Nothing — Accept No Visual Feedback

The layout toggle works correctly at the login screen via XKB `grp:alt_shift_toggle`. The user simply cannot see which layout is active. Since there are only two layouts (es, latam), pressing the toggle key once always switches.

- **Effort**: None
- **Complexity**: None
- **Feasibility**: Always works, but fails the user's explicit request.

### Option F: WAYBAR in Greeter Mode

Launch waybar in the greeter Hyprland session with a minimal config showing only a `custom/kb-layout` module. waybar supports layer-shell and can run custom scripts on an interval.

- **Effort**: Medium-Low
- **Complexity**: Medium-Low — waybar is already installed (user session), just needs a separate greeter config.
- **Risk**: waybar initialization might race with regreet; both use layer-shell; waybar might overlap regreet's login form.
- **Packages**: `pkgs.waybar` already available; `pkgs.jq` needed for JSON parsing.

## Decision or Recommendation

**RECOMMENDATION: Option F (waybar in greeter mode) as primary, Option B (yad script) as fallback.**

Option F is the most pragmatic because:
1. **waybar is already in the closure** — no new heavy deps
2. **Layer-shell integration** — waybar naturally occupies a screen edge without overlapping regreet's centered login form
3. **Proven pattern** — the user session already uses waybar; a minimal greeter config is a natural extension
4. **Custom script reuse** — the polling logic from `kb-layout.sh` can be adapted with minor changes
5. **Nix-native** — waybar config is declarative via Home Manager or direct file write

**Configuration approach**:
- Add `exec-once` to the greeter Hyprland config (BEFORE `greetd-regreet-start`) that launches waybar with a separate greeter-specific config file
- Create a minimal waybar config at `/etc/greetd/waybar-config` showing only a `custom/kb-layout` module
- The custom module runs a shell one-liner: `hyprctl devices -j | jq -r '.keyboards[] | select(.main) | .active_keymap'`
- Set `GTK_USE_PORTAL=0` env var in the greeter Hyprland config to prevent GTK portal deadlocks
- This requires changes in TWO repos: `omarchy-nix` (greeter config generation) and `nixos-hosts` (waybar config for greeter)

**Implementation surface**:
| Repo | File | Change |
|------|------|--------|
| omarchy-nix | `modules/nixos/system.nix:282-291` | Add `env = GTK_USE_PORTAL,0` and `exec-once = waybar -c /etc/greetd/waybar-config` before regreet |
| omarchy-nix | `config.nix:~300-317` | Add optional `layoutIndicator` submodule under `greeter` |
| nixos-hosts | `hosts/t14/default.nix:~208` | Enable `greeter.layoutIndicator` with waybar config |

### Ctrl+Shift vs Alt+Shift Discrepancy

The user says "Ctrl+Shift to change layout" but both the greeter and user session use `grp:alt_shift_toggle`. Available XKB options include `grp:ctrl_shift_toggle` if the user wants to change. This should be clarified before implementation.

## Risks and Unknowns

1. **waybar startup race**: If waybar launches after regreet has already grabbed layer-shell, it may fail silently. The `exec-once` ordering in Hyprland guarantees waybar runs before `greetd-regreet-start` (which launches regreet), but regreet's initialization may be faster than waybar's. Mitigation: delay regreet launch by 0.5s in the script.

2. **GTK portal deadlock**: GTK apps running in a bare Hyprland session may hang waiting for `xdg-desktop-portal`. `GTK_USE_PORTAL=0` should prevent this, but needs testing.

3. **waybar layer-shell overlap**: waybar's bar may compete for screen space with regreet's centered login form. waybar's default bottom/top bar position should not overlap, but the `mode: overlay` vs `mode: dock` distinction matters.

4. **Ctrl+Shift vs Alt+Shift mismatch**: User's stated preference doesn't match the code — needs clarification before implementation.

5. **Non-t14 hosts**: rog (MATE/X11 + SDDM) and thinkcentre (headless) do not use regreet/greetd at all. mact2 uses nix-darwin (no greeter concept). This change is t14-only.

6. **Greeter user permissions**: The `greeter` system user runs the Hyprland session. It needs access to `/etc/greetd/waybar-config` (world-readable by default) and the waybar binary (in PATH).

7. **Hyprland IPC socket**: `hyprctl` communicates via `$HYPRLAND_INSTANCE_SIGNATURE` socket. The greeter script already uses `hyprctl` successfully (monitor selection phase), so this is proven to work.

8. **Waybar config persistence**: If waybar config references `/etc/greetd/waybar-config`, it's generated at Nix build time and read-only — updates require rebuild. For a greeter, this is acceptable (no runtime reconfiguration needed).

## Relevant Files

- `hosts/t14/default.nix:201-234` — Greeter config (type, keyboard layouts/options, focusMonitor, monitors, cursor, wayvnc)
- `hosts/t14/home/omarchy.nix:32-46` — Architecture decision record documenting Hyprland-as-greeter-compositor
- `hosts/t14/home/hypr/input.nix:14-17` — User session keyboard layout override (es,latam + alt_shift_toggle)
- `hosts/t14/home/scripts/kb-layout.sh` — User session script to read/set keyboard layout via hyprctl
- `hosts/t14/home/scripts/kb-toggle.sh` — User session script to toggle layout with debounce
- `modules/desktop/i18n.nix:17-19` — NixOS default keyboard layout (xkb.layout = "es")
- `/home/glats/repos/omarchy-nix/modules/nixos/system.nix:155-291` — Greeter greetd session + Hyprland config generation
- `/home/glats/repos/omarchy-nix/config.nix:300-317` — `omarchy.greeter.keyboard` submodule options
- `/home/glats/repos/omarchy-nix/config.nix:331-347` — `omarchy.greeter.focusMonitor` option
- `openspec/specs/greeter-script/spec.md` — Spec for the greeter script architecture (named derivation, phases, logging, VT escape hatch)
- `openspec/specs/hyprland-config/spec.md:36-69` — Spec documenting Hyprland-as-greeter-compositor decision

## Verification Notes

- ReGreet GitHub: https://github.com/rharish101/ReGreet — README confirms no built-in layout widget
- ReGreet sample TOML: https://github.com/rharish101/ReGreet/blob/main/regreet.sample.toml — no keyboard/layout section
- NixOS option `programs.regreet.settings`: TOML value, no layout-specific sub-options
- NixOS option `programs.regreet.extraCss`: static CSS only, no runtime state injection
- External search: multiple greetd greeters (elementary, dankgreeter) have the same limitation — keyboard layout display requires compositor-level support
