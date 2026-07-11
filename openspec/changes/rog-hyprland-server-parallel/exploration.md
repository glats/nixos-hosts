# Exploration: rog-hyprland-server-parallel

## Executive Summary

Installing Hyprland/Omarchy alongside the existing server profile on rog is **NOT FEASIBLE without replacing the GPU**. The GTX 1050 (Pascal) uses NVIDIA's legacy_580 proprietary driver, which has critically poor Wayland support -- Hyprland developers explicitly state there is "no official support" for NVIDIA hardware. The legacy 580 driver branch lacks the open kernel modules that modern Wayland compositors need, and the closed-source modules are known to crash on kernels 6.11+ (nixos-unstable uses 6.13+). Even if the GPU issue were resolved, the profile architecture (server.nix chain enables xserver for xrdp) would require significant restructuring to coexist with a Wayland compositor. The lid-switch mechanism is entirely absent on rog and would need infrastructure built from scratch. **Recommendation**: Defer until GPU upgrade (AMD or NVIDIA Turing+) or explore alternative approaches (run Hyprland on the Intel iGPU if rog has hybrid graphics -- unconfirmed).

## rog Current State

### Profiles imported
- `server.nix` -> which chains: `desktop.nix` -> `base.nix`
- `base.nix` provides: cachix, options, dconf, home-manager, logind, nh, nix, packages, polkit, shutdown-fix, sops, users, zsh; networking (avahi, firewall, openssh); boot
- `desktop.nix` adds: fonts, i18n, kmscon, keyring
- `server.nix` adds: xrdp, github-mcp-server, github-token-check, wol, docker

### Display/Graphics
- **GPU**: NVIDIA GTX 1050 (Pascal architecture, GP107)
- **Driver**: `hardware.nvidia.package = nvidiaPackages.legacy_580` (proprietary, NOT open kernel modules)
- **Kernel modules**: nvidia, nvidia_modeset, nvidia_uvm, nvidia_drm
- **modeset**: Enabled (`nvidia-drm modeset=1`)
- **nvidia.open = false** (proprietary kernel modules -- Pascal cannot use open modules)
- **Xserver**: `services.xserver.enable = true` (via xrdp.nix)
- **Video drivers**: `services.xserver.videoDrivers = ["nvidia"]` (proprietary)
- **Xorg config**: Ignores eDP-1 (laptop panel), enables HDMI-1
- **No display manager**: `displayManager.lightdm.enable = false` (xrdp uses xrdp-sesman directly)
- **No greeter**: No greetd, sddm, gdm, or lightdm

### Desktop suite
- `my.desktop.suite = "mate"` -- provides MATE DE (atril, caja, marco, mate-panel, etc.) + X11 tools (scrot, xclip, flameshot, copyq, conky) + materia-theme

### xrdp status
- Custom module at `modules/features/services/xrdp.nix`
- Creates MATE sessions via xrdp-sesman (no display manager needed)
- Session loop: MATE logout -> fresh MATE session (not disconnect)
- Preamble: dbus activation, graphical-session.target, xset dpms off
- Session cleanup: kills session-spawned PIDs on logout (excludes agents: ssh-agent, gpg-agent, gnome-keyring, tmux)

### Home Manager
- Uses `shared-modules.nix` which includes: base, shell, theme, omarchy-btop, tmux, neovim, mate, rofi, git, gpg, gh, ghostty, kitty, alacritty, chrome-apps, ssh, fontconfig, sops, shell-aliases, opencode, opencode-profile
- Host-conditional additions: remote-desktop, mate-rog-autostart, conky-rog, openfang, webcam-rog, shell-gpt

### Lid switch
- `HandleLidSwitch = "ignore"` in `modules/base/logind.nix` -- ALL lid events are completely ignored on ALL hosts
- No lid-switch handling infrastructure exists anywhere in the repo for rog

### Key observations
1. Rog has **NO graphical login on the local console** -- xrdp is the only way to get a desktop
2. The xserver is enabled **solely** for xrdp's virtual X sessions; no physical display output is configured
3. The NVIDIA driver is configured for X11 (`videoDrivers = ["nvidia"]`), not for Wayland/GBM
4. The `my.desktop.suite` option only supports `"mate"` and `"gnome"` -- there is no `"hyprland"` value

## t14 Omarchy/Hyprland Stack

### How it's wired
- **NixOS module**: Injected via `extraModules` in `flake.nix:224-227`: `[inputs.omarchy-nix.nixosModules.default, inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t14-amd-gen4]`
- **No profile chain**: t14 imports modules directly (base pieces individually + desktop pieces + hardware) -- it does NOT use server.nix or desktop.nix
- **omarchy config block**: `omarchy = { username, theme, monitors, browser, terminal, greeter, wayvnc, ... }` in `hosts/t14/default.nix`
- **Greeter**: greetd + regreet running INSIDE a Hyprland compositor session (NOT cage, NOT sddm, NOT lightdm)
- **HM modules**: Custom `omarchy.nix` imports omarchy-nix HM module + selective shared modules -- notably excludes mate.nix, rofi.nix, chrome-apps.nix, theme.nix
- **Standalone HM**: flake.nix homeConfigurations.t14 uses omarchy.nix directly (not shared-modules.nix)

### Key components rog would need to replicate
1. **omarchy-nix NixOS module** via extraModules (currently only t14 uses it)
2. **greetd** + regreet as greeter (new service, currently absent on rog)
3. **Hyprland** compositor with NVIDIA-specific env vars
4. **HM config fork**: rog needs omarchy HM modules instead of mate/rofi/chrome-apps/theme
5. **HDM** (HyprDynamicMonitors) for lid-switch handling -- currently t14-only
6. **PipeWire + WirePlumber** (omarchy-nix enables these; rog currently has no audio stack)
7. **NetworkManager** (already enabled on rog -- no conflict)
8. **Bluetooth** (omarchy-nix enables it; rog may or may not have BT hardware)

### Graphics/GPU considerations
- t14 uses **AMD iGPU** (amdgpu open-source driver) -- fully supported by Hyprland
- Rog uses **NVIDIA dGPU** (proprietary) -- problematic for Hyprland
- Rog's hardware-configuration.nix shows Intel CPU (`kvm-intel` kernel module, `hardware.cpu.intel.updateMicrocode`) -- potentially has Intel iGPU (unconfirmed, needs `lspci` check at runtime)

## Architecture Analysis

### Profile chain implications
The profile chain `server.nix -> desktop.nix -> base.nix` has two problems for Hyprland:

1. **xserver conflict**: `server.nix` imports `xrdp.nix` which enables `services.xserver.enable = true`. Omarchy/Hyprland is Wayland-only and does NOT use xserver. While they could theoretically coexist (xserver for xrdp virtual sessions + Wayland for local display), the NVIDIA driver configuration might conflict (xserver sets `videoDrivers = ["nvidia"]` while Hyprland needs GBM/nvidia-drm).

2. **No conditional branching**: The profile chain has no mechanism to say "enable desktop.nix + server.nix BUT also add Hyprland on top while keeping xrdp." t14 avoids this entirely by NOT using the profile chain.

**Options**:
- **A. Break the chain for rog** (like t14): Import modules directly, don't use server.nix. Most correct, but requires restructuring rog's imports and re-verifying all 20+ services still work.
- **B. Extend `my.desktop.suite`** with a `"hyprland"` value and add conditional logic to profiles. Would require refactoring server.nix/desktop.nix to be conditional.
- **C. Dual-host approach**: Create `hosts/rog-hyprland/` as a separate NixOS configuration that shares most config with rog but adds Hyprland. Overkill for a single machine.

### Shared vs host-specific modules
- `shared-modules.nix` includes `mate.nix`, `rofi.nix`, `chrome-apps.nix`, `theme.nix` -- all incompatible with Hyprland
- Rog would need a t14-style custom HM import list (like `omarchy.nix`)
- The `omarchy-nix.homeManagerModules.btop` in shared-modules.nix means omarchy-nix is already a dependency for rog's HM -- this is good, no new flake input needed

### Graphics/GPU considerations
- The **BLOCKING** issue is GPU compatibility, not module architecture
- NVIDIA legacy_580 driver: Pascal GPUs (GTX 1050) do NOT support the open kernel modules
- Closed-source modules don't get the drm_fbdev fix for kernel 6.11+
- Hyprland wiki states "no official support" for NVIDIA
- Without the open modules, Hyprland may crash with `GBM: Failed to allocate a GBM buffer` errors
- **Potential mitigation**: If rog has Intel iGPU (unconfirmed from code), could use the iGPU for Hyprland display and keep NVIDIA for CUDA/compute only (like a reverse-PRIME setup)

## Blocker Analysis

### BLOCKER -- NVIDIA GTX 1050 + Hyprland Wayland support
- **Severity**: CRITICAL
- **Evidence**: Hyprland wiki says "no official support for Nvidia hardware." Pascal architecture requires legacy_580 driver which does NOT support open kernel modules. Closed-source modules are known to crash on Wayland with kernel 6.11+. NixOS unstable uses kernel 6.13+.
- **Potential workaround**: 
  1. Check if rog has Intel iGPU (hybrid graphics) and use the iGPU for Hyprland display output
  2. Replace GPU with AMD card (RX 6400, RX 7600, etc.) or NVIDIA Turing+ (GTX 1650 Super or newer)
  3. Test Hyprland with legacy_580 + kernel params (nvidia_drm.modeset=1, initcall_blacklist=simpledrm_platform_driver_init) -- may work but is unsupported

### BLOCKER -- xserver/Hyprland coexistence on same GPU
- **Severity**: HIGH
- **Evidence**: `xrdp.nix` enables `services.xserver.enable = true` with `videoDrivers = ["nvidia"]`. Hyprland also needs to configure the GPU via GBM/nvidia-drm. These two graphics stacks may conflict on the same DRM device.
- **Potential workaround**: 
  1. If rog has iGPU: run Hyprland on iGPU, keep xrdp/xserver on NVIDIA (they don't share the same DRM device)
  2. If only dGPU: xserver for xrdp creates virtual X sessions (no physical output); Hyprland would own the physical output. Could work if Xorg is configured to be headless.

### CONCERN -- Profile chain restructuring required
- **Severity**: MEDIUM
- **Evidence**: Rog's import list goes through server.nix chain which enables xserver. Adding Hyprland requires either breaking the chain or making it conditional. Breaking it (t14 style) would mean rog's imports grow from ~25 lines to ~60+ lines.
- **Potential workaround**: Copy t14's pattern -- import base modules individually, then selectively import server-only modules (xrdp, docker, wol) + Hyprland modules. This is the "correct" approach but requires careful verification.

### CONCERN -- Lid-switch infrastructure absent
- **Severity**: MEDIUM
- **Evidence**: `HandleLidSwitch = "ignore"` in logind.nix (shared across ALL hosts). No lid-event handling exists on rog. t14 uses HDM (HyprDynamicMonitors) via UPower D-Bus -- this is compositor-level and requires Hyprland to be running.
- **Potential workaround**: 
  1. Change logind to handle lid events (suspend or lock) on rog, and use systemd services to start/stop greetd based on lid state
  2. Import HDM on rog if Hyprland is running -- HDM handles monitor profiles but not service start/stop
  3. Custom acpid/systemd script that reacts to lid events

### CONCERN -- kmscon + greetd VT conflict
- **Severity**: LOW-MEDIUM
- **Evidence**: `desktop.nix` imports `kmscon.nix` which manages virtual consoles. greetd wants to occupy VT7 for the greeter. These may conflict.
- **Potential workaround**: Disable kmscon on rog (if using Hyprland as the greeter compositor, VT consoles may not be needed) or configure greetd to use a different VT.

### CONCERN -- HM module divergence
- **Severity**: LOW
- **Evidence**: rog's HM includes mate.nix, rofi.nix, chrome-apps.nix -- all incompatible with Hyprland. Would need t14-style custom imports.
- **Potential workaround**: Use `lib.mkIf` gating on a new option to conditionally include/exclude modules based on active desktop mode. Or fork HM configs per mode.

### NEUTRAL -- omarchy-nix already available
- Rog already depends on omarchy-nix via `shared-modules.nix` importing `omarchy-nix.homeManagerModules.btop`. The flake input already exists. No new dependency needed.

### NEUTRAL -- server services unaffected
- All 20+ rog services (arr-stack, jellyfin, nginx, wireguard, etc.) are system services. They run regardless of desktop mode. Hyprland does not interfere with them.

## Unknowns

1. **Does rog have Intel iGPU?** hardware-configuration.nix shows Intel CPU (`kvm-intel`) but does NOT list i915 or internal GPU kernel modules. The Xorg config ignores eDP-1 and enables HDMI-1 -- this suggests the laptop panel IS connected to something (likely the NVIDIA GPU or an Intel iGPU). Need `lspci | grep VGA` on the rog host to confirm.
2. **Can legacy_580 run Hyprland at all?** Need to test on the actual hardware. Some Pascal users report success with Hyprland + proprietary drivers, but not with the 580 legacy branch specifically.
3. **What is the physical lid state behavior?** Rog is an ASUS laptop (rog = Republic of Gamers). ASUS laptops often have custom ACPI/WMI handling. The existing `asus_nb_wmi` and `asus_armoury` kernel modules are blacklisted. This may affect lid-switch detection.
4. **Does rog have an HDMI/DP output?** The Xorg config enables HDMI-1. For the "lid closed = server" use case, does the user want the display OFF when lid is closed (laptop mode) or always use an external monitor?
5. **Can greetd + xrdp coexist?** xrdp uses its own session manager (xrdp-sesman) and doesn't use a DM. greetd manages VT7. Should be fine, but needs verification.
6. **PipeWire on rog?** omarchy-nix enables PipeWire. Rog currently has no audio stack configured. Adding PipeWire may have side effects on a server host.

## Feasibility Verdict

**OVERALL: NOT FEASIBLE with current GPU**

### Key risks (if attempted):
1. **GPU compatibility (90% risk of failure)**: GTX 1050 + legacy_580 + Wayland/Hyprland is the wrong hardware combination. The driver branch is too old, doesn't support open kernel modules, and kernel 6.11+ breaks closed-source Wayland support.
2. **Architecture restructuring (30% risk)**: Profile chain needs to be broken or made conditional. This is achievable but increases rog's config complexity significantly.
3. **Lid-switch unreliability (40% risk)**: No infrastructure exists; custom scripts may be fragile; ASUS ACPI quirks add uncertainty.

### Recommended approach (high level):
1. **BEFORE any code changes**: SSH into rog and run `lspci | grep -E "VGA|3D"` to confirm GPU topology. If Intel iGPU exists, the feasibility changes significantly.
2. **If Intel iGPU exists**: Use iGPU for Hyprland/display, keep NVIDIA for CUDA/xrdp. This is the most promising path -- follows the hybrid graphics pattern many Linux users employ.
3. **If only NVIDIA dGPU**: Either replace the GPU (AMD RX 6400 is ~$130, passive, single-slot, perfect for a server) OR accept that Hyprland on rog is a non-starter.
4. **Architecture approach**: Follow t14 pattern -- break the profile chain, import modules individually. Create a new `hosts/rog/desktop/` directory for Hyprland-specific configs (greeter, monitors, HDM profiles).
5. **Lid-switch**: Use logind `HandleLidSwitch=lock` + custom systemd path unit or acpid event to toggle greetd service.

## Prior Art

### `openspec/explore/greetd-wayvnc-feasibility/`
Confirms greetd + Hyprland + regreet architecture works. The greeter runs Hyprland as a compositor (not cage). wayvnc can attach to the greeter session for pre-login VNC. This exploration was scoped to t14 only but the architecture patterns are reusable.

### `openspec/changes/host-desktop-suite-separation/`
The `my.desktop.suite` option was created to separate MATE from GNOME apps. Currently only supports `"mate"` and `"gnome"`. To add Hyprland, this option would need a third variant `"hyprland"` with its own profile, OR rog would follow t14's approach of NOT using the suite option at all.

## Files Examined
- `hosts/rog/default.nix` -- full rog config (161 lines)
- `hosts/rog/hardware-configuration.nix` -- auto-generated, Intel CPU, no iGPU detected
- `hosts/rog/home/modules.nix` -- HM module list (uses shared-modules.nix + additions)
- `hosts/rog/services/` -- 20 service files
- `modules/profiles/server.nix` -- server profile (16 lines, adds xrdp + docker + wol)
- `modules/profiles/desktop.nix` -- desktop profile (13 lines, adds fonts + i18n + kmscon)
- `modules/profiles/base.nix` -- base profile (26 lines)
- `modules/features/services/xrdp.nix` -- custom xrdp module (142 lines)
- `modules/hardware/nvidia.nix` -- NVIDIA config (75 lines, legacy_580, closed modules)
- `modules/base/logind.nix` -- lid switch = ignore (14 lines)
- `modules/base/home-manager.nix` -- HM integration (27 lines)
- `modules/base/options.nix` -- my.desktop.suite option (13 lines)
- `modules/base/packages.nix` -- package composition (41 lines)
- `modules/base/profiles/mate.nix` -- MATE profile (33 lines)
- `modules/base/profiles/gnome.nix` -- GNOME profile (11 lines)
- `hosts/t14/default.nix` -- t14 config (280 lines)
- `hosts/t14/home/omarchy.nix` -- t14 HM omarchy entry (284 lines)
- `hosts/t14/home/default.nix` -- t14 HM overlays (110 lines)
- `hosts/t14/home/hypr/monitors.nix` -- HDM-based monitor config
- `home-linux/shared-modules.nix` -- shared HM modules (40 lines)
- `home-linux/mate.nix` -- MATE dconf settings (338 lines)
- `flake.nix` -- inputs, mkNixosHost, homeConfigurations (322 lines)
- `lib/mkHost.nix` -- NixOS host builder (48 lines)
- `modules/desktop/kmscon.nix` -- kmscon VT config
- `modules/hardware/keyring.nix` -- lightdm gnome-keyring reference
- `openspec/explore/greetd-wayvnc-feasibility/exploration.md` -- prior art: greetd + Hyprland greeter
- `openspec/changes/host-desktop-suite-separation/proposal.md` -- prior art: desktop suite separation
- `openspec/specs/hyprland-config/spec.md` -- Hyprland config spec for t14
- Hyprland Wiki (Nvidia page) -- official NVIDIA compatibility docs
- NixOS issue #343774 -- NVIDIA Wayland failures on kernel 6.11+
- NixOS issue #376863 -- NVIDIA 565.77 closed drivers crash on Wayland
