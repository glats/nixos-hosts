# Proposal: Remove CUDA Build-From-Source & Move Kernel to Per-Host Config

## Intent

Every `nixos-rebuild switch` on rog takes 45-100 minutes, and thinkcentre/t14 take 30-60 minutes, due to build-from-source. Two root causes: (1) CUDA packages (`nvtopPackages.nvidia`, `btop.override { cudaSupport = true; }`) aren't cached because cache.nixos.org can't distribute unfree CUDA toolkits, and (2) `linuxPackages_zen` isn't in the binary cache, forcing all three Linux hosts to compile the kernel from source. This eliminates rebuild wait times without losing functional capability.

## Scope

### In Scope
- Remove `nvtopPackages.nvidia` from `environment.systemPackages` in `nvidia.nix`
- Replace `btop.override { cudaSupport = true; }` with cached `pkgs.btop`
- Remove `boot.kernelPackages = pkgs.linuxPackages_zen` from shared `boot.nix`
- Add explicit `boot.kernelPackages = pkgs.linuxPackages` to rog and thinkcentre
- Add explicit `boot.kernelPackages = pkgs.linuxPackages_zen` to t14 (Hyprland stays on zen)

### Out of Scope
- NVIDIA driver (legacy_580 stays); Docker GPU (`nvidia-container-toolkit`, `nvidia-vaapi-driver`) already cached
- ollama, openfang, NVIDIA_API_KEY — untouched
- btop security wrapper — kept, just references cached btop binary

## Capabilities

### New Capabilities
None — this is a package/kernel selection change, not a new feature.

### Modified Capabilities
None — spec-level behavior unchanged. Hosts boot the same way with a different kernel or without CUDA userspace tools.

## Approach

1. **nvidia.nix**: Delete `nvtopPackages.nvidia` from `systemPackages`. Replace `btopWithCuda` let-binding with inline `pkgs.btop` in both the systemPackage and the security wrapper.
2. **boot.nix**: Remove `boot.kernelPackages = pkgs.linuxPackages_zen` line. All other boot config (systemd-boot, plymouth, kernel params) stays.
3. **Host configs**: Add per-host `boot.kernelPackages`. rog/thinkcentre get cached `pkgs.linuxPackages`; t14 keeps `pkgs.linuxPackages_zen` for desktop performance.
4. **Verify**: `nix flake check --no-build` on all three hosts.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `linux/system/hardware/nvidia.nix` | Modified | Remove CUDA packages, use cached btop |
| `linux/system/features/boot.nix` | Modified | Remove shared `kernelPackages` line |
| `hosts/rog/default.nix` | Modified | Add explicit `boot.kernelPackages = pkgs.linuxPackages` |
| `hosts/thinkcentre/default.nix` | Modified | Add explicit `boot.kernelPackages = pkgs.linuxPackages` |
| `hosts/t14/default.nix` | Modified | Add explicit `boot.kernelPackages = pkgs.linuxPackages_zen` |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| GPU monitoring lost without nvtop | Low | `nvidia-smi` provides equivalent GPU stats; nvtop is a convenience tool |
| Zen kernel regression on t14 | Low | Zen stays on t14; only headless hosts switch to default |
| CUDA dependency in other packages | Low | Only btop and nvtop used CUDA; verified in exploration |

## Rollback Plan

Revert the commit (`git revert`). No state or data migration needed — purely package/kernel selection changes.

## Dependencies

None.

## Success Criteria

- [ ] `nix flake check --no-build` passes on rog, thinkcentre, and t14
- [ ] No references to `nvtopPackages.nvidia` or `btop.override { cudaSupport = true; }` remain
- [ ] Each host has explicit `boot.kernelPackages` in its `default.nix`
- [ ] `boot.nix` no longer sets `kernelPackages`
