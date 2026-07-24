# Proposal: Per-Host Package Profiles

## Intent

`linux/system/base/packages.nix` applies `sharedProfiles = [core dev media virt browsers]` to ALL Linux hosts. Profiles `core.nix` and `media.nix` contain hardware-specific packages that reach wrong hosts: `asus-fan-control` (ASUS-only) on thinkcentre/t14, `pipewire-module-xrdp` (xrdp-only) on t14, `intel-vaapi-driver`/`libva-vdpau-driver` (Intel GPU) on t14 (AMD). Extract hardware-specific packages to host `environment.systemPackages`.

## Scope

### In Scope

- Remove: `asus-fan-control`, `pipewire-module-xrdp` from `core.nix`
- Remove: `intel-vaapi-driver`, `libva-vdpau-driver` from `media.nix`
- Add: 4 hardware packages to `rog/default.nix` `environment.systemPackages`
- Add: 3 hardware packages to `thinkcentre/default.nix` `environment.systemPackages`

### Out of Scope

- Profile selection per host (sharedProfiles stays as-is — phase 2)
- Splitting dev/virt/browsers per host (phase 2)
- New Nix options, modules, or files

## Capabilities

**New**: None  
**Modified**: None  

Pure refactor — no behavioral change. Each host ends up with identical packages as before.

## Approach

Minimal diff, no indirection. Remove 4 lines from shared profiles. Add 4 lines to rog, 3 lines to thinkcentre. Zero new options, modules, or files.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `linux/system/base/profiles/core.nix` | Modified | Remove lines 87-88 |
| `linux/system/base/profiles/media.nix` | Modified | Remove lines 39-40 |
| `hosts/rog/default.nix` | Modified | Add `environment.systemPackages` block |
| `hosts/thinkcentre/default.nix` | Modified | Add `environment.systemPackages` block |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| `docker` CLI lost on thinkcentre | Low | `docker` in virt.nix is the CLI package; thinkcentre imports `services/docker.nix` which provides the daemon. Verify with `nix flake check` |
| Build breaks on missing package refs | Low | `format-nix && nix flake check --no-build` catches syntax/import errors |

## Rollback Plan

`git revert` the single commit. Each host's package set is identical before and after — reversion restores with no state loss.

## Dependencies

None.

## Success Criteria

- [ ] `format-nix` passes
- [ ] `nix flake check --no-build` passes for rog, thinkcentre, t14
- [ ] Each host's resolved `environment.systemPackages` is identical to current state
