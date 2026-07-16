# Design: regreeter-keyboard-layout

## Technical Approach

Add a waybar-based keyboard layout indicator to the t14 greeter Hyprland session. A new `omarchy.greeter.layoutIndicator` submodule in omarchy-nix generates a minimal waybar config and wires it into the greeter compositor via `exec-once`. The custom waybar module polls `hyprctl devices -j` every 1s to display the active layout name ("ES" or "LATAM") in a 24px bottom bar.

Two-repo change: omarchy-nix (config generation) + nixos-hosts (host enablement). Follows the existing `greeter.wayvnc` submodule pattern.

## Architecture Decisions

| Decision | Choice | Rejected | Rationale |
|----------|--------|----------|-----------|
| Polling mechanism | `hyprctl devices -j` via shell script | DBus, Hyprland IPC socket | hyprctl already works in greeter session (proven by monitor-selection script); JSON output is stable |
| Layout label mapping | Shell `case` on `.active_keymap` value | Show raw name, use awk-based index parsing | Raw names ("Spanish", "Latin American") are too long; `case` handles both known XKB locale names without extra deps |
| Config path | `/etc/greetd/waybar-config` via `environment.etc` | `/var/lib/greeter/.config/waybar/` | Matches existing `/etc/greetd/hyprland.conf` pattern; world-readable, no per-user HOME complexity |
| `GTK_USE_PORTAL=0` | `env =` in hyprland.conf | systemd Environment=, shell export | Consistent with Hyprland env mechanism already used for cursor env vars |
| Startup ordering | `exec-once waybar` THEN `exec-once regreet-start` with 0.5s sleep | Systemd service dependency | `exec-once` guarantees ordering in Hyprland; sleep handles waybar layer-shell initialization race |

## Data Flow

```
Hyprland (greeter) ──exec-once──> waybar ──every 1s──> greetd-kb-layout script
                                              │
                                              v
                                    hyprctl devices -j | jq
                                              │
                                              v
                                    .active_keymap ──case──> "ES" | "LATAM"
                                              │
                                              v
                                    waybar custom/kb-layout ──> bottom bar text
```

## File Changes

| Repo | File | Action | Description |
|------|------|--------|-------------|
| omarchy-nix | `config.nix` | Modify | Add `greeter.layoutIndicator` submodule (enable, style) after `wayvnc` block |
| omarchy-nix | `modules/nixos/system.nix` | Modify | Generate waybar config + CSS at `/etc/greetd/`, add `GTK_USE_PORTAL=0` env, waybar `exec-once`, 0.5s delay in greeter script |
| nixos-hosts | `hosts/t14/default.nix` | Modify | Add `layoutIndicator.enable = true` in `omarchy.greeter` block |
| nixos-hosts | `hosts/t14/home/omarchy.nix` | Modify | Update architecture doc block (lines 31-43) to mention layout indicator |

## Component Details

### 1. omarchy-nix submodule (`config.nix`)

```nix
layoutIndicator = lib.mkOption {
  type = lib.types.submodule {
    options = {
      enable = lib.mkEnableOption "keyboard layout indicator in greeter";
      style = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Additional CSS injected into greeter waybar stylesheet";
      };
    };
  };
  default = { };
  description = "Keyboard layout indicator for the greeter Hyprland session. Only takes effect when greeter.type = 'regreet'.";
};
```

No `waybarPackage` option — `pkgs.waybar` is referenced directly in `system.nix` (same pattern as `pkgs.hyprland`, `pkgs.jq`, `pkgs.wayvnc` elsewhere in the greeter block).

### 2. Config generation (`system.nix` — inside `greetd` block)

Three new `let` bindings and one new script, all gated on `cfg.greeter.layoutIndicator.enable`:

**a) Layout polling script:**
```nix
layoutIndicatorScript = pkgs.writeShellScriptBin "greetd-kb-layout" ''
  ACTIVE=$(${pkgs.hyprland}/bin/hyprctl devices -j 2>/dev/null \
    | ${pkgs.jq}/bin/jq -r '.keyboards[] | select(.main) | .active_keymap' 2>/dev/null)
  case "$ACTIVE" in
    *Spanish*) echo "ES" ;;
    *Latino*|*Latin*) echo "LATAM" ;;
    *) echo "?" ;;
  esac
'';
```

**b) Waybar config** (`/etc/greetd/waybar-config`):
```nix
waybarGreeterConfig = pkgs.writeText "waybar-greeter-config"
  (builtins.toJSON {
    layer = "bottom";
    position = "bottom";
    height = 24;
    modules-left = [ ];
    modules-center = [ ];
    modules-right = [ "custom/kb-layout" ];
    "custom/kb-layout" = {
      exec = "${layoutIndicatorScript}/bin/greetd-kb-layout";
      interval = 1;
      format = "{}";
      tooltip = false;
    };
  });
```

**c) Waybar stylesheet** (`/etc/greetd/waybar-style.css`):
```nix
waybarGreeterStyle = pkgs.writeText "waybar-greeter-style" ''
  * { font-family: sans-serif; font-size: 14px; color: #cdd6f4; }
  window#waybar { background: rgba(30, 30, 46, 0.9); }
  #custom-kb-layout { padding: 0 12px; font-weight: bold; }
  ${cfg.greeter.layoutIndicator.style}
'';
```

**d) Hyprland config template changes** (the `${...}` string at line 282):
- Add `gtkPortalEnv = lib.optionalString cfg.greeter.layoutIndicator.enable "env = GTK_USE_PORTAL,0\n"`
- Add `waybarExec = lib.optionalString cfg.greeter.layoutIndicator.enable "exec-once = ${pkgs.waybar}/bin/waybar -c /etc/greetd/waybar-config -s /etc/greetd/waybar-style.css\n"`
- Insert `${gtkPortalEnv}${waybarExec}` before `${monitorBlock}` in template

**e) `environment.etc` entries:**
```nix
environment.etc."greetd/waybar-config".text = lib.mkIf
  (cfg.greeter.type == "regreet" && cfg.greeter.layoutIndicator.enable)
  (builtins.readFile waybarGreeterConfig);

environment.etc."greetd/waybar-style.css".text = lib.mkIf
  (cfg.greeter.type == "regreet" && cfg.greeter.layoutIndicator.enable)
  (builtins.readFile waybarGreeterStyle);
```

**f) Greeter script delay** — insert before Phase 1 monitor selection:
```nix
${lib.optionalString cfg.greeter.layoutIndicator.enable ''
  # Phase 0: wait for waybar layer-shell surface to map
  sleep 0.5
''}
```

### 3. Host config (`hosts/t14/default.nix`)

Add at `omarchy.greeter` block (~line 203):
```nix
layoutIndicator.enable = true;
```

### 4. Architecture doc update (`hosts/t14/home/omarchy.nix`)

Append to the GREETER ARCHITECTURE block (line 43): mention that waybar provides visual kb-layout feedback via `omarchy.greeter.layoutIndicator`.

## Configuration

| Value | Location | Rationale |
|-------|----------|-----------|
| `height: 24` | waybar config | Matches user session waybar height; bottom bar avoids overlapping centered ReGreet form |
| `interval: 1` | waybar config | 1s is responsive enough for Alt+Shift toggle feedback; 0.5s would add CPU load with negligible UX gain |
| `layer: bottom` | waybar config | Prevents waybar from intercepting clicks meant for the login form |
| `sleep 0.5` | greeter script | Empirical: waybar needs ~200-400ms to map its layer-shell surface after exec-once |
| `GTK_USE_PORTAL=0` | hyprland.conf env | Prevents GTK (ReGreet) from calling xdg-desktop-portal inside the greeter session, avoiding dbus timeout deadlocks |

## Rollback

Set `omarchy.greeter.layoutIndicator.enable = false`, rebuild t14. `exec-once` line disappears from generated hyprland.conf. Waybar config files at `/etc/greetd/` become empty (controlled by `lib.mkIf`). The 0.5s sleep is removed from the greeter script. No state migration needed.

## Testing

1. `nix flake check --no-build` for t14
2. Rebuild and reboot t14 — verify waybar bar appears at bottom of login screen showing "ES" or "LATAM"
3. Press Alt+Shift — verify label changes within 2s
4. Type password — verify ReGreet form is clickable, no focus-steal or overlap
5. Verify non-t14 hosts unaffected: `nix flake check --no-build` for rog, thinkcentre, mact2
