# Exploration: t14-hdm-migration-v3

## Current Stack Analysis

The T14's monitor management is ~290 lines of fragile custom code split across 4 files:

### What It Does

1. **monitor-lid-validator.sh** (71 lines) — Bash daemon running as a systemd user service. Polls `/proc/acpi/button/lid/LID*/state` every 2s via a `while true; do sleep 2` loop. On lid state change OR monitor hotplug (detected via `hyprctl monitors -j` snapshot diff), re-applies monitor layout via `hyprctl keyword monitor` with description-based (EDID) matching. Two states: `move_to_y420()` (lid open — laptop at 4920x420, externals at y=420) and `move_to_y0()` (lid closed — laptop disabled, externals at y=0).

2. **monitors.nix** (88 lines) — Nix-generated Hyprland configuration. Uses hyprlang conditional blocks (`if ENABLE_LAPTOP / if !ENABLE_LAPTOP`) driven by `~/.config/hypr/settings.conf`. Has inline `bindl` for lid events (regex `switch:on:.*[Ll]id.*` and `switch:off:.*[Ll]id.*`) that pipe to long shell chains (`printf + hyprctl keyword` x4 monitors). Workspace rules use `mkWorkspaceRules` with cyclic distribution (1/4/7/10/13/16/19 → AOC 24P1W1, 2/5/8/11/14/17/20 → Lenovo G24-10, 3/6/9/12/15/18 → AOC 2470W). eDP-1 workspace bindings in the extraConfig `if ENABLE_LAPTOP` block bind ws 1-3 to eDP-1.

3. **default.nix (home)** (128 lines) — Deploys the bash script via `home.file`, seeds `settings.conf` via `home.activation.seedHyprSettings`, adds a `udevadm settle` drop-in for Hyprland, runs the daemon as a `systemd.user.service` with `Type=simple` and `Restart=on-failure`.

4. **default.nix (t14 host)** (239 lines) — Omarchy config block: `monitors = ["eDP-1,preferred,auto,1"]` (omarchy's own monitor directive), `hyprland.lidSwitch.enable = false` (disables omarchy's default lid bindl to avoid dual-writer race), greeter monitors configured separately.

### What's Fragile About It

| Fragility | Symptom | Root Cause |
|-----------|---------|------------|
| Polling lag | 2s stall on dock/undock before monitors adjust | `while true; do sleep 2` in bash daemon |
| ACPI dependency | `/proc/acpi/button/lid/LID*/state` is legacy | Uses ACPI procfs instead of Wayland-native events |
| Shell chain monstrosity | 300+ char bindl strings with `&&` chains of `printf + 4x hyprctl keyword` | All monitor directives inlined into hyprlang `bindl` |
| settings.conf persistence | v1 BUG 1: settings.conf written via `printf` with absolute path in hyprlang source | Home Manager can't manage a writable runtime file |
| Hyprlang conditional fragility | v1 BUG 6: `if ENABLE_LAPTOP` block binds ws 1-3 to eDP-1; `mkWorkspaceRules` also binds ws 1-3 to externals → two `default:true` per workspace | Double workspace binding breaks Super+1/2/3 |
| Connector name rot | DP-3/4/5 → DP-6/7/8 after kernel updates | Description-based matching in scripts but connector names in documentation |
| No proper hotplug detection | Snapshot diff via `grep name | sort` | No event-driven monitor add/remove handling |
| Race with omarchy watch | `omarchy-hyprland-monitor-watch` calls `hyprctl reload` on `monitoradded>>` | Two writers (bash daemon + omarchy socat) can race |
| Flaky state recovery | v1 BUG 3: `source =` directive resolves relative to hyprland.conf, not config dir. Paths in `$HOME/.config/hypr/` break when HM manages the file. | HDM destination path must be outside HM-managed tree |

### Omarchy-Nix Monitor Handling (What We Must Not Break)

- **omarchy.hyprland.lidSwitch.enable = false** — Disables omarchy's default `bindl` that calls `omarchy-hw-external-monitors && omarchy-hyprland-monitor-internal off/on`. Must remain disabled.
- **omarchy.greeter.*** — Greeter monitors are configured separately in `hosts/t14/default.nix` (`omarchy.greeter.monitors`). Not affected.
- **omarchy-hyprland-monitor-watch** — socat listener that reacts to `monitorremoved>>` events by calling `omarchy-hyprland-monitor-internal recover`. Orthogonal to profile-based switching; benign with HDM's `debounce_time_ms = 1500`.
- **omarchy config block** — `omarchy.monitors = ["eDP-1,preferred,auto,1"]` feeds into `wayland.windowManager.hyprland.settings.monitor`. This must NOT conflict with HDM's generated config.

### Requirements That Must Be Preserved

1. **4 monitors**: eDP-1 (laptop 1920x1080) + AOC 24P1W1 (1080x1920 portrait, rotated) + Lenovo G24-10 (1920x1080) + AOC 2470W (1920x1080)
2. **Dead-zone fix**: y=420 for horizontal monitors when docked+lid-open (AOC 24P1W1 portrait is 1080px tall → horizontals centered at y=420 for cursor dead-zone elimination)
3. **eDP-1 parked at -30000x0** when lid closed (NOT disabled — Hyprland #1274: disabling eDP-1 loses workspace state)
4. **4 layout states**: docked+lid-open, docked+lid-closed, undocked+lid-open, undocked+lid-closed
5. **Workspace 1-3 always on eDP-1** when laptop is active; **workspaces 4-20 distributed** across external monitors (cyclic mod 3)
6. **GDK_SCALE=1** env
7. **Description-based matching** (EDID) — not connector names that change after kernel updates
8. **No regression** on rog, thinkcentre, mact2 builds

## Tools Survey

| Tool | Nixpkgs | Explicit Coords | Lid Events | EDID Match | HM Module | Active | Stars | Notes |
|------|---------|-----------------|------------|------------|-----------|--------|-------|-------|
| **HyprDynamicMonitors** | ✅ v1.4.0 | ✅ | ✅ UPower D-Bus | ✅ (desc+regex) | ✅ (flake) | ✅ Jun 2026 | 364 | Hyprland-specific, event-driven, TUI, templates, scoring, fallback |
| **shikane** | ✅ v1.0.1 | ✅ | ❌ | ✅ (ser/model/vendor/name+regex) | ✅ (HM 25.11) | ✅ May 2026 | ~50 | Generic wlr-output-management, deterministic matching, no lid events |
| **kanshi** | ✅ v1.8.0 | ✅ | ❌ | ✅ | ❌ | ⚠️ Stagnant | ~500 | Generic, no lid support (issue #56 closed won't fix), no HM module |
| **hyprdocked** | ❌ | ✅ | ✅ (limited) | ❌ (connector only) | ❌ | ❌ Archived | 0 | Dead project. Required Hyprland 0.55 Lua `hyprctl eval` — fragile |
| **nwg-displays** | ✅ | ✅ (GUI) | ❌ | ✅ | ❌ | ✅ | 400+ | GUI only, no automatic profile switching. Companion tool, not replacement. |
| **hyprmon** | ✅ | ✅ (TUI) | ❌ | ❌ | ❌ | ⚠️ | ~100 | TUI only, manual. Not a daemon. |
| **srandrd** | ✅ | ✅ (wlr) | ❌ | ❌ | ❌ | ⚠️ | ~30 | X11/wlr-randr approach, not Hyprland-specific. |
| **pyprland** | ❌ (AUR) | ✅ | ⚠️ via plugins | ❌ | ❌ | ✅ | ~200 | Python plugin ecosystem. Adds complexity via external plugins. Not in nixpkgs. |

### Critical Gaps Identified

- **shikane**: No lid events. To handle lid with shikane, you'd need external lid detection (systemd-logind/acpid) + `shikanectl switch` calls. This means keeping a bindl or adding a separate lid watcher — similar to the current stack's fragility.
- **kanshi**: No lid support and no HM module. Requires `bindswitch + kanshictl switch` workaround. Archived approach.
- **hyprdocked**: Dead project. Archived with 0 stars.

## Tool Deep-Dives

### 1. HyprDynamicMonitors (v1.4.0)

**Config format**: TOML at `~/.config/hyprdynamicmonitors/config.toml`

```toml
[general]
destination = "$HOME/.config/hypr/config.d/99_autogenerated-monitors.conf"
debounce_time_ms = 1500

[lid_events]
[lid_events.dbus_query_object]
destination = "org.freedesktop.UPower"
path = "/org/freedesktop/UPower"
method = "org.freedesktop.DBus.Properties.Get"
expected_lid_closing_value = "true"
[[lid_events.dbus_query_object.args]]
arg = "org.freedesktop.UPower"
[[lid_events.dbus_query_object.args]]
arg = "LidIsClosed"
[[lid_events.dbus_signal_match_rules]]
interface = "org.freedesktop.DBus.Properties"
object_path = "/org/freedesktop/UPower"
member = "PropertiesChanged"
[[lid_events.dbus_signal_receive_filters]]
name = "org.freedesktop.DBus.Properties.PropertiesChanged"
body = "LidIsClosed"

[scoring]
name_match = 10
description_match = 5
power_state_match = 3
lid_state_match = 2

[fallback_profile]
config_file = "hyprconfigs/fallback.conf"
config_file_type = "static"

[profiles.docked_lid_open]
config_file = "hyprconfigs/docked-lid-open.conf"
config_file_type = "static"
[profiles.docked_lid_open.conditions]
lid_state = "Opened"
[[profiles.docked_lid_open.conditions.required_monitors]]
name = "eDP-1"
[[profiles.docked_lid_open.conditions.required_monitors]]
description = "AOC 24P1W1 OTNQ4HA000101"
[[profiles.docked_lid_open.conditions.required_monitors]]
description = "Lenovo Group Limited LEN G24-10 U5B4GWF1"
[[profiles.docked_lid_open.conditions.required_monitors]]
description = "AOC 2470W GGZM3HA438259"

[profiles.docked_lid_closed]
config_file = "hyprconfigs/docked-lid-closed.conf"
config_file_type = "static"
[profiles.docked_lid_closed.conditions]
lid_state = "Closed"
# ... same 4 required_monitors
```

**Static hyprconfig example** (`docked-lid-open.conf`):
```
monitor = eDP-1, preferred, 4920x420, 1
monitor = desc:AOC 24P1W1 OTNQ4HA000101, 1920x1080@60, 0x420, 1, transform, 1
monitor = desc:Lenovo Group Limited LEN G24-10 U5B4GWF1, 1920x1080@60, 1080x420, 1
monitor = desc:AOC 2470W GGZM3HA438259, 1920x1080@60, 3000x420, 1
```

**Integration pattern (NixOS)**:
```nix
# flake.nix
inputs.hyprdynamicmonitors.url = "github:fiffeek/hyprdynamicmonitors";

# hosts/t14/default.nix — add to home-manager.users.glats.imports
inputs.hyprdynamicmonitors.homeManagerModules.default

# Home Manager config block
home.file.".config/hyprdynamicmonitors/config.toml".source = ./hdm/config.toml;
home.file.".config/hyprdynamicmonitors/hyprconfigs".source = ./hdm/hyprconfigs;
systemd.user.services.hyprdynamicmonitors-prepare = { ... };
systemd.user.services.hyprdynamicmonitors = { ... };
```

**Known issues**:
- **#152**: Non-atomic symlink swap (`os.Remove` + `os.Symlink`) races Hyprland's inotify config watcher → "source= globbing error" overlay at profile switch time. Fix: use atomic `rename()`. PR pending.
- **#145**: Callbacks hardcode `bash` path → fails on NixOS without `services.envfs`. Workaround: add `bash` to PATH in the systemd service, or add `envfs.enable = true`.
- **#116** (fixed in v1.3.10): Profile condition not registering after boot when state changes while powered off. Fixed by `hyprdynamicmonitors-prepare.service`.

**Scoring mechanics**: docked_lid_open and docked_lid_closed both score the same number of points (1 name_match × 10 + 3 description_match × 5 + 1 lid_state_match × 2 = 27). They disambiguate because `lid_state` is a mandatory condition — only one matches at a time. Undocked profiles (just eDP-1) score 12 (10 + 2).

**Community examples**:
- `nieomylnieja/dotfiles` (June 2026): Real NixOS+HDM integration with systemd services, replacing a custom 218-line monitor policy script. Uses `config.toml` + hyprconfigs, deploy via `home.file`, systemd managed daemon.
- `fiffeek/hyprdynamicmonitors/examples/lid-states`: Reference lid-state profile configuration with UPower D-Bus integration.

### 2. shikane (v1.1.0, nixpkgs v1.0.1)

**Config format**: TOML at `~/.config/shikane/config.toml`

```toml
[[profile]]
name = "docked-lid-open"
exec = ["notify-send shikane 'Profile docked-lid-open applied'"]
  [[profile.output]]
  search = ["n=eDP-1"]
  enable = true
  mode = "1920x1080@60"
  position = "4920,420"
  [[profile.output]]
  search = ["s=OTNQ4HA000101"]
  enable = true
  mode = "1920x1080@60"
  position = "0,420"
  transform = "90"
  [[profile.output]]
  search = ["s=U5B4GWF1"]
  enable = true
  mode = "1920x1080@60"
  position = "1080,420"
  [[profile.output]]
  search = ["s=GGZM3HA438259"]
  enable = true
  mode = "1920x1080@60"
  position = "3000,420"

[[profile]]
name = "docked-lid-closed"
  [[profile.output]]
  search = ["n=eDP-1"]
  enable = false
  # ... same externals at y=0
```

**HM module** (available in `nix-community/home-manager` release-25.11):
```nix
services.shikane = {
  enable = true;
  settings = {
    profile = [
      {
        name = "docked-lid-open";
        output = [ ... ];
      }
    ];
  };
};
```

**LID GAP**: shikane has no lid state awareness. Profiles match ONLY on connected displays. To handle the lid, you must:
1. Define two profiles that differ by whether eDP-1 is enabled (`enable = true/false`)
2. Use external lid detection: either keep a bindl in hyprland.conf or add a `systemd-logind` handler
3. Call `shikanectl switch <profile>` from the lid event handler

This adds complexity compared to HDM's native `lid_state = "Opened"/"Closed"` conditions.

**Advantages over HDM**:
- Deterministic matching algorithm (generates all variants, ranks by exactness)
- Home Manager module with TOML generation (no separate config.toml file needed)
- Ad-hoc profile switching via `shikanectl switch`
- Export current setup as config (`shikanectl export`)
- Generic wlr-output-management — works with any compositor (not Hyprland-locked-in)

**Disadvantages vs HDM**:
- No lid events — external dependency for lid handling
- No power state awareness
- No TUI for visual configuration
- No template system
- No fallback profile concept
- Nixpkgs package is v1.0.1 while upstream is v1.1.0

### 3. kanshi (v1.8.0)

**Verdict: NOT VIABLE for this use case.**

- No lid support (issue #56 closed as "won't fix")
- No HM module in nix-community/home-manager
- Stagnant maintenance (last commit ~5 months ago)
- `bindswitch + kanshictl switch` workaround is fragile — same problems as current stack
- Custom config format (not TOML, not Hyprland syntax)

## Community Examples Found

| Source | Type | Setup | Notes |
|--------|------|-------|-------|
| `nieomylnieja/dotfiles` (commit 689853c) | NixOS + HDM | Replaced 218-line custom monitor script with HDM | Working reference: systemd prepare + daemon services, config.toml + hyprconfigs via home.file, laptop-only + external-only profiles |
| `Haseeb Majid` blog post (Jul 2023) | NixOS + kanshi | `services.kanshi` with `systemdTarget = "hyprland-session.target"` | Pre-HDM era. Shows kanshi working on NixOS+Hyprland via HM options. No lid handling. |
| `fiffeek/hyprdynamicmonitors` examples/ | Reference | Lid states, full config, power states, templates | Official docs with complete examples |
| `rtorrero/hyprdynamicmonitors-gui` | GTK4 GUI fork of HDM | Drag-and-drop monitor layout + profile editing | Very new (June 27, 2026). Fork of HDM adding GUI. Not stable yet. |
| Arch Wiki `kanshi` page | Community doc | systemd service for sway-session.target, exec directives for workspace moves | Generic Wayland setup. No lid handling. |

## Cross-Reference with V2

### Where V2 and V3 Agree

1. **HDM is the best candidate.** V2 correctly identified HDM v1.4.0 as the primary candidate with native lid events, description matching, scoring, and static profile support for explicit coordinates.
2. **hyprdocked is dead.** Confirmed: repo is archived with 0 stars.
3. **kanshi lacks lid support.** Confirmed: issue #56 closed as won't fix.
4. **Scoring mechanics are correct.** V2's scoring analysis (docked profiles score 27, undocked 12) matches HDM docs.
5. **Static profiles support any Hyprland syntax.** Confirmed: `monitor = desc:...,1920x1080@60,0x420,1,transform,1` is valid in static hyprconfigs.
6. **Description-based matching is the right approach.** Confirmed working via `description = "AOC 24P1W1 OTNQ4HA000101"` matchers.
7. **Fallback syntax is `[fallback_profile]`** (not `[profiles.fallback]`). V2 had this right.

### Where V3 Extends V2

1. **shikane is now a stronger alternative** than V2 considered. V2 treated shikane as equivalent to kanshi. But:
   - shikane now has a **Home Manager module** (`services.shikane` in HM 25.11) — V2 didn't have this
   - shikane v1.1.0 (May 2026) is actively maintained
   - The HM module generates TOML natively — no separate config.toml file management
   - **However**: shikane still lacks lid events natively. The lid gap is fundamental.
   
2. **New HDM issues discovered** that V2 didn't document:
   - **#152 (non-atomic symlink swap)**: Real race condition at profile switch time. `os.Remove` + `os.Symlink` creates a window where Hyprland's inotify watcher sees the file disappear → "source= globbing error" overlay. Fix is `rename()` atomic swap. PR pending. **Mitigation**: Use `debounce_time_ms=1500` to reduce switch frequency; avoid `disable_autoreload=false`.
   - **#145 (NixOS bash path)**: HDM callbacks hardcode `/bin/bash` which doesn't exist on NixOS without `services.envfs`. Workaround: add `bash` to the systemd service PATH. Mitigation: we won't use callbacks (workspace rules stay in Nix, not in TOML).
   - **#151 (Hyprland Lua migration)**: Hyprland is moving to Lua config. HDM still outputs old-style `monitor =` directives. This works today but may need updating in the future.

3. **Working NixOS+HDM reference found**: `nieomylnieja/dotfiles` — validates the exact integration pattern V2 proposed (systemd prepare + daemon, config.toml + hyprconfigs via home.file, strip old daemon).

4. **HDM's prepare service (v1.3.10+)** was confirmed to fix V1 bug #1 (stale `monitor=...,disable` lines after boot when state changed while powered off). V2 mentioned this but V3 confirms it's working in the wild.

### Where V3 Disagrees or Adds Caution

V2 said "HDM uses native Hyprland IPC" — this is true, but #152 shows the symlink approach (writing to a `source =`-included file) has a subtle race. The atomic rename fix is pending. This is NOT a blocker but should be mentioned in the design as a risk.

V2 said `omarchy-hyprland-monitor-watch` race is "benign" — V3 agrees with `debounce_time_ms = 1500`, but adds the note that #152 could compound this if the socat listener triggers `hyprctl reload` during the symlink window.

## Approaches

### Approach 1: HyprDynamicMonitors (Recommended)

**Description**: Replace the entire custom stack with HDM v1.4.0. HDM runs as a systemd user daemon, watching Hyprland IPC for monitor events and UPower D-Bus for lid events. It matches the current set of connected monitors + lid state against TOML profiles, and writes/link the matching Hyprland config to a destination file that Hyprland `source =`-includes.

**Pros**:
- **Native lid events** — UPower D-Bus, no `/proc/acpi` polling, no bindl shell chains
- **Native monitor hotplug** — Hyprland IPC events, no `while true; do sleep 2` loop
- **Explicit coordinate profiles** — dead-zone y=420, eDP-1 at -30000x0, all via static hyprconfigs
- **Description-based matching** — EDID descriptions, not connector names
- **Scoring + fallback** — unambiguous profile selection even with 4 monitors
- **systemd-managed** — prepare service handles boot-time cleanup, daemon has restart-on-failure
- **Proven NixOS integration** — working reference in nieomylnieja/dotfiles
- **Shrinks codebase** — removes ~290 lines, replaces with ~80 lines of TOML + ~10 lines of Nix
- **In nixpkgs** — no custom flake input needed (package is in nixpkgs; module must come from flake)
- **Templates available** if we ever need dynamic config
- **TUI available** for visual adjustments without editing TOML

**Cons**:
- **Issue #152 (symlink race)**: Non-atomic profile switch can briefly show "globbing error" overlay. Mitigation: `debounce_time_ms=1500`, prepare service cleanup. Fix is pending upstream.
- **Issue #145 (NixOS callbacks)**: HDM hardcodes bash path for callbacks. Mitigation: don't use callbacks (workspace rules stay in Nix).
- **Hyprland-specific**: If T14 ever switches compositors, HDM stops working. But this is unlikely.
- **Module must come from flake input**: nixpkgs package doesn't include the HM module. Requires adding a flake input.
- **Future-proofing**: Hyprland is moving to Lua config (#151). HDM will need to update its output format eventually.

**Effort**: Medium. ~5 files to modify, ~4 files to create, ~3 files to delete.

**Dead-zone support**: ✅ Full. Static profiles are raw Hyprland `monitor =` directives. `0x420` positions work identically to the current stack.

### Approach 2: shikane + External Lid Handler

**Description**: Use shikane for monitor profile switching (TOML profiles with explicit monitor positions) and add a lightweight lid event handler (systemd-logind inhibitor or a minimal hyprland bindl) that calls `shikanectl switch` on lid events.

**Pros**:
- **Home Manager module** — `services.shikane` generates TOML natively, no separate config.toml file
- **Deterministic matching** — generates all profile variants, ranks by exactness, better matching than HDM's scoring-only approach
- **Not Hyprland-locked** — uses wlr-output-management protocol, works with any compositor
- **Ad-hoc switching** — `shikanectl switch` for runtime overrides
- **Export feature** — `shikanectl export` to capture current layout as a config profile
- **Maintained** — v1.1.0 from May 2026

**Cons**:
- **No lid events** — MUST add external lid detection. Options:
  a. Keep a minimal bindl (but this adds back the shell chain fragility)
  b. Use systemd-logind handle-lid-switch + a oneshot service calling `shikanectl switch`
  c. Use acpid (same ACPI fragility as current stack)
- **Two tools to maintain** — shikane + lid handler = more surface area
- **Lid state ambiguity** — shikane matches on connected displays only. If eDP-1 is enabled in both lid-open and lid-closed profiles, shikane can't tell them apart without the lid handler.
- **No fallback concept** — if no profile matches, shikane does nothing. HDM has `[fallback_profile]`.
- **No TUI** — visual adjustments require nwg-displays or manual editing
- **Nixpkgs lag** — package is v1.0.1, upstream is v1.1.0
- **No power state awareness**

**Effort**: Medium-High. More integration work (shikane + lid handler), more failure modes.

**Dead-zone support**: ✅ Full. `position = "0,420"` in profile output.

### Approach 3: Custom Nix-Generated Script (Stay with Current Pattern but Clean It Up)

**Description**: Keep the custom approach but refactor: replace the bash daemon with a more robust script, eliminate hyprlang conditionals, use `hyprctl` socket events instead of polling.

**Pros**:
- Full control
- No external tools to trust
- Can be as simple or complex as needed

**Cons**:
- **Reinventing the wheel** — HDM already solved all these problems
- **Maintenance burden** — we write and maintain the monitor management logic
- **More code** — a socket2-based script is still ~50-100 lines + Nix wiring
- **No community** — nobody else uses our custom script
- **Lid handling still needs external code** — either `/proc/acpi` (fragile) or UPower D-Bus (complex in bash)

**Effort**: High. Writing a robust socket2-based monitor manager from scratch.

**Dead-zone support**: ✅ Full. We control the script.

## Recommendation

**HyprDynamicMonitors is the recommended approach.** 

**Evidence**:
1. It's the only tool with **native lid event support** via UPower D-Bus — no external lid handler needed
2. It's the only tool with **native Hyprland IPC** for monitor hotplug — event-driven, not polling
3. **Static profiles support explicit coordinates** — dead-zone y=420 and eDP-1 at -30000x0 are first-class
4. **Description-based matching** is stable across kernel updates (connector names change, EDID doesn't)
5. **Scoring system** disambiguates docked/undocked profiles naturally
6. **Fallback profile** covers unknown monitor sets (safety net)
7. **systemd integration** is documented and proven (prepare + daemon services)
8. **Working NixOS reference** exists (nieomylnieja/dotfiles)
9. **V1 bugs are addressed by construction**: V2 analysis validated all 6 bugs can be fixed
10. **Shrinks codebase by ~250 lines** — less to maintain, fewer failure modes

**Why not shikane**: The lid gap is fundamental. Adding external lid detection to shikane means keeping a bindl or adding another service — this adds back the fragility we're trying to eliminate. shikane's HM module is nice, but the lid problem negates its advantage.

**Why not the current pattern**: The custom stack is fragile for the reasons documented above. Refactoring it doesn't solve the fundamental problem that we're writing and maintaining monitor management code instead of using a purpose-built tool.

**Mitigation for HDM issues**:
- **#152 (symlink race)**: Use `debounce_time_ms = 1500`, prepare service, and `disable_autoreload = false` (default). The race is timing-dependent and the fix is pending upstream.
- **#145 (NixOS callbacks)**: Don't use callbacks. Workspace rules stay in Nix `wayland.windowManager.hyprland.settings.workspace`. Only monitor directives go through HDM.
- **#151 (Lua migration)**: Monitor directive format (`monitor = desc:...,1920x1080@60,0x420,1`) is valid in both old and new Hyprland config. HDM output is forward-compatible.
- **Flake input**: Required for the HM module. The package alone (`pkgs.hyprdynamicmonitors`) is not enough — the module provides `homeManagerModules.default`.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| HDM #152 symlink race causes "globbing error" overlay | Medium | Low (cosmetic, self-healing on next event) | `debounce_time_ms=1500`, prepare service cleanup, monitor upstream fix |
| HDM #145 NixOS callback bash path | Low (we won't use callbacks) | None | Workspace rules stay in Nix, not in TOML callbacks |
| `omarchy-hyprland-monitor-watch` race with HDM | Low | Low (benign extra reload) | HDM debounce absorbs; `hyprctl reload` re-parses including latest HDM output |
| EDID description changes on monitor replacement | Low | Medium (wrong profile selected) | Fallback profile covers unknown sets; user updates TOML descriptions |
| UPower regression breaks lid events | Low | High (lid events stop working) | UPower already enabled in `modules/hardware/amd-laptop.nix`; add Nix assertion |
| Hyprland Lua migration breaks HDM output format | Low (monitor directives unchanged) | Low | `monitor =` syntax is valid in both old and new format |
| Flake input creates circular/version conflicts | Low | Medium (build failure) | HDM flake uses `inputs.nixpkgs.follows = "nixpkgs"`; version-compatible with hyprland in omarchy-nix |
| Double workspace bindings (V1 BUG 6) | Medium | High (Super+1/2/3 broken) | Filter `mkWorkspaceRules` to `w > 3` — external-only workspaces. eDP-1 ws 1-3 move to a conditional Nix block or separate config |
| omarchy.monitors = ["eDP-1,preferred,auto,1"] conflicts with HDM generated config | Medium | High (monitor directive defined twice) | HDM overwrites via `source =` which is parsed after `settings.monitor`. Test carefully; may need to set `omarchy.monitors = []` or override with `lib.mkForce` |

## Ready for Proposal

**Yes.** All research questions are answered. All tools are evaluated. The recommendation is clear and evidence-backed. Cross-reference with V2 confirms and extends the previous analysis.

The proposal should address:
1. HDM as the chosen tool with evidence
2. Flake input addition and HM module wiring
3. TOML profile design (4 profiles + fallback) with scoring analysis
4. Static hyprconfigs with explicit dead-zone y=420 and eDP-1 at -30000x0
5. Removal plan for the old stack (daemon, bindls, hyprlang ifs, settings.conf, udev drop-in, validator script)
6. Workspace rule redesign (ws 1-3 eDP-1, ws 4-20 externals, no double default:true)
7. HDM issue mitigations (#152, #145)
8. Rollback plan
9. Test matrix (4 states × workspace keys × connector stability)
