# Tasks: rog-hyprland-server-parallel

## PR1: Foundation -- Profile chain break

### T1.1: Break profile chain in hosts/rog/default.nix + define HM inline
**Files**: `hosts/rog/default.nix`
**Depends on**: none
**Description**: Replace the `../../modules/profiles/server.nix` chain import with individual module imports. Add `inputs` to the function signature. Define `home-manager` config inline (same behavior as the removed `modules/base/home-manager.nix` module, still pointing at `./home/modules.nix`). No omarchy changes yet.

**Detailed changes**:
1. Add `inputs` to function signature: `{ config, pkgs, lib, inputs, ... }:`
2. Replace `../../modules/profiles/server.nix` with individual imports collated by group:

**Base modules** (from `profiles/base.nix`, excluding `home-manager.nix`):
- `../../modules/base/cachix.nix`
- `../../modules/base/dconf.nix`
- `../../modules/base/logind.nix`
- `../../modules/base/nh.nix`
- `../../modules/base/nix.nix`
- `../../modules/base/packages.nix`
- `../../modules/base/polkit.nix`
- `../../modules/base/shutdown-fix.nix`
- `../../modules/base/sops.nix`
- `../../modules/base/users.nix`
- `../../modules/base/zsh.nix`
- `../../modules/base/options.nix` (needed for `my.desktop.suite`)

**Desktop modules** (from `profiles/desktop.nix`):
- `../../modules/desktop/fonts.nix`
- `../../modules/desktop/i18n.nix`
- `../../modules/desktop/kmscon.nix`
- `../../modules/hardware/keyring.nix`

**Networking** (from `profiles/base.nix`):
- `../../modules/networking/avahi.nix`
- `../../modules/networking/firewall.nix`
- `../../modules/networking/openssh.nix`

**Boot** (from `profiles/base.nix`):
- `../../modules/features/boot.nix`

**Server services** (from `profiles/server.nix`):
- `../../modules/features/services/xrdp.nix`
- `../../modules/features/services/github-mcp-server.nix`
- `../../modules/features/services/github-token-check.nix`
- `../../modules/networking/wol.nix`
- `../../modules/virtualisation/docker.nix`

3. Keep all existing rog-specific imports (secrets.nix, conky-config.nix, conky module, hardware modules, services/*, libvirt.nix, shutdown-debug.nix) in the same order.

4. Add inline `home-manager` config block (replaces `modules/base/home-manager.nix`):
```nix
home-manager = {
  useGlobalPkgs = true;
  useUserPackages = true;
  backupFileExtension = "backup";
  extraSpecialArgs = {
    inherit inputs;
    hostName = config.networking.hostName;
    conkyConfig = config.conky-config;
    username = "glats";
  };
  users.glats.imports = import ./home/modules.nix { inherit inputs; };
};
```

5. Keep ALL existing config unchanged (boot-settings, networking, fileSystems, systemd service timeouts, nixpkgs.config, my.desktop.suite, etc.).

**Verification**:
```bash
nix flake check --no-build
# Must exit 0 with no errors for rog
# Then verify key services are still evaluable:
nix eval .#nixosConfigurations.rog.config.services.xrdp.enable
# Must return true
nix eval .#nixosConfigurations.rog.config.my.desktop.suite
# Must return "mate"
# Verify 3 random server services still resolve:
nix eval .#nixosConfigurations.rog.config.services.nginx.enable
nix eval .#nixosConfigurations.rog.config.services.jellyfin.enable
nix eval .#nixosConfigurations.rog.config.services.wireguard.enable
```

**Risk note**: This is the riskiest task. Any missing import from the profile chain would cause a regression. Cross-check the import list against `profiles/base.nix` (26 lines), `profiles/desktop.nix` (13 lines), and `profiles/server.nix` (16 lines) to ensure all 30+ modules are accounted for. The `options.nix` module is required for `my.desktop.suite` and `my.shutdownDebug` to work.

---

## PR2: Omarchy infrastructure -- NixOS module + files creation

### T2.1: Add omarchy-nix to rog extraModules in flake.nix
**Files**: `flake.nix`
**Depends on**: T1.1 (PR1 must be merged first)
**Description**: Add `inputs.omarchy-nix.nixosModules.default` to rog's `extraModules` in the `nixosConfigurations.rog` block. Rog's entry currently has no `extraModules` -- add the attribute.

**Changes**:
```nix
rog = mkNixosHost {
  hostname = "rog";
  extraModules = [
    inputs.omarchy-nix.nixosModules.default
  ];
};
```

**Verification**:
```bash
nix flake check --no-build
# Must exit 0; the omarchy option set is now available for rog
nix eval .#nixosConfigurations.rog.config.omarchy.username
# Should evaluate (even though not set yet, should show default or error)
```

---

### T2.2: Add omarchy config block to hosts/rog/default.nix (greetd masked)
**Files**: `hosts/rog/default.nix`
**Depends on**: T2.1
**Description**: Add the `omarchy` config block with all required options. Set `nvidia.enable = false` (rog uses its own `modules/hardware/nvidia.nix`), `firewall.enable = false` (rog uses its own firewall), `hyprland.lidSwitch.enable = false` (logind handle). Mask greetd from auto-starting (`systemd.services.greetd.wantedBy = lib.mkForce []`). The HM path still uses `./home/modules.nix` (not omarchy.nix yet).

**Detailed changes**:
1. Add omarchy config block BEFORE the `boot-settings` block (or after the imports block), with comment:
```nix
# === OMARCHY DESKTOP (Hyprland on Intel iGPU) ===
# greetd is masked in PR2 -- enabled in PR3
omarchy = {
  username = "glats";
  full_name = "Glats";
  email_address = "glats@local";
  theme = "glats";
  scale = 1;
  browser = "brave";
  terminal = "ghostty";
  monitors = [ "eDP-1,preferred,auto,1" ];

  # Keep rog's own firewall (omarchy's is disabled)
  firewall.enable = false;

  # Do NOT activate omarchy's NVIDIA module -- rog uses nvidia.nix
  nvidia.enable = lib.mkForce false;

  # Disable lid-switch handling (HandleLidSwitch=ignore already set)
  hyprland.lidSwitch.enable = false;

  # Greeter defined but service masked -- unmasked in PR3
  greeter = {
    type = "regreet";
  };
};

# Mask greetd from auto-starting until PR3 (Hyprland per-host configs)
systemd.services.greetd.wantedBy = lib.mkForce [];
```

**Verification**:
```bash
nix flake check --no-build
# Must exit 0
nix eval .#nixosConfigurations.rog.config.omarchy.username
# Must return "glats"
nix eval .#nixosConfigurations.rog.config.omarchy.nvidia.enable
# Must return false
nix eval .#nixosConfigurations.rog.config.services.greetd.enable
# Must return true (omarchy enables it) but service is masked
nix eval .#nixosConfigurations.rog.config.systemd.services.greetd.wantedBy
# Must return empty list []
```

---

### T2.3: Create hosts/rog/home/omarchy.nix
**Files**: `hosts/rog/home/omarchy.nix` (NEW)
**Depends on**: T2.1
**Description**: Create the Omarchy HM entry point for rog (t14 pattern). Imports `omarchy-nix.homeManagerModules.default` first, then `./default.nix` (rog Hyprland overlays), then individual shared modules. Excludes MATE/X11-specific modules.

**Contents** (template from `hosts/t14/home/omarchy.nix`, adapted for rog):

```nix
# Rog Home Manager -- Omarchy HM entry point.
#
# Replaces the previous modules.nix wrapping shared-modules.nix.
# Wire the omarchy-nix homeManagerModules.default alongside rog-specific
# Hyprland overlays in home/default.nix.
#
# Selective shared-module imports:
#   * Imported: base, shell, tmux, neovim, git, gh, ssh, ghostty, kitty,
#     alacritty, remote-desktop, shell-gpt, opencode, sops, fontconfig,
#     shell-aliases, openfang, webcam-rog
#   * Excluded: mate (MATE dconf -- system-level only, incompatible with
#     Hyprland), rofi (omarchy uses walker), chrome-apps (webapps managed
#     by omarchy webapp tooling), theme.nix (omarchy owns the visual layer)
#
# The omarchy HM module is imported FIRST so rog-specific overlays in
# default.nix can override via lib.mkForce.
{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    # Omarchy HM module -- supplies Hyprland, waybar, walker, etc.
    inputs.omarchy-nix.homeManagerModules.default

    # Rog-specific Hyprland overlays (monitors, input, env)
    ./default.nix

    # Compatible shared modules from home-linux/
    ../../../home-linux/base.nix
    ../../../home-linux/shell.nix
    ../../../home-linux/tmux.nix
    ../../../home-linux/neovim.nix
    ../../../home-linux/git.nix
    ../../../home-linux/gh.nix
    ../../../home-linux/ssh.nix
    ../../../home-linux/remote-desktop.nix
    ../../../home-linux/ghostty.nix
    ../../../home-linux/kitty.nix
    ../../../home-linux/alacritty.nix
    ../../../home-linux/shell-gpt.nix
    ../../../home-linux/openfang.nix
    ../../../home-linux/webcam-rog.nix

    # Shared modules (cross-platform)
    ../../../shared/shell-aliases.nix
    ../../../shared/opencode.nix
    ../../../shared/opencode-profile.nix
    ../../../shared/sops.nix
    inputs.sops-nix.homeManagerModules.sops

    # ShellGPT enabled
    ({ home.shell-gpt.enable = true; })
  ];

  # Use SSH host key for sops decryption (matches host_rog in .sops.yaml).
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # Disable omarchy's zsh extras that conflict with shell.nix prezto setup.
  programs.zsh.zplug.enable = lib.mkForce false;
  programs.starship.enable = lib.mkForce false;

  # Disable HM-level fontconfig -- rely on system-level fonts.nix.
  fonts.fontconfig.enable = lib.mkForce false;

  # Override active OpenCode provider for this host
  home.opencode.activeProviderName = "opencode-go-medium";
}
```

**Verification**:
```bash
# Check file exists and Nix evaluation is OK (will fail until PR3
# when HM path switches to this file -- standalone check still passes
# via modules.nix)
nix-instantiate --eval --strict -E '(import ./hosts/rog/home/omarchy.nix { config = {}; pkgs = {}; lib = {}; inputs = {}; })'
# At minimum, validate syntax:
nix eval --file ./hosts/rog/home/omarchy.nix 2>&1 || true
# (May fail on missing pkgs/lib -- that's expected for partial eval,
#  the real validation is in flake check)
```

---

### T2.4: Create hosts/rog/home/default.nix (Hyprland overlays scaffold)
**Files**: `hosts/rog/home/default.nix` (NEW)
**Depends on**: T2.3
**Description**: Create the rog-specific Hyprland overlays module. This file imports the hypr/ subfiles. In PR2 the imports list is EMPTY (hypr/ files don't exist yet). In PR3, the hypr/ imports are added.

**Contents**:
```nix
# Rog-specific Home Manager overlays on top of omarchy-nix.
#
# hypr/ subfiles added in PR3 (Hyprland per-host configs).
# This file is a scaffold imported by omarchy.nix.
{ config, lib, pkgs, ... }:

{
  imports = [
    # ./hypr/monitors.nix   # PR3
    # ./hypr/input.nix      # PR3
    # ./hypr/env.nix        # PR3
  ];
}
```

**Verification**:
```bash
nix flake check --no-build
# Must exit 0 (file is imported by omarchy.nix, but HM path
# still uses modules.nix in PR2, so this file isn't evaluated yet)
# Syntax check:
nix-instantiate --parse ./hosts/rog/home/default.nix > /dev/null
echo "Syntax OK"
```

---

## PR3: Hyprland per-host configs

### T3.1: Create hosts/rog/home/hypr/monitors.nix
**Files**: `hosts/rog/home/hypr/monitors.nix` (NEW)
**Depends on**: PR2 merged
**Description**: Create the rog Hyprland monitor configuration. Static config (no HDM on rog -- lid switch is disabled). eDP-1 is the internal display. HDMI-1 available for external. Follows t14 pattern but without HDM source directive.

**Contents**:
```nix
# Rog Hyprland monitor configuration.
# Static config -- no HDM on rog (lid-switch disabled, HandleLidSwitch=ignore).
# Intel iGPU drives eDP-1 (internal laptop panel).
# NVIDIA drives HDMI-1 via xrdp headless Xorg only (not Hyprland).
{ ... }:

{
  wayland.windowManager.hyprland.settings = {
    monitor = [
      "eDP-1,preferred,auto,1"
      # "HDMI-1,preferred,auto,1"  # External monitor (if connected to Intel iGPU)
    ];

    env = [ "GDK_SCALE,1" ];
  };
}
```

**Verification**:
```bash
nix-instantiate --parse ./hosts/rog/home/hypr/monitors.nix > /dev/null
echo "Syntax OK"
```

---

### T3.2: Create hosts/rog/home/hypr/input.nix
**Files**: `hosts/rog/home/hypr/input.nix` (NEW)
**Depends on**: PR2 merged
**Description**: Create the rog Hyprland input configuration. Keyboard layout "es" (rog's current layout). Match t14's pattern but with single layout (rog doesn't need latam).

**Contents**:
```nix
# Rog Hyprland input -- keyboard layout "es" (rog's current layout).
# All other input settings owned by omarchy-nix upstream.
{ lib, ... }:

{
  wayland.windowManager.hyprland.settings.input = {
    kb_layout = lib.mkForce "es";
    # kb_options = lib.mkForce "grp:alt_shift_toggle";  # Only needed for multi-layout
  };
}
```

**Verification**:
```bash
nix-instantiate --parse ./hosts/rog/home/hypr/input.nix > /dev/null
echo "Syntax OK"
```

---

### T3.3: Create hosts/rog/home/hypr/env.nix
**Files**: `hosts/rog/home/hypr/env.nix` (NEW)
**Depends on**: PR2 merged
**Description**: Create the rog Hyprland environment configuration. Forces Hyprland to Intel iGPU DRM device (`WLR_DRM_DEVICES`, `AQ_DRM_DEVICES`). Overrides NVIDIA env vars that omarchy HM would inject (since `videoDrivers` contains `"nvidia"`).

**Contents**:
```nix
# Rog Hyprland environment -- Intel iGPU DRM device selection.
#
# Forces Hyprland to use the Intel iGPU for Wayland rendering, preventing
# the NVIDIA GTX 1050 from being used for framebuffer allocation.
# Overrides omarchy HM's default NVIDIA env vars (which are injected
# because services.xserver.videoDrivers contains "nvidia").
#
# IMPORTANT: /dev/dri/card0 is assumed to be Intel iGPU. Verify at
# deploy time via `ls /dev/dri/by-path/` on the rog host. If the Intel
# iGPU is on a different card path, update both WLR_DRM_DEVICES and
# AQ_DRM_DEVICES.
{ lib, ... }:

{
  wayland.windowManager.hyprland.settings = {
    env = [
      # Force Hyprland to Intel iGPU DRM device only
      "WLR_DRM_DEVICES,/dev/dri/card0"
      "AQ_DRM_DEVICES,/dev/dri/card0"

      # Override omarchy HM's NVIDIA env vars (since videoDrivers contains "nvidia")
      "LIBVA_DRIVER_NAME,iHD"           # Intel VA-API
      "__GLX_VENDOR_LIBRARY_NAME,mesa"  # Mesa GLX (not NVIDIA)
    ];
  };
}
```

**Verification**:
```bash
nix-instantiate --parse ./hosts/rog/home/hypr/env.nix > /dev/null
echo "Syntax OK"
```

---

### T3.4: Wire hypr imports in hosts/rog/home/default.nix
**Files**: `hosts/rog/home/default.nix`
**Depends on**: T3.1, T3.2, T3.3
**Description**: Replace the empty imports list in `default.nix` with the actual hypr/ subfile imports.

**Changes**: Uncomment/add the hypr subfile imports:
```nix
imports = [
  ./hypr/monitors.nix
  ./hypr/input.nix
  ./hypr/env.nix
];
```

**Verification**:
```bash
nix flake check --no-build
# Must exit 0 (still via modules.nix HM path, but files exist now)
```

---

### T3.5: Switch NixOS HM path to omarchy.nix + update flake.nix homeConfigurations
**Files**: `hosts/rog/default.nix`, `flake.nix`
**Depends on**: T3.4
**Description**: Two coordinated changes:

1. **hosts/rog/default.nix**: Switch the inline HM `users.glats.imports` from `modules.nix` to `omarchy.nix`:
```nix
users.glats.imports = [ ./home/omarchy.nix ];
```

2. **flake.nix**: Update `homeConfigurations.rog` to use `omarchy.nix` directly (t14 pattern):
```nix
rog = home-manager.lib.homeManagerConfiguration {
  pkgs = pkgsFor "x86_64-linux";
  modules = [
    ./hosts/rog/home/omarchy.nix
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
      };
    }
  ];
  extraSpecialArgs = {
    inherit inputs;
    hostName = "rog";
    username = "glats";
  };
};
```

**Verification**:
```bash
nix flake check --no-build
# Must exit 0
# Verify both paths work:
nix build .#nixosConfigurations.rog.config.system.build.toplevel
nix build .#homeConfigurations.rog.activationPackage
# Both must build successfully
```

---

### T3.6: Unmask greetd in hosts/rog/default.nix
**Files**: `hosts/rog/default.nix`
**Depends on**: T3.5
**Description**: Remove the `systemd.services.greetd.wantedBy = lib.mkForce []` line to allow greetd to auto-start on boot. The omarchy config block already has `greeter.type = "regreet"` which enables greetd.

**Changes**: Delete or comment out the masking line:
```nix
# systemd.services.greetd.wantedBy = lib.mkForce [];  # Removed -- greetd active now
```

**Verification**:
```bash
nix flake check --no-build
# Must exit 0
nix eval .#nixosConfigurations.rog.config.systemd.services.greetd.wantedBy
# Should include "multi-user.target" (or whatever omarchy sets)
nix eval .#nixosConfigurations.rog.config.services.greetd.enable
# Must return true
```

---

## PR4: HM module alignment + spec update

### T4.1: Update hosts/rog/home/modules.nix for backward compat
**Files**: `hosts/rog/home/modules.nix`
**Depends on**: T3.5 (omarchy.nix is now the primary path)
**Description**: Update `modules.nix` to re-export the omarchy.nix import list for backward compatibility. Any stale reference to `import ./hosts/rog/home/modules.nix` will still resolve to the same modules as omarchy.nix. Add a deprecation comment directing future consumers to use `./omarchy.nix` directly.

**Changes**:
```nix
# hosts/rog/home/modules.nix -- BACKWARD COMPATIBILITY WRAPPER
#
# This file is preserved for backward compatibility. The canonical HM
# entry point for rog is ./omarchy.nix. Both NixOS-integrated and
# standalone HM paths now use omarchy.nix directly (see flake.nix
# homeConfigurations.rog and hosts/rog/default.nix).
#
# New consumers should import ./omarchy.nix instead.
{ inputs }:
[
  inputs.omarchy-nix.homeManagerModules.default
  ./default.nix
  ../../../home-linux/base.nix
  ../../../home-linux/shell.nix
  ../../../home-linux/tmux.nix
  ../../../home-linux/neovim.nix
  ../../../home-linux/git.nix
  ../../../home-linux/gh.nix
  ../../../home-linux/ssh.nix
  ../../../home-linux/remote-desktop.nix
  ../../../home-linux/ghostty.nix
  ../../../home-linux/kitty.nix
  ../../../home-linux/alacritty.nix
  ../../../home-linux/shell-gpt.nix
  ../../../home-linux/openfang.nix
  ../../../home-linux/webcam-rog.nix
  ../../../shared/shell-aliases.nix
  ../../../shared/opencode.nix
  ../../../shared/opencode-profile.nix
  ../../../shared/sops.nix
  inputs.sops-nix.homeManagerModules.sops
  ({ home.shell-gpt.enable = true; })
]
```

**Verification**:
```bash
nix flake check --no-build
# Must exit 0
# Verify the re-exported list is equivalent to omarchy.nix's imports
diff <(nix eval --expr 'builtins.functionArgs ./hosts/rog/home/modules.nix') <(nix eval --expr 'builtins.functionArgs ./hosts/rog/home/omarchy.nix')
# Both should accept { inputs }
```

---

### T4.2: Update linux-hm-composition-alignment spec delta
**Files**: `openspec/changes/rog-hyprland-server-parallel/specs/linux-hm-composition-alignment/spec.md`
**Depends on**: T4.1
**Description**: Update the spec to reflect that `modules.nix` is now a backward-compat re-export of omarchy.nix's import list. The HM-SA-01 single-source guarantee is preserved: `modules.nix` re-exports the same modules that `omarchy.nix` imports, and the canonical source is `omarchy.nix`.

**Changes**: Update requirement HM-SA-07 to reflect the backward-compat nature of `modules.nix`. Remove or update scenarios that refer to modules.nix being the direct import for rog HM. Add scenario verifying the re-exported list matches omarchy.nix's imports.

**Verification**:
```bash
# Verify spec file is valid markdown and reads coherently
# Human review: check the logic still makes sense after updates
```

---

## Summary: Files per PR

| PR | Files | Lines Changed (est.) |
|----|-------|----------------------|
| PR1 | 1 modified (`hosts/rog/default.nix`) | ~120 (imports restructured, HM inline) |
| PR2 | 2 modified (`flake.nix`, `hosts/rog/default.nix`), 2 created (`home/omarchy.nix`, `home/default.nix`) | ~150 |
| PR3 | 2 modified (`hosts/rog/default.nix`, `home/default.nix`), 1 modified (`flake.nix`), 3 created (`hypr/*.nix`) | ~80 |
| PR4 | 1 modified (`home/modules.nix`), 1 modified (`spec.md`) | ~40 |

## Rollback verification (applicable to all PRs)

```bash
# Before switch, verify rollback will work:
nixos-build dry
# Shows what would change
# Pre-change generation is always available (configurationLimit = 3)
nixos-rebuild switch --rollback
```
