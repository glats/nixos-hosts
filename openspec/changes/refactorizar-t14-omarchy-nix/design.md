# Design: refactorizar-t14-omarchy-nix

## Technical Approach

Pure configuration refactor in 5 commits. Each commit is independently `git revert`-able. No new logic in this repo — only deletions, opt-in moves to upstream `omarchy.*` options, and one upstream module addition (wayvnc). The key mechanical insight: omarchy-nix's HM module already uses `mkDefault` for input/looknfeel, so t14's `mkForce` overrides will continue to work unchanged — we just stop deleting/redeploying files that upstream already provides.

**Commit ordering rationale**: Commit 1 must land first (upstream). Commits 2–5 are sequential because each deletes files that later commits' imports reference (e.g., commit 3 removes `./ghostty.nix` from imports, commit 4 removes waybar config that commit 3's `home.file` drops depend on).

## Diff Plan (per commit)

### Commit 1 — Upstream: wayvnc module + osConfig fix (omarchy-nix repo)

**Repository**: `github:glats/omarchy-nix` (NOT this repo)

#### New file: `modules/nixos/wayvnc.nix` (~35 lines)

```nix
{ config, lib, pkgs, ... }:
let cfg = config.omarchy.wayvnc;
in {
  config = lib.mkIf cfg.enable {
    programs.wayvnc.enable = true;
    # PAM auth requires wayvnc in systemPackages for the PAM stack
    environment.systemPackages = [ pkgs.wayvnc ];
  };
}
```

#### New file: `modules/home-manager/wayvnc.nix` (~45 lines)

Mirror of current `hosts/t14/home/wayvnc/default.nix`, but gated by `omarchy.wayvnc.enable`:

```nix
{ config, lib, pkgs, ... }:
let cfg = config.omarchy.wayvnc;
in {
  config = lib.mkIf cfg.enable {
    xdg.configFile."wayvnc/config".text = ''
      use_relative_paths=true
      address=0.0.0.0
      port=${toString cfg.port}
      enable_pam=${lib.boolToString cfg.enable_pam}
    '';
    systemd.user.services.wayvnc = {
      Unit = { Description = "wayvnc VNC server for Wayland";
               After = [ "graphical-session.target" ];
               PartOf = [ "graphical-session.target" ]; };
      Service = { Type = "simple";
                  PassEnvironment = [ "WAYLAND_DISPLAY" "XDG_RUNTIME_DIR" "DISPLAY" ];
                  ExecStartPre = "${pkgs.bash}/bin/bash -c 'pkill wayvnc 2>/dev/null || true'";
                  ExecStart = "${pkgs.wayvnc}/bin/wayvnc";
                  Restart = "on-failure"; RestartSec = 5; };
      Install = { WantedBy = [ "graphical-session.target" ]; };
    };
  };
}
```

#### Edit: `modules/nixos/default.nix`

Add `./wayvnc.nix` to the imports list (after `./hardware.nix`).

#### Edit: `modules/home-manager/default.nix`

Add `(import ./wayvnc.nix inputs)` to the imports list.

#### Edit: `config.nix` — add wayvnc option block

Add to `omarchyOptions`:

```nix
wayvnc = lib.mkOption {
  type = lib.types.submodule {
    options = {
      enable = lib.mkOption { type = lib.types.bool; default = false; };
      port = lib.mkOption { type = lib.types.port; default = 5900; };
      enable_pam = lib.mkOption { type = lib.types.bool; default = true; };
    };
  };
  default = {};
};
```

#### Edit: `flake.nix:55` — osConfig fix (1 line)

**Before** (line 55):
```nix
osConfig ? {},
```

**After**:
```nix
osConfig ? {},
```

The actual fix is in the `config` block (line 58-60):

**Before**:
```nix
config = lib.mkIf (osConfig ? omarchy) {
  omarchy = osConfig.omarchy;
};
```

**After**:
```nix
config = lib.mkIf (osConfig ? omarchy) {
  omarchy = osConfig.omarchy or {};
};
```

This prevents `pushDownProperties` from forcing evaluation of `osConfig.omarchy` when it doesn't exist (the standalone HM crash). The `or {}` makes the attr access lazy-safe.

#### Verify: `nix flake check --no-build` in omarchy-nix

---

### Commit 2 — Move wayvnc upstream + delete osConfig workaround (this repo)

**Net: ~55 lines deleted, ~5 lines added**

#### Edit: `flake.nix:19-22` — bump omarchy-nix input ref

**Before**: `url = "github:glats/omarchy-nix/main";` (pinned to `d6f0163...`)
**After**: Same URL, but `flake.lock` updated to Commit 1's new rev.

#### Edit: `hosts/t14/default.nix:94` — delete `programs.wayvnc.enable`

Delete line 94: `programs.wayvnc.enable = true;`

#### Edit: `hosts/t14/default.nix:117-148` — add wayvnc to omarchy block

Add inside the `omarchy = { ... };` block (after `firewall.enable = false;`):

```nix
wayvnc.enable = true;
```

#### Delete: `hosts/t14/home/wayvnc/default.nix` (51 lines)

Entire file deleted.

#### Edit: `hosts/t14/home/default.nix:33` — remove wayvnc import

Delete line 33: `./wayvnc`

#### Edit: `flake.nix:269-285` — delete osConfig workaround

**Before** (lines 269-285):
```nix
{
  _module.args.osConfig = nixpkgs.lib.mkForce {
    omarchy = { };
    services.xserver.videoDrivers = [ ];
  };
  omarchy = {
    theme = "glats";
    username = "glats";
    ...
  };
}
```

**After**:
```nix
{
  omarchy = {
    theme = "glats";
    username = "glats";
    full_name = "Glats";
    email_address = "glats@local";
    browser = "brave";
    terminal = "ghostty";
    monitors = [ "eDP-1,preferred,auto,1" ];
    scale = 1;
    light_theme_detection.enable = false;
    wayvnc.enable = true;
  };
}
```

The `_module.args.osConfig = mkForce { ... }` block is deleted entirely. The `omarchy = { ... }` block stays (standalone HM still needs the values) with `wayvnc.enable = true` added.

#### Verify: `nix flake check --no-build` + `nixos-build dry` + `hms` standalone build

---

### Commit 3 — Delete pure-duplicate files

**Net: ~230 lines deleted, 0 added**

#### Delete: `hosts/t14/home/hypr/xdph.nix` (31 lines)

Byte-identical to upstream `omarchy-nix:modules/home-manager/xdph.nix`.

#### Delete: `hosts/t14/home/ghostty.nix` (17 lines)

Only imports `home-linux/ghostty.nix` — no t14 delta.

#### Delete: `hosts/t14/home/scripts/window-switcher.sh` (18 lines)

Replaced by `omarchy-launch-walker -m windows` (already on PATH).

#### Delete: `hosts/t14/home/scripts/monitor-hotplug-handler.sh` (91 lines)

Superseded by upstream `omarchy-hyprland-monitor-watch`.

#### Delete: `hosts/t14/home/hypr/autostart.nix` (17 lines)

Empty file (only comments).

#### Edit: `hosts/t14/home/default.nix:21-34` — update imports

**Before** (lines 21-34):
```nix
imports = [
  ./hypr/monitors.nix
  ./hypr/input.nix
  ./hypr/bindings.nix
  ./hypr/looknfeel.nix
  ./hypr/autostart.nix      # DELETE this line
  ./hypr/hyprlock.nix
  ./hypr/hyprsunset.nix
  ./hypr/xdph.nix           # DELETE this line
  ./ghostty.nix              # DELETE this line
  ../../../home-linux/kitty.nix
  ./mouse-wiggle.nix
  ./wayvnc                   # Already deleted in commit 2
];
```

**After**:
```nix
imports = [
  ./hypr/monitors.nix
  ./hypr/input.nix
  ./hypr/bindings.nix
  ./hypr/looknfeel.nix
  ./hypr/hyprlock.nix
  ./hypr/hyprsunset.nix
  ../../../home-linux/kitty.nix
  ./mouse-wiggle.nix
];
```

#### Edit: `hosts/t14/home/default.nix:39-80` — remove deleted script drops

**Delete** lines 39-50 (window-switcher.sh and monitor-hotplug-handler.sh `home.file` drops).

**Keep** lines 52-79 (kb-toggle.sh, kb-layout.sh, and `.config/hypr/` symlinks — these stay).

**After** (lines 39-63 become):
```nix
home.file = {
  # Keyboard layout toggle (es <-> latam)
  ".local/share/omarchy/bin/kb-toggle.sh" = {
    source = ./scripts/kb-toggle.sh;
    executable = true;
  };
  ".local/share/omarchy/bin/kb-layout.sh" = {
    source = ./scripts/kb-layout.sh;
    executable = true;
  };
  ".config/hypr/kb-layout.sh" = {
    source = ./scripts/kb-layout.sh;
    executable = true;
  };
  ".config/hypr/kb-toggle.sh" = {
    source = ./scripts/kb-toggle.sh;
    executable = true;
  };
};
```

#### Verify: `nix flake check --no-build`

---

### Commit 4 — Trim waybar override to iwd-wifi only

**Net: ~200 lines deleted, 0 added**

#### Edit: `hosts/t14/home/default.nix:104-346` — delete waybar config override

**Delete** lines 104-346 (the entire `xdg.configFile."waybar/config" = lib.mkForce { ... };` block).

This is ~243 lines of near-identical waybar JSON config. Upstream `omarchy-nix:modules/home-manager/waybar.nix` deploys the raw config file from `config/waybar/config` (preserving the U+E900 NerdFont icon that `formats.json` strips).

**Keep** lines 89-102 (the `home.file.".config/waybar/indicators/iwd-wifi.sh"` drop).

**The iwd-wifi module in waybar's `modules-right`**: The upstream waybar config does NOT include `custom/iwd-wifi` in its `modules-right`. Two options:
1. **Accept missing iwd-wifi indicator** — the upstream `network` module shows WiFi via NetworkManager, which doesn't work with standalone-iwd. The iwd-wifi.sh script still deploys but isn't referenced by the bar.
2. **Patch upstream waybar config** — add `custom/iwd-wifi` to the upstream `config/waybar/config` file's `modules-right`, gated by a conditional or just always present (harmless if the script doesn't exist).

**Decision**: Option 2 is out of scope for this repo. For now, accept option 1 — the iwd-wifi indicator is a "nice to have" and the user can manually add it to the upstream waybar config in a follow-up. The script still deploys via `home.file`.

**After** (lines 82-102 become):
```nix
# ------------------------------------------------------------------
# Waybar — iwd WiFi status indicator
# ------------------------------------------------------------------
# omarchy-nix owns the waybar config. We add only the iwd-wifi
# indicator script (iwd-specific, not in upstream). The script
# deploys but is not yet referenced by upstream's waybar modules-right
# (follow-up: patch upstream waybar config to include custom/iwd-wifi).
home.file.".config/waybar/indicators/iwd-wifi.sh" = {
  text = ''
    #!/bin/bash
    state=$(iwctl station wlan0 show 2>/dev/null | awk '/State/ {print $2}')
    ssid=$(iwctl station wlan0 show 2>/dev/null | awk '/Connected network/ {$1=""; $2=""; print}' | xargs)
    if [ "$state" = "connected" ] && [ -n "$ssid" ]; then
      echo "{\"text\": \" $ssid\", \"class\": \"connected\", \"tooltip\": \"WiFi: $ssid (iwd)\"}"
    else
      echo "{\"text\": \"󰤮\", \"class\": \"disconnected\", \"tooltip\": \"WiFi disconnected\"}"
    fi
  '';
  executable = true;
};
```

#### Side-effect: NerdFont U+E900 icon auto-fixed

Upstream's `waybar.nix` deploys `config/waybar/` as a raw recursive directory copy (`home.file.".config/waybar/" = { source = ../../config/waybar; recursive = true; };`). The config file is NOT generated via `pkgs.formats.json` (which strips non-encodable chars). The `custom/omarchy` module's `<span font='omarchy'>\ue900</span>` renders correctly.

#### Verify: `nix flake check --no-build` + `nixos-build dry`

---

### Commit 5 — Final audit: bindings + input trim

**Net: ~80 lines deleted, ~15 lines remain**

#### Delete: `hosts/t14/home/hypr/bindings.nix` (50 lines)

All 5 bindings are duplicates:
- `SUPER, Q` → `window-switcher.sh` — script deleted in commit 3; upstream has `omarchy-launch-walker -m windows`
- `SUPER, M` → `window-switcher.sh` — same
- `switch:on/off:Lid Switch` — upstream has `omarchy-hyprland-monitor-internal toggle` on `SUPER CTRL DELETE`
- `SUPER SHIFT, R` → `wofi --show run` — intentional override of upstream's `SUPER, R` calculator, but wofi is not in omarchy's package set
- `SUPER ALT, RETURN` → tmux — byte-identical to upstream `bindings.nix` tmux binding
- `SUPER ALT SHIFT, F` → file manager cwd — byte-identical to upstream

**Decision**: Delete the entire file. The `SUPER SHIFT, R` → wofi override is dropped (wofi is not installed; upstream's `SUPER, R` calculator works). If the user wants wofi, it should be added to `home.packages` in a separate change.

#### Edit: `hosts/t14/home/default.nix:23` — remove bindings import

Delete line: `./hypr/bindings.nix`

#### Edit: `hosts/t14/home/hypr/input.nix` — trim to kb_layout only

**Before** (107 lines): Full input config with touchpad, gestures, windowrules, opacity override.

**After** (~15 lines):
```nix
# T14 Hyprland input — keyboard layout override only.
# All other input settings (touchpad, gestures, windowrules, opacity)
# are owned by omarchy-nix upstream and match t14's needs.
{ lib, ... }:

{
  wayland.windowManager.hyprland.settings = {
    input = {
      # Chile: es (Spain) + latam (Latin America); Alt+Shift toggles.
      # mkForce required because omarchy's input.nix sets kb_layout = "us".
      kb_layout = lib.mkForce "es,latam";
      kb_options = lib.mkForce "grp:alt_shift_toggle,compose:caps";
    };
  };
}
```

**Deleted from input.nix**:
- Lines 43-49: touchpad block (matches upstream defaults: `natural_scroll`, `scroll_factor = 0.4`)
- Lines 52-57: repeat_rate/delay/follow_mouse/sensitivity/numlock/accel_profile (all match upstream `mkDefault` values)
- Lines 64-66: `cursor.no_hardware_cursors` (upstream looknfeel.nix doesn't set this, but it's a personal preference — **KEEP or DELETE?** Decision: DELETE — it's not t14-specific, and software cursors break screen recording. If needed later, push upstream.)
- Line 74: gesture syntax `"3, horizontal, workspace"` (matches upstream's gesture handling)
- Lines 85-96: windowrules (upstream already has identical scroll_touchpad rules in `extraConfig`; the float picker and steam rules are personal — **Decision: DELETE** — they can be re-added as `omarchy.hyprland.windowrules` upstream if needed)
- Lines 104-106: opacity override via `mkAfter extraConfig` (upstream `windows.nix` sets opacity 0.97/0.90; the override makes everything 1.0. **Decision: DELETE** — accept upstream's slight transparency. If opaque is critical, push `omarchy.hyprland.opacity_default` upstream.)

#### Verify: `nix flake check --no-build` + `nixos-build dry`

---

## Upstream Changes (Commit 1) — Summary

| File | Action | Lines |
|------|--------|------:|
| `omarchy-nix:modules/nixos/wayvnc.nix` | Create | +35 |
| `omarchy-nix:modules/home-manager/wayvnc.nix` | Create | +45 |
| `omarchy-nix:modules/nixos/default.nix` | Edit (add import) | +1 |
| `omarchy-nix:modules/home-manager/default.nix` | Edit (add import) | +1 |
| `omarchy-nix:config.nix` | Edit (add wayvnc options) | +12 |
| `omarchy-nix:flake.nix:58-60` | Edit (osConfig or {}) | +1/-1 |
| **Total** | | **+94/-1** |

## Local Changes (Commits 2-5) — Summary

| Commit | Files deleted | Files edited | Lines Δ |
|--------|-------------:|-------------:|--------:|
| 2 | 1 (`wayvnc/default.nix`) | 3 (`flake.nix`, `default.nix` ×2) | -55, +5 |
| 3 | 5 (`xdph.nix`, `ghostty.nix`, `autostart.nix`, `window-switcher.sh`, `monitor-hotplug-handler.sh`) | 1 (`home/default.nix`) | -225 |
| 4 | 0 | 1 (`home/default.nix`) | -243 |
| 5 | 1 (`bindings.nix`) | 1 (`input.nix`) | -92, +15 |
| **Total** | **7** | **6** | **-615, +20** |

## Preserved Files (unchanged across all commits)

| File | Lines | Reason |
|------|------:|--------|
| `hosts/t14/hardware-configuration.nix` | 35 | Auto-generated (INV-1) |
| `hosts/t14/secrets.nix` | 7 | sops placeholders (INV-3) |
| `hosts/t14/default.nix:61-110` | 50 | hostName, XKB latam, boot/xfs (INV-1,5,7) |
| `hosts/t14/default.nix:117-148` | 32 | omarchy config block (identity) |
| `hosts/t14/default.nix:150-228` | 79 | Portal overrides (STAY — not in scope) |
| `hosts/t14/home/hypr/monitors.nix` | 57 | desc:-based physical monitor IDs |
| `hosts/t14/home/hypr/hyprlock.nix` | 65 | t14-local mkForce (user decision) |
| `hosts/t14/home/hypr/hyprsunset.nix` | 59 | t14-local mkForce (user decision) |
| `hosts/t14/home/hypr/looknfeel.nix` | 48 | t14-local mkForce (user decision) |
| `hosts/t14/home/omarchy.nix:113-174` | 62 | hypridle, gtk, copyScreensaverTxt (user decision) |
| `hosts/t14/home/scripts/kb-*.sh` | 58 | Chile 2-layout cycling |
| `hosts/t14/home/mouse-wiggle.nix` | 60 | Custom utility |

## Verification (per commit)

| Commit | `nix flake check --no-build` | `nixos-build dry` | `hms` standalone | Runtime |
|--------|:---:|:---:|:---:|---------|
| 1 (upstream) | ✅ | n/a | n/a | — |
| 2 (wayvnc+osConfig) | ✅ | ✅ | ✅ (workaround removed) | `systemctl --user status wayvnc` |
| 3 (dup deletes) | ✅ | — | — | — |
| 4 (waybar trim) | ✅ | ✅ | — | waybar renders, U+E900 visible |
| 5 (final audit) | ✅ | ✅ | — | `hyprctl getoption input:kb_layout` = `es,latam` |

**Universal invariant check (every commit)**:
```bash
git diff HEAD~1 -- hosts/t14/hardware-configuration.nix | wc -l  # MUST be 0
git diff HEAD~1 -- .sops.yaml hosts/t14/secrets.nix | wc -l      # MUST be 0
```

## Open Questions

- [ ] **iwd-wifi waybar integration**: The iwd-wifi indicator script deploys but isn't in upstream's `modules-right`. Accept as-is, or patch upstream waybar config in a follow-up?
- [ ] **cursor.no_hardware_cursors**: Deleted from input.nix (not t14-specific). Re-add if screen recording breaks.
- [ ] **windowrules (float picker, steam workspace)**: Deleted from input.nix. Re-add as `omarchy.hyprland.windowrules` upstream if needed.
- [ ] **opacity override**: Deleted from input.nix. Accept upstream's 0.97/0.90 transparency, or push `omarchy.hyprland.opacity_default` upstream?
