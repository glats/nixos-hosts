# Design: Remove CUDA Build-From-Source & Move Kernel to Per-Host Config

## Technical Approach

Eliminate two build-from-source bottlenecks by (1) removing uncached CUDA packages from `nvidia.nix` and inlining `pkgs.btop` directly, and (2) moving `boot.kernelPackages` out of shared `boot.nix` into each host's `default.nix` with a per-host kernel choice. This is a pure selection/config change — no new modules, no new abstractions, no data migration.

## Architecture Decisions

### Decision: Inline `pkgs.btop` directly, remove `let` binding

**Choice**: Delete the `let btopWithCuda = pkgs.btop.override { cudaSupport = true; }; in` binding entirely. Use `pkgs.btop` inline in `security.wrappers.btop.source`.
**Alternatives considered**: Keep `btopWithCuda = pkgs.btop;` as an alias — rejected because the name `btopWithCuda` is misleading when CUDA is gone, and it adds an indirection for a single use site.
**Rationale**: One reference site, no CUDA, no alias needed. Cleanest diff, no dead naming.

### Decision: Per-host `boot.kernelPackages` inline, following each host's existing style

**Choice**: Set `boot.kernelPackages` inline in each host's `default.nix`, matching each host's existing boot-attribute pattern:
- **rog**: Add inside the existing `boot = { ... }` block (line 117–120).
- **thinkcentre**: Add as a standalone `boot.kernelPackages = pkgs.linuxPackages;` line after the `boot-settings` block (no `boot = {}` block exists).
- **t14**: Add as a standalone `boot.kernelPackages = pkgs.linuxPackages_zen;` line near the other scattered `boot.*` attributes (line 117–130).
**Alternatives considered**: Create a per-host boot module (e.g. `hosts/rog/boot.nix`) — rejected as over-engineering for a one-liner. Add a `boot-settings.kernelPackages` mkOption — rejected because the whole point is removing shared kernel selection.
**Rationale**: Each host already imports `boot.nix` for shared config (systemd-boot, plymouth, kernelParams). Kernel choice is a one-liner that belongs next to the host's other boot overrides. No new files, no new abstractions.

### Decision: Remove `nvtopPackages.nvidia`, do not replace

**Choice**: Delete `nvtopPackages.nvidia` from `environment.systemPackages` with no replacement.
**Alternatives considered**: Replace with `nvidia-smi` wrapper — rejected because `nvidia-smi` is already installed via the NVIDIA driver package automatically.
**Rationale**: `nvidia-smi` provides equivalent GPU monitoring. nvtop was a convenience tool whose uncached CUDA dependencies caused 45+ minute rebuilds.

## Data Flow

No data flow change. Same boot sequence, same NVIDIA driver stack, same btop wrapper — just sourced from the binary cache instead of built from source.

```
Host default.nix (kernelPackages) ──→ boot.nix (loader, plymouth, params)
                                              ↓
                                      NixOS evaluation
                                              ↓
nvidia.nix (pkgs.btop, no nvtop) ──→ security.wrappers.btop ──→ cached binary
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `linux/system/hardware/nvidia.nix` | Modify | Remove `let` binding (line 15–17 becomes `{`), delete `nvtopPackages.nvidia` from systemPackages (line 63), change wrapper source to `"${pkgs.btop}/bin/btop"` (line 71) |
| `linux/system/features/boot.nix` | Modify | Delete `kernelPackages = pkgs.linuxPackages_zen;` (line 44) |
| `hosts/rog/default.nix` | Modify | Add `kernelPackages = pkgs.linuxPackages;` inside existing `boot = { ... }` block (after line 118) |
| `hosts/thinkcentre/default.nix` | Modify | Add `boot.kernelPackages = pkgs.linuxPackages;` after `boot-settings` block (after line 59) |
| `hosts/t14/default.nix` | Modify | Add `boot.kernelPackages = pkgs.linuxPackages_zen;` near other `boot.*` attributes (after line 117) |

## Interfaces / Contracts

No new interfaces. The `security.wrappers.btop` contract is preserved — same `source` path pattern, same `cap_perfmon=ep` capability. The `boot-settings` option interface is unchanged (kernel selection was never an option on it).

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Static | `nix flake check --no-build` passes on rog, thinkcentre, t14 | Run validation after edits, `format-nix` first |
| Static | No references to `nvtopPackages.nvidia` or `cudaSupport` remain | `grep -r "nvtopPackages.nvidia\|cudaSupport" linux/ hosts/` |
| Static | Each host `default.nix` has explicit `boot.kernelPackages` | `grep -r "boot.kernelPackages" hosts/` |
| Runtime | rog reboots with `pkgs.linuxPackages` (default kernel) | Deploy + reboot (post-merge, manual) |
| Runtime | btop wrapper works with `cap_perfmon` | Run `btop` on rog after deploy |

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary.

## Migration / Rollout

No migration required. Rollback via `git revert`. No state or data migration — purely package/kernel selection changes.

## Open Questions

None — all three design decisions are resolved from codebase patterns.