# hardware-nvidia Specification

## Purpose

NVIDIA hardware configuration for hosts with NVIDIA GPUs. Controls driver, container toolkit, btop capability wrapper. Applies to rog only.

## Requirements

### Requirement: Cache-Only Package Policy

The NVIDIA module MUST NOT include build-from-source unfree packages in `environment.systemPackages`. All packages MUST come from the binary cache.

#### Scenario: No build-from-source CUDA tools

- GIVEN `nvidia.nix` is imported on rog
- WHEN the configuration is evaluated
- THEN `nvtopPackages.nvidia` MUST NOT appear in `environment.systemPackages`

#### Scenario: Cached btop without CUDA override

- GIVEN `nvidia.nix` is imported on rog
- WHEN the configuration is evaluated
- THEN btop MUST be the cached `pkgs.btop` with no `cudaSupport` override

### Requirement: Preserved btop Security Wrapper

The btop security wrapper MUST continue to work, referencing the cached binary with `cap_perfmon` capabilities.

#### Scenario: btop wrapper references cached binary

- GIVEN `nvidia.nix` is imported
- WHEN `security.wrappers.btop` is evaluated
- THEN `source` MUST point to the cached `pkgs.btop` binary
- AND `capabilities` MUST equal `"cap_perfmon=ep"`

### Requirement: Unchanged NVIDIA Driver Stack

The NVIDIA driver, container toolkit, and VA-API driver MUST remain unchanged.

#### Scenario: Driver and Docker GPU untouched

- GIVEN `nvidia.nix` is imported
- WHEN configuration is evaluated
- THEN `hardware.nvidia.package` MUST be `legacy_580`
- AND `nvidia-container-toolkit` MUST be enabled
- AND `nvidia-vaapi-driver` MUST be in `hardware.graphics.extraPackages`
