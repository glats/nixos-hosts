# Design: Restore fcitx5 IME and fix compose:caps on t14

## Technical Approach

Two-repo change. **Repo 1 (omarchy-nix)**: add fcitx5 as a reusable Home Manager module following the project's existing submodule option pattern (voxtype, wayvnc, nvidia). **Repo 2 (nixos-hosts)**: t14 enables the module with `omarchy.fcitx5.enable = true` and strips `compose:caps` from both the Hyprland session and the ReGreet greeter.

## Architecture Decisions

### Decision: Module location — omarchy-nix upstream

| Option | Tradeoff | Decision |
|--------|----------|----------|
| t14-only at `hosts/t14/home/fcitx5.nix` | Quick but not reusable; rog/thinkcentre would duplicate if needed later | ❌ |
| nixos-hosts shared at `modules/features/services/` | Wrong repo — fcitx5 is a HM concern, not a NixOS module | ❌ |
| omarchy-nix `modules/home-manager/fcitx5.nix` | Reusable, follows project convention (voxtype, wayvnc), any consumer can opt-in | ✅ **Chosen** |

**Rationale**: fcitx5 is a general IME framework. omarchy-nix already has the pattern (`voxtype.nix`, `wayvnc.nix`) — gated option, systemd user service, xdg config. This makes it available to all omarchy-nix consumers.

### Decision: Option style — submodule (project convention)

| Option | Tradeoff | Decision |
|--------|----------|----------|
| `lib.mkEnableOption` | Simpler, but inconsistent with every other omarchy option | ❌ |
| `lib.mkOption` with `types.submodule` | Matches voxtype, wayvnc, nvidia, gaming, firewall — extensible if future options needed | ✅ **Chosen** |

### Decision: Autostart — systemd user service

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Hyprland `exec-once` | Dies on Hyprland restart; omarchy's autostart.nix has fcitx5 commented out | ❌ |
| `systemd.user.services.fcitx5` | Survives Hyprland restarts, journalctl-visible, matches voxtype/wayvnc pattern | ✅ **Chosen** |

### Decision: compose:caps — do NOT touch upstream

omarchy-nix's `modules/home-manager/hyprland/input.nix:12` sets `input.kb_options = lib.mkDefault "compose:caps"`. This stays unchanged. t14 already overrides with `lib.mkForce` in `hosts/t14/home/hypr/input.nix` — we just remove `,compose:caps` from the force.

## Data Flow

```
  omarchy-nix (Repo 1)
    config.nix                          ← ADD omarchy.fcitx5 option (submodule)
    modules/home-manager/fcitx5.nix     ← NEW: packages + env + config + systemd
    modules/home-manager/default.nix    ← ADD import ./fcitx5.nix
    flake.nix                           ← ADD homeManagerModules.fcitx5 standalone

  nixos-hosts (Repo 2) — t14
    hosts/t14/home/omarchy.nix          ← ADD omarchy.fcitx5.enable = true
    hosts/t14/home/hypr/input.nix       ← REMOVE ,compose:caps from kb_options
    hosts/t14/default.nix               ← REMOVE ,compose:caps from greeter options
```

## File Changes

### Repo 1: omarchy-nix (`/home/glats/repos/omarchy-nix`)

| File | Action | Description |
|------|--------|-------------|
| `modules/home-manager/fcitx5.nix` | Create | Reusable HM module: packages, sessionVariables, xdg.configFile, systemd user service |
| `config.nix` | Modify | Add `fcitx5` option (submodule with `enable` bool, default false) |
| `modules/home-manager/default.nix` | Modify | Add `./fcitx5.nix` to imports list |
| `flake.nix` | Modify | Add `homeManagerModules.fcitx5` standalone output |

### Repo 2: nixos-hosts (`/home/glats/.nixos`)

| File | Action | Description |
|------|--------|-------------|
| `hosts/t14/home/omarchy.nix` | Modify | Add `omarchy.fcitx5.enable = true;` |
| `hosts/t14/home/hypr/input.nix` | Modify | Remove `,compose:caps` from `kb_options` (line 11) |
| `hosts/t14/default.nix` | Modify | Remove `,compose:caps` from `greeter.keyboard.options` (line 178) |

## Interfaces / Contracts

### omarchy-nix: `config.nix` — new option

Add after `wayvnc` option (line ~509), following exact project pattern:

```nix
fcitx5 = lib.mkOption {
  type = lib.types.submodule {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable fcitx5 input method with IME support for accented characters and multi-layout switching. Requires removing compose:caps from Hyprland input options.";
      };
    };
  };
  default = { };
  description = "Fcitx5 input method configuration";
};
```

### omarchy-nix: `modules/home-manager/fcitx5.nix` — new module

Content recovered from `git show 84f88a8:hosts/t14/home/fcitx5.nix`, wrapped in the omarchy option gate (following wayvnc.nix pattern):

```nix
# fcitx5 input method — reusable Home Manager module.
# Provides packages, session env vars, user config (profile + behavior),
# and a systemd user service. Gated by omarchy.fcitx5.enable.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.omarchy.fcitx5;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      fcitx5
      fcitx5-qt
      fcitx5-gtk
      fcitx5-configtool
    ];

    home.sessionVariables = {
      GTK_IM_MODULE = "fcitx";
      QT_IM_MODULE = "fcitx";
      XMODIFIERS = "@im=fcitx";
    };

    # fcitx5 profile — pin es/latam/us layouts.
    # Default Layout=es matches the omarchy upstream default kb_layout.
    # Consumers with different layouts can override via xdg.configFile
    # with lib.mkForce in their own HM config.
    xdg.configFile."fcitx5/profile".text = ''
      [Groups/0]
      Name=Default
      Default Layout=es
      DefaultIM=keyboard-es

      [Groups/0/Items/0]
      Name=keyboard-es
      Layout=es

      [Groups/0/Items/1]
      Name=keyboard-latam
      Layout=latam

      [Groups/0/Items/2]
      Name=keyboard-us
      Layout=us

      [GroupOrder]
      0=Default
    '';

    xdg.configFile."fcitx5/config".text = ''
      [Behavior]
      TriggerWhenFocus=True
      ShowInputMethodInformation=True
    '';

    systemd.user.services.fcitx5 = {
      Unit = {
        Description = "Fcitx5 input method";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.fcitx5}/bin/fcitx5 -d";
        Restart = "on-failure";
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
```

### omarchy-nix: `modules/home-manager/default.nix` — add import

Add to the imports list (after `./wayvnc.nix` at line 88):

```nix
    ./wayvnc.nix
    ./fcitx5.nix
```

### omarchy-nix: `flake.nix` — standalone module

Add after `homeManagerModules.btop` (line ~82), following the exact btop precedent:

```nix
        # Standalone fcitx5 module — IME packages + env + config + autostart
        # without the full omarchy desktop (Hyprland, waybar, walker, etc.).
        fcitx5 =
          { config, lib, pkgs, ... }:
          {
            imports = [
              (import ./modules/home-manager/fcitx5.nix)
            ];
            options.omarchy = (import ./config.nix lib).omarchyOptions;
          };
```

### nixos-hosts: `hosts/t14/home/omarchy.nix` — enable fcitx5

Add inside the top-level config block (e.g., after the `omarchy.rotate_on_start` override at line 121):

```nix
  # fcitx5 IME — accented characters (dead keys, backtick) and
  # multi-layout switching. The omarchy-nix module provides packages,
  # env vars, config, and autostart; we just opt in.
  omarchy.fcitx5.enable = true;
```

### nixos-hosts: `hosts/t14/home/hypr/input.nix` — exact diff

```diff
-    kb_options = lib.mkForce "grp:alt_shift_toggle,compose:caps";
+    kb_options = lib.mkForce "grp:alt_shift_toggle";
```

### nixos-hosts: `hosts/t14/default.nix` — exact diff

```diff
-        options = "grp:alt_shift_toggle,compose:caps";
+        options = "grp:alt_shift_toggle";
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Build (omarchy-nix) | `nix flake check` in omarchy-nix | Validates option types, module imports, standalone output |
| Build (nixos-hosts) | `nix flake check --no-build` | Confirms eval + type checks across all hosts |
| Build (nixos-hosts) | `nixos-build dry` on t14 | Full closure builds without errors |
| Runtime | Dead keys (`` ` ``, `´`) produce characters | Manual — type in ghostty + nautilus |
| Runtime | CAPS LOCK toggles caps (not Compose) | Manual — verify normal behavior |
| Runtime | fcitx5 tray icon in waybar | Manual — visual check after login |
| Runtime | es/latam/us toggle via fcitx5 Ctrl+Space | Manual — verify layout switch in fcitx5 panel |
| Runtime | Alt+Shift still toggles es/latam at XKB level | Manual — verify layout switch |
| Runtime | `systemctl --user status fcitx5` shows active | Manual — verify service running |
| Regression | rog, thinkcentre, mact2 build cleanly | `nix flake check --no-build` covers all hosts |

## Migration / Rollout

No migration required. The omarchy-nix change must be committed and the flake input updated in nixos-hosts before the t14 enable line resolves. Suggested order:

1. Commit omarchy-nix changes → push → update flake lock in nixos-hosts
2. Commit nixos-hosts changes (enable + compose:caps removal)
3. `nixos-build switch` on t14

Rollback: revert the nixos-hosts commit (removes enable + restores compose:caps). The omarchy-nix module stays — it's inert when `enable = false` (default).

## Open Questions

None.
