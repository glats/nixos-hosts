# Proposal: Run Hyprland Desktop + Server Services in Parallel on rog

## Intent

Add Hyprland/Omarchy desktop environment to rog (Intel iGPU for display, NVIDIA GTX 1050 stays on xrdp headless X + CUDA). Both greetd and xrdp run simultaneously at all times -- lid just covers the physical display, no service toggle needed. Server services (xrdp, arr-stack, jellyfin, nginx, docker, etc.) continue running uninterrupted.

## Scope

**In**: omarchy-nix NixOS module via extraModules; greetd + regreet greeter; Hyprland on Intel iGPU; HM config fork (omarchy-compatible subset, excluding mate/rofi/chrome-apps); co-existent xrdp/xserver on NVIDIA (both always running).
**Out**: NVIDIA Wayland support (not needed, iGPU handles display); PipeWire audio stack (future phase); HDM monitor profiles (future phase); GPU replacement; lid-switch service toggle (unnecessary -- both run in parallel).

## Capabilities

### New
- `rog-hyprland-desktop`: Hyprland/Omarchy desktop with greetd/regreet greeter, Intel iGPU rendering, omarchy-compatible HM on rog host (coexists with xrdp, both always running)

### Modified
- `linux-hm-composition-alignment`: rog HM modules diverge from shared-modules.nix for omarchy compatibility

## Approach

1. **Break profile chain** (follow t14 pattern): import base modules individually, keep server profile modules
2. **Add omarchy-nix**: via `extraModules` in `flake.nix` (already a flake input), configure omarchy block in rog default.nix
3. **Dual-GPU**: Intel iGPU for Hyprland/GBM display; NVIDIA continues driving xrdp's headless Xorg + CUDA; no GPU conflict
4. **greetd + regreet**: omarchy-nix manages the greeter compositor (Hyprland-as-greeter pattern, no cage)
5. **HM fork**: `hosts/rog/home/modules.nix` imports omarchy-nix HM module + selective shared modules (base, shell, tmux, neovim, git, gh, ssh, remote-desktop, opencode, sops) -- excludes mate.nix, rofi.nix, chrome-apps.nix, theme.nix
6. **No lid-switch**: greetd and xrdp both run at all times. Lid is purely physical -- display on/off handled by DRM when screen is covered. `HandleLidSwitch` stays at current `"ignore"` (no change needed).

## Affected Areas

| File | Impact | Description |
|------|--------|-------------|
| `flake.nix` | Modified | Add `inputs.omarchy-nix.nixosModules.default` to rog's `extraModules` in `nixosConfigurations` |
| `hosts/rog/default.nix` | Modified | Break profile chain, import modules individually, add omarchy config block |
| `hosts/rog/home/modules.nix` | Modified | Fork from shared-modules.nix to omarchy-compatible subset |
| `hosts/rog/home/omarchy.nix` | **New** | Omarchy HM entry point for rog (t14 pattern) |
| `hosts/rog/home/hypr/` | **New** | Rog-specific Hyprland configs (monitors, input, env) |
| `modules/base/logind.nix` | **None** | No change -- `HandleLidSwitch = "ignore"` stays as-is |
| `modules/hardware/nvidia.nix` | **None** | No change -- xserver videoDrivers stay on NVIDIA for xrdp |

## Risks

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Profile chain break breaks a hidden dependency | Low | Import ALL base.nix modules (same list), diff rog imports with base.nix |
| greetd + xrdp racing on session management | Low | xrdp uses xrdp-sesman (separate PAM stack), greetd occupies VT7 only |
| Intel iGPU not present or not detected by kernel | Low | User confirmed hybrid graphics; `modesetting` driver auto-loads for Intel |
| NixOS build time increase | Low | omarchy-nix is already in the flake closure (btop module); no new inputs |

## Rollout Plan

1. `nixos-build dry` -- validate syntax, check module imports resolve
2. Deploy modules WITHOUT enabling greetd (`omarchy.greeter.type` unset or greetd masked) -- verify xrdp + all 20 services still work
3. Enable greetd + regreet, test local graphical login on iGPU
4. Keep previous generation for `nixos-rebuild --rollback`

## Rollback Plan

`nixos-rebuild switch --rollback` to the generation before first Hyprland deployment. xrdp and all services unaffected -- they continue running on separate GPU.

## Dependencies

None. omarchy-nix already in flake inputs (via shared-modules.nix btop import).

## Success Criteria

- [ ] `nix flake check --no-build` passes with omarchy-nix in rog extraModules
- [ ] xrdp MATE sessions still work after profile chain break (no regression)
- [ ] greetd + regreet renders on rog's internal display (Intel iGPU)
- [ ] User can log in via regreet → Hyprland desktop session starts
- [ ] All 20+ server services (arr-stack, jellyfin, nginx, docker, wireguard, etc.) remain operational
- [ ] greetd + xrdp coexist without session conflicts (both running, separate PAM stacks)
- [ ] Rollback recovers pre-Hyprland state without service interruption
