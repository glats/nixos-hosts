# SDD Session Prompt — t14-hdm-migration-v2

**For**: New SDD session (do NOT execute in this session)
**Save to**: Engram `sdd/t14-hdm-migration-v2/preflight` + openspec `openspec/changes/t14-hdm-migration-v2/`
**Predecessor**: `FAILED-2026-06-29-hyprdynamicmonitors-migration-v1` (archived with POSTMORTEM)

---

## SDD Session Preflight

### Change: t14-hdm-migration-v2

Replace the T14's fragile custom monitor stack (~290 lines of bash daemon + hyprlang
conditionals + 300-char bindls + settings.conf + udev drop-in) with a robust, event-driven
approach. The primary candidate is HyprDynamicMonitors v1.4.0 (Go daemon in nixpkgs, native
Hyprland IPC, UPower lid events, TOML profiles). If HDM proves unsuitable during exploration,
fall back to hyprdocked (dsrosen6/hyprdocked, Rust, requires Hyprland ≥0.55) or explore
other tools discovered via exa + GitHub MCP.

### Execution Mode
- **guided** (auto-chain phases, pause before apply)

### Artifact Store
- **hybrid** (Engram + openspec)

### Delivery
- **no-pr** (commit directly to master)

### Review Budget
- **standard** (nix flake check, format-nix, grep basics)

---

## REPOSITORY CONTEXT

- **nixos-hosts** (`github.com/glats/.nixos`): Multi-host NixOS + Home Manager + nix-darwin configuration. T14 is `hosts/t14/`. Stack: NixOS flakes, Omarchy (Hyprland-based desktop), sops-nix, nixos-hardware.
- **omarchy-nix** (`github.com/glats/omarchy-nix`): The user OWNS this repo (full clone + push access). Changes involving omarchy-nix can be committed and pushed directly.
- **Auth**: Use `~/.git-credentials` for git push/pull. The user is `glats` on GitHub.
- **Patterns**: Follow existing project conventions — NixOS module imports via `mkHost.nix`, Home Manager via `home-manager.users.glats.imports`, flake inputs with `inputs.*.follows = "nixpkgs"`, `format-nix` for formatting, `nixos-build` for switching.

---

## FEATURES TO PRESERVE

### Monitor Layout — Current Known-Good Configuration

| Monitor | Connector | Resolution | Docked+Lid-Open Position | Transform | Notes |
|---------|-----------|------------|--------------------------|-----------|-------|
| T14 built-in | eDP-1 | preferred | 4920x420 (rightmost slot) | none | Laptop panel |
| AOC 24P1W1 | DP-* (varies) | 1920x1080@60 | 0x420 | transform,1 | Rotated portrait (1080×1920 effective) |
| Lenovo G24-10 | DP-* (varies) | 1920x1080@60 | 1080x420 | none | |
| AOC 2470W | DP-* (varies) | 1920x1080@60 | 3000x420 | none | |

**Connector names are variable**: On this T14 they changed from DP-3/4/5 to DP-6/7/8 after a
kernel or hardware update. The `desc:` identifier (EDID-based) is stable — always use
`desc:AOC 24P1W1 OTNQ4HA000101` etc. in Hyprland monitor config lines.

### Dead-Zone Fix (y=420)

The AOC 24P1W1 is physically rotated to portrait mode (`transform,1`). After rotation its
effective dimensions are 1080×1920, spanning y=0 to y=1919. The three horizontal monitors
(DP-4, DP-3, eDP-1) are 1920×1080 each, positioned at y=420 to vertically center them with
the rotated monitor. Without y=420, the cursor cannot cross between the rotated monitor and
the horizontals — a "dead zone" appears.

**Requirement**: Preserve y=420 for horizontals when docked + lid open, BUT ONLY IF the
chosen tool (HDM, hyprdocked, etc.) supports explicit coordinate positioning. If the tool
only does auto-placement, the dead-zone fix must be implemented as a complementary mechanism
(e.g., post-apply script, template with coordinates, or separate hyprctl keyword calls).
DO NOT sacrifice the dead-zone fix for tool simplicity.

### Layout States

| State | eDP-1 | External Monitors |
|-------|-------|-------------------|
| Docked + lid open | enabled at 4920x420 | all 3 at y=420 |
| Docked + lid closed | parked off-screen (-30000x0, NOT disabled) | all 3 at y=0 |
| Undocked + lid open | enabled at 0x0 | none |
| Undocked + lid closed | enabled at 0x0 (pre-suspend) | none |

**Off-screen park vs disable**: eDP-1 must be PARKED at negative coordinates (e.g., -30000x0)
rather than DISABLED. Hyprland issue #1274: `monitor:disable` removes the display from the
compositor state entirely. When re-docking, the panel cannot be re-enabled. Park + DPMS off
keeps the monitor registered with Hyprland.

### Workspace Distribution (mod-3, 20 workspaces total)

| Monitor | Workspaces |
|---------|-----------|
| AOC 24P1W1 (rotated) | 4, 7, 10, 13, 16, 19 |
| Lenovo G24-10 | 5, 8, 11, 14, 17, 20 |
| AOC 2470W | 6, 9, 12, 15, 18 |
| eDP-1 (laptop) | 1, 2, 3 |

Workspaces 1-3 are ALWAYS on eDP-1 (persistent, default). Workspaces 4-20 are distributed
across the 3 external monitors. When undocked, only workspaces 1-3 should be active.

### Other Preserved Settings (DO NOT TOUCH)

- `GDK_SCALE=1` — no HiDPI scaling on the 1920x1080 panel
- `omarchy.greeter.*` — COMPLETELY SEPARATE. ReGreet login screen runs as `greeter` user with its own generated `/etc/greetd/hyprland.conf`. Has its own `focusMonitor`, `keyboard.layouts`, `monitors`, `cursor.theme`, `wayvnc`. HDM or any replacement MUST NOT affect the greeter session.
- `omarchy.hyprland.lidSwitch.enable = false` — prevents dual-writer race between omarchy's default lid bindl and T14's custom handler. MUST remain.
- `omarchy.monitors = ["eDP-1,preferred,auto,1"]` — harmless omarchy-level fallback. Leave as-is.
- `omarchy-hyprland-monitor-watch` — exec-once socat listener that calls `hyprctl reload` on monitoradded events. Orthogonal to HDM, should not conflict.
- UPower — already enabled on T14 via `power-profiles-daemon` in `modules/hardware/amd-laptop.nix`.

---

## EXPLORATION PHASE REQUIREMENTS

The explore phase MUST use these tools to research before proposing any approach:

1. **exa (web search)**: Search for HyprDynamicMonitors examples, configurations, known issues, and best practices. Search for hyprdocked, kanshi, and any other dock/lid management tools for Hyprland.

2. **github MCP**: Search for HyprDynamicMonitors issues, PRs, example configs (the repo has an `examples/` directory with lid-states, basic, full, scoring, power-states). Search for hyprdocked (dsrosen6/hyprdocked) and EndoliteMatrix/hyprland-dock-undock-automation.

3. **context7**: Query the HyprDynamicMonitors documentation (library ID: `/fiffeek/hyprdynamicmonitors` or from the project's doc site at `hyprdynamicmonitors.filipmikina.com`). Understand:
   - How `required_monitors` matching works (by `name` vs `description` vs `monitor_tag`)
   - How `match_description_using_regex` works
   - How profile scoring/selection works (first match? highest score?)
   - How `[fallback_profile]` differs from `[profiles.*]`
   - How `[scoring]` weights affect profile selection
   - How lid events work (UPower D-Bus configuration)
   - Whether static profiles support explicit coordinates (not just templates)

4. **nixos MCP**: Verify `hyprdynamicmonitors` is in nixpkgs, check its version, check if it has NixOS and Home Manager modules, verify the flake structure.

### Exploration Goals

- Determine whether HDM supports explicit coordinate positioning in static profiles (CRITICAL for dead-zone fix)
- Determine how HDM's profile matching works (validate or disprove the "bugs" from v1 below)
- Find example configs for multi-monitor + lid-aware setups
- Evaluate hyprdocked as an alternative (Rust, IPC-native, lid-aware, suspend-safe)
- Determine the best approach for integrating with omarchy-nix conventions

---

## KNOWN ISSUES FROM v1 (TO VALIDATE, NOT BLINDLY FIX)

These were encountered during the failed v1 migration. The explore phase MUST validate each
one against current HDM documentation and actual T14 hardware before assuming they're real
bugs. Some may be misunderstandings of HDM's behavior.

### Issue 1 — Tilde in Hyprland source directive
`source = ~/.config/...` may not expand `~` in Hyprland config. Use absolute path from
`config.home.homeDirectory` as a precaution regardless.

### Issue 2 — home.file clobber
Using `home.file` for a path that HDM also writes to at runtime causes "would be clobbered"
on next HM activation. Use `home.activation` with existence guard `[ ! -f "$file" ]`.

### Issue 3 — Profile monitor matching
We used `name = "desc:AOC..."` which may be incorrect — HDM may match by connector name or
description field, not `desc:` prefix. **Validate against HDM docs and actual `hyprctl monitors -j` output on T14.**

### Issue 4 — Fallback profile syntax
We used `[profiles.fallback]` but HDM may expect `[fallback_profile]`. **Validate against
HDM documentation.**

### Issue 5 — Profile scoring
Multiple profiles can match the same state (e.g., docked+lid-open matches both `docked_lid_open`
and `undocked_lid_open`). **Validate HDM's profile selection algorithm** and add `[scoring]`
weights if needed.

### Issue 6 — Workspace rule merging in Hyprland 0.55
`mkWorkspaceRules` binds workspaces 1-3 to external monitors. `extraConfig` also binds them
to eDP-1. Hyprland 0.55 may merge rather than override. **Validate**: filter `w > 3` from
mkWorkspaceRules as a precaution.

### Issue 7 — hyprctl reload causes visual flicker
`hyprctl reload` in the polling daemon caused visible resets. HDM should not have this issue
(since it uses IPC natively), but verify.

### Issue 8 — moveworkspacetomonitor syntax
Uses space not comma: `hyprctl dispatch moveworkspacetomonitor "1 eDP-1"`. Verify on T14.

### Issue 9 — Connector name instability
DP-3/4/5 became DP-6/7/8. Always use description-based matching, never hardcode connector
names in HDM profiles.

---

## FILES TO MODIFY

| File | Action |
|------|--------|
| `flake.nix` | Add tool flake input (HDM, hyprdocked, etc.) + wire module |
| `hosts/t14/default.nix` | Import tool's HM/NixOS module. KEEP omarchy block untouched. |
| `hosts/t14/home/default.nix` | Add tool config. REMOVE: validator service, seed activation, udev drop-in, validator home.file. |
| `hosts/t14/home/hypr/monitors.nix` | Filter w>3 from mkWorkspaceRules. Replace extraConfig with `source` directive + workspace 1-3 eDP-1 bindings. Keep GDK_SCALE. |
| `hosts/t14/home/scripts/monitor-lid-validator.sh` | DELETE (replaced by tool) |
| `hosts/t14/hdm/config.toml` | NEW (if HDM) — 4 profiles + [fallback_profile] + [scoring] + [lid_events] |
| `hosts/t14/hdm/hyprconfigs/*.conf` | NEW (if HDM) — static Hyprland config per profile |
| `docs/t14-monitor-layout.md` | Update to reflect new architecture |

## RELEVANT CONTEXT FILES (READ THESE)

- `docs/t14-monitor-layout.md` — dead-zone documentation, connector reference
- `openspec/changes/archive/FAILED-2026-06-29-abri-el-lid-black-screen/POSTMORTEM.md` — 4 bugs from custom daemon approach
- `openspec/changes/archive/FAILED-2026-06-29-hyprdynamicmonitors-migration-v1/POSTMORTEM.md` — 6 bugs from HDM v1 approach
- `session-ses_0e9e.md` — full debugging session transcript (2863 lines)
- Engram: search `sdd/t14` for all previous SDD artifacts
