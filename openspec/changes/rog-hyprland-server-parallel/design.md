# Design: rog-hyprland-server-parallel

## Architecture Overview

```
rog (ASUS laptop, hybrid graphics)
├── Intel iGPU (i915) ──→ Hyprland/greetd (VT7, Wayland, DRM card0)
├── NVIDIA GTX 1050 (legacy_580) ──→ xrdp headless Xorg + CUDA (DRM card1)
├── 20+ server services ──→ unaffected (systemd, Docker, Nginx, etc.)
└── Home Manager ──→ omarchy.nix (omarchy-compatible subset, no MATE/rofi/chrome-apps/theme)
```

Both greetd and xrdp run simultaneously. No lid-switch toggle. Profile chain broken (t14 pattern).

## Hosts Affected

- **rog** (primary) — restructured imports, new HM fork, omarchy config block, GPU env vars
- **none other**

## Detailed Design

### flake.nix

Add `inputs.omarchy-nix.nixosModules.default` to rog's `extraModules`:

```nix
rog = mkNixosHost {
  hostname = "rog";
  extraModules = [
    inputs.omarchy-nix.nixosModules.default
  ];
};
```

Update `homeConfigurations.rog` to use `omarchy.nix` directly (t14 pattern):

```nix
rog = home-manager.lib.homeManagerConfiguration {
  pkgs = pkgsFor "x86_64-linux";
  modules = [
    ./hosts/rog/home/omarchy.nix
    { omarchy = { theme = "glats"; username = "glats"; /* ...inline inject for standalone */ }; }
  ];
  extraSpecialArgs = { inherit inputs; hostName = "rog"; username = "glats"; };
};
```

No new flake inputs. `omarchy-nix` already in flake closure.

### hosts/rog/default.nix

Break the profile chain. Import base modules individually (mirrors t14, adds rog server/desktop needs).

**Import list:**

```nix
imports = [
  ./hardware-configuration.nix

  # === BASE (individual, NOT profile chain) ===
  ../../modules/base/cachix.nix
  ../../modules/base/dconf.nix        # MATE dconf settings (for xrdp)
  ../../modules/base/logind.nix       # HandleLidSwitch=ignore (stays)
  ../../modules/base/nh.nix
  ../../modules/base/nix.nix
  ../../modules/base/packages.nix     # imports options.nix internally
  ../../modules/base/polkit.nix
  ../../modules/base/shutdown-fix.nix
  ../../modules/base/sops.nix
  ../../modules/base/users.nix
  ../../modules/base/zsh.nix
  # NOT: ../../modules/base/home-manager.nix (HM defined inline below)

  # === DESKTOP ===
  ../../modules/desktop/fonts.nix
  ../../modules/desktop/i18n.nix
  ../../modules/desktop/kmscon.nix
  ../../modules/hardware/keyring.nix

  # === NETWORKING ===
  ../../modules/networking/avahi.nix
  ../../modules/networking/firewall.nix
  ../../modules/networking/openssh.nix

  # === BOOT ===
  ../../modules/features/boot.nix

  # === SERVER SERVICES (from former server.nix) ===
  ../../modules/features/services/xrdp.nix
  ../../modules/features/services/github-mcp-server.nix
  ../../modules/features/services/github-token-check.nix
  ../../modules/networking/wol.nix
  ../../modules/virtualisation/docker.nix

  # === HARDWARE (rog-specific) ===
  ../../modules/hardware/nvidia.nix     # Unchanged — legacy_580 + xserver videoDrivers
  ../../modules/hardware/rog-shutdown.nix
  ../../modules/hardware/rog-poweroff-workaround.nix
  ../../modules/hardware/asus-fan-control.nix
  ../../modules/base/shutdown-debug.nix

  # === ROG SERVICES ===
  ./services/arr-stack.nix
  # ... (all 20 rog services — unchanged)
  ../../modules/virtualisation/libvirt.nix

  # === ROG-SPECIFIC ===
  ./secrets.nix
  ./conky-config.nix
  ../../modules/features/conky
];
```

**omarchy config block:**

```nix
omarchy = {
  username = "glats";
  full_name = "Glats";
  email_address = "glats@local";
  theme = "glats";
  scale = 1;
  browser = "brave";
  terminal = "ghostty";
  monitors = [ "eDP-1,preferred,auto,1" ];

  # Keep rog's firewall (omarchy's is disabled)
  firewall.enable = false;

  # Do NOT activate omarchy's NVIDIA module — we use our own nvidia.nix
  nvidia.enable = lib.mkForce false;

  # Disable lid-switch handling (HandleLidSwitch=ignore already set)
  hyprland.lidSwitch.enable = false;

  greeter = {
    type = "regreet";
    # Monitor config TBD at apply time (needs lspci on rog)
    # keyboard.layouts = [ "es" ];  # rog uses "es" layout
  };
};
```

**Keep existing rog config:** `my.desktop.suite = "mate"` (xrdp MATE packages), `boot-settings`, `networking`, `fileSystems`, `systemd.services.*` timeouts, `nixpkgs.config`.

**Home Manager (inline, like t14):**

```nix
home-manager = {
  useGlobalPkgs = true;
  useUserPackages = true;
  backupFileExtension = "backup";
  extraSpecialArgs = { hostName = config.networking.hostName; };
  users.glats = {
    imports = [ ./home/omarchy.nix ];
  };
};
```

### GPU Split (Intel iGPU vs NVIDIA)

**Challenge:** omarchy-nix HM module (`envs.nix`) checks `osConfig.services.xserver.videoDrivers`. Since nvidia.nix sets `["nvidia"]`, HM injects `NVD_BACKEND`, `LIBVA_DRIVER_NAME=nvidia`, `__GLX_VENDOR_LIBRARY_NAME=nvidia` into Hyprland env. These would misdirect VA-API/GLX to NVIDIA while Hyprland renders on Intel.

| Strategy | Tradeoff | Decision |
|-----------|----------|----------|
| `WLR_DRM_DEVICES` + `AQ_DRM_DEVICES` pointing to Intel DRM card | Forces Hyprland to Intel DRM device regardless of env vars | **Use** |
| Override NVIDIA env vars via `lib.mkForce` in rog Hyprland config | Defensive — prevents VA-API confusion | **Use** |
| `omarchy.nvidia.enable = false` | Prevents omarchy's nvidia.nix NixOS module from activating GBM_BACKEND=nvidia-drm | **Use** |

**New file `hosts/rog/home/hypr/env.nix`:**

```nix
{ lib, ... }:
{
  wayland.windowManager.hyprland.settings = {
    # Force Hyprland to Intel iGPU DRM device only
    env = [
      "WLR_DRM_DEVICES,/dev/dri/card0"
      "AQ_DRM_DEVICES,/dev/dri/card0"
      # Override omarchy HM's NVIDIA env vars (since videoDrivers contains "nvidia")
      "LIBVA_DRIVER_NAME,iHD"          # Intel VA-API
      "__GLX_VENDOR_LIBRARY_NAME,mesa" # Mesa GLX
    ];
  };
}
```

NVIDIA module (`modules/hardware/nvidia.nix`) stays **completely unchanged**. It drives xrdp's headless Xorg and CUDA. No conflict because Hyprland never touches the NVIDIA DRM device.

### Home Manager Fork

**New file: `hosts/rog/home/omarchy.nix`** (t14 pattern):

```nix
imports = [
  inputs.omarchy-nix.homeManagerModules.default
  ./default.nix  # rog-specific Hyprland overlays

  # Compatible shared modules (no mate.nix, rofi.nix, chrome-apps.nix, theme.nix)
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
];
```

**New file: `hosts/rog/home/default.nix`** (rog Hyprland overlays):

```nix
imports = [
  ./hypr/monitors.nix
  ./hypr/input.nix
  ./hypr/env.nix       # iGPU DRM device selection
];
```

**New directory: `hosts/rog/home/hypr/`:**
- `monitors.nix` — rog display config (eDP-1 or HDMI-1)
- `input.nix` — keyboard layout "es" (rog's current layout)
- `env.nix` — `WLR_DRM_DEVICES`, `AQ_DRM_DEVICES`, NVIDIA env var overrides

**Modified: `hosts/rog/home/modules.nix`** — no longer used by NixOS-integrated HM (defined inline) or standalone HM (uses omarchy.nix directly in flake.nix). Updated to re-export omarchy.nix's import list for backward compatibility.

**Excluded from HM fork:** `mate.nix` (MATE dconf — system-level only), `rofi.nix` (omarchy uses walker), `chrome-apps.nix` (omarchy manages webapps), `theme.nix` (omarchy owns visual layer), `mate-rog-autostart.nix` (HM-level MATE autostart incompatible with Hyprland).

### greetd + xrdp Coexistence

| Component | Mechanism | Conflict Risk |
|-----------|-----------|---------------|
| greetd | Manages VT7, launches regreet inside minimal Hyprland session | None — exclusive VT7 ownership |
| xrdp | xrdp-sesman creates virtual X sessions (DISPLAY :10, :11, ...) on NVIDIA | None — separate PAM stack, no VT |
| xserver | Enabled by xrdp.nix for headless Xorg (NVIDIA videoDrivers) | None — Xorg runs on NVIDIA DRM, Hyprland on Intel DRM |
| PipeWire | Enabled by omarchy system.nix (new on rog) | Low — harmless addition, audio not needed but doesn't break |

No PAM collision: greetd uses `pam.services.greetd`, xrdp uses its own PAM config. Both services start independently via systemd.

## Build & Verification

```bash
# 1. Syntax validation
nix flake check --no-build

# 2. Build rog only (no switch)
nix build .#nixosConfigurations.rog.config.system.build.toplevel

# 3. Dry run (show what would change)
nixos-build dry

# 4. Safe rollout (check → build → dry → switch)
nixos-build safe

# 5. Verify xrdp still works after switch
#    (connect via RDP client — MATE session should start)

# 6. Verify greetd renders on Intel iGPU
#    (physical display should show regreet login)
```

## Rollback

```bash
# Immediate rollback to pre-Hyprland generation
nixos-rebuild switch --rollback
# OR
nixos-build --rollback
```

System keeps `configurationLimit = 3` generations (from boot.nix). The pre-change generation is guaranteed available. All 20+ server services continue running during rollback — they are independent of the desktop stack.

Escape hatch if greetd fails: append `systemd.mask=greetd.service` to kernel cmdline at systemd-boot menu.

## Option Paths Reference

| Option | Module | Purpose |
|--------|--------|---------|
| `omarchy.username` | omarchy-nix | Set login user |
| `omarchy.theme` | omarchy-nix | Color theme ("glats") |
| `omarchy.nvidia.enable` | omarchy-nix | Gate omarchy NVIDIA module (set false) |
| `omarchy.greeter.type` | omarchy-nix | "regreet" for Hyprland greeter |
| `omarchy.firewall.enable` | omarchy-nix | Disable (rog uses own firewall) |
| `omarchy.hyprland.lidSwitch.enable` | omarchy-nix | Disable (HandleLidSwitch=ignore) |
| `services.greetd.enable` | omarchy-nix system.nix | Greeter service (auto-enabled) |
| `services.xserver.enable` | xrdp.nix | Headless Xorg for xrdp |
| `services.xserver.videoDrivers` | nvidia.nix | `["nvidia"]` for xrdp (unchanged) |
| `hardware.nvidia.package` | nvidia.nix | `legacy_580` (unchanged) |
| `services.logind.settings.Login.HandleLidSwitch` | logind.nix | `"ignore"` (unchanged) |
| `my.desktop.suite` | options.nix | `"mate"` — MATE packages for xrdp |
| `wayland.windowManager.hyprland.settings.env` | HM (rog env.nix) | `WLR_DRM_DEVICES`, iGPU selection |
| `home-manager.users.glats.imports` | rog default.nix | `[ ./home/omarchy.nix ]` (inline) |

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `flake.nix` | Modify | Add omarchy-nix to rog extraModules; update homeConfigurations.rog |
| `hosts/rog/default.nix` | Modify | Break profile chain, 20+ individual imports, omarchy block, inline HM |
| `hosts/rog/home/omarchy.nix` | Create | Omarchy HM entry point (t14 pattern) |
| `hosts/rog/home/default.nix` | Create | Rog Hyprland overlays (imports hypr/ subfiles) |
| `hosts/rog/home/hypr/monitors.nix` | Create | Monitor config for rog display |
| `hosts/rog/home/hypr/input.nix` | Create | Keyboard layout "es" |
| `hosts/rog/home/hypr/env.nix` | Create | iGPU DRM device selection + NVIDIA env overrides |
| `hosts/rog/home/modules.nix` | Modify | Update for backward compat (no longer primary HM path) |
| `modules/hardware/nvidia.nix` | None | Unchanged |
| `modules/base/logind.nix` | None | Unchanged |

## Open Questions

- [ ] Exact Intel iGPU DRM card path (`/dev/dri/card0` vs `/dev/dri/by-path/...`) — needs `ls /dev/dri/by-path/` on rog at apply time
- [ ] rog greeter monitor config — needs physical display info (eDP-1 resolution, external monitors)
- [ ] `mate-rog-autostart.nix` exclusion impact on xrdp sessions — MATE autostart may need system-level replacement