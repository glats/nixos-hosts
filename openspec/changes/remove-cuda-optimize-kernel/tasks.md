# Tasks: Remove CUDA Build-From-Source & Move Kernel to Per-Host Config

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~16 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | single-pr |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

## Phase 1: nvidia.nix — Remove CUDA Build-From-Source

- [x] 1.1 In `linux/system/hardware/nvidia.nix`: **ADJUSTED SCOPE** — removed ONLY `nvtopPackages.nvidia` from `environment.systemPackages`. `btopWithCuda` let-binding, `security.wrappers.btop`, and `source = "${btopWithCuda}/bin/btop"` all KEPT untouched per user confirmation.
  - **Verify**: `grep -r "nvtopPackages.nvidia" linux/` returns empty; `btopWithCuda` still present

## Phase 2: Boot — Per-Host Kernel Selection

- [x] 2.1 In `linux/system/features/boot.nix`: delete `kernelPackages = pkgs.linuxPackages_zen;` (line 44)
  - **Verify**: `grep "kernelPackages" linux/system/features/boot.nix` returns empty — PASS

- [x] 2.2 In `hosts/rog/default.nix`: add `boot.kernelPackages = pkgs.linuxPackages;` inside existing `boot = { ... }` block (line 118)
  - **Verify**: `grep "kernelPackages" hosts/rog/default.nix` matches `pkgs.linuxPackages` — PASS

- [x] 2.3 In `hosts/thinkcentre/default.nix`: add `boot.kernelPackages = pkgs.linuxPackages;` after the `boot-settings` block (line 61)
  - **Verify**: `grep "kernelPackages" hosts/thinkcentre/default.nix` matches `pkgs.linuxPackages` — PASS

- [x] 2.4 In `hosts/t14/default.nix`: add `boot.kernelPackages = pkgs.linuxPackages_zen;` after `boot-settings.enable = true;` (line 118)
  - **Verify**: `grep "kernelPackages" hosts/t14/default.nix` matches `pkgs.linuxPackages_zen` — PASS

## Phase 3: Verification

- [x] 3.1 Run `format-nix && nix flake check --no-build` on rog, then confirm `grep -r "nvtopPackages.nvidia" linux/ hosts/` returns empty and `grep -r "boot.kernelPackages" hosts/` shows an entry for each of rog, thinkcentre, and t14
  - **Verify**: `nix flake check --no-build` exits 0; all grep checks pass
