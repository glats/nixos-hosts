# Design: Per-Host Package Profiles

## Technical Approach

Move 4 hardware-specific packages from shared profiles to host `environment.systemPackages`. Zero new options, modules, or files. Pure package relocation.

## Architecture Decisions

### Decision: Inline env.systemPackages over new option/module

| Option | Tradeoff | Decision |
|--------|----------|----------|
| `environment.systemPackages` in host default.nix | Simplest, 0 indirection | ✅ Chosen |
| New `my.hardware.packages` option | Adds option for 4 pkgs | Rejected — YAGNI |
| Split profiles into hardware-specific files | 4-5 new files | Rejected — overkill |

**Rationale**: 4 packages don't justify new abstraction. Host default.nix already imports hardware modules directly.

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `linux/system/base/profiles/core.nix` | Modify | Remove lines 87-88 (`asus-fan-control`, `pipewire-module-xrdp`) |
| `linux/system/base/profiles/media.nix` | Modify | Remove lines 39-40 (`intel-vaapi-driver`, `libva-vdpau-driver`) |
| `hosts/rog/default.nix` | Modify | Add `environment.systemPackages` with 4 pkgs |
| `hosts/thinkcentre/default.nix` | Modify | Add `environment.systemPackages` with 3 pkgs (no asus-fan-control) |

## Before/After

### core.nix (tail)
```nix
# BEFORE (lines 86-88)
  # System utilities (hardware + xrdp audio)
  asus-fan-control
  pipewire-module-xrdp
]

# AFTER
  # System utilities
]
```

### media.nix (VA-API block)
```nix
# BEFORE (lines 38-40)
  # GPU acceleration (VA-API stack)
  intel-vaapi-driver
  libva-vdpau-driver
  libva-utils
  intel-gpu-tools

# AFTER
  # GPU acceleration (VA-API stack)
  libva-utils
  intel-gpu-tools
```

### rog/default.nix (add before closing `}`)
```nix
  environment.systemPackages = with pkgs; [
    asus-fan-control
    pipewire-module-xrdp
    intel-vaapi-driver
    libva-vdpau-driver
  ];
```

### thinkcentre/default.nix (add before closing `}`)
```nix
  environment.systemPackages = with pkgs; [
    pipewire-module-xrdp
    intel-vaapi-driver
    libva-vdpau-driver
  ];
```

## Edge Cases

- **docker CLI on thinkcentre**: `virt.nix` stays in sharedProfiles. No change to it. docker CLI available. ✅
- **t14 loses all 4 packages**: Correct — t14 has AMD GPU (no Intel VA-API), no xrdp, no ASUS hardware. These pkgs were dead weight on t14.
- **asus-fan-control**: rog imports `hardware/asus-fan-control.nix` module separately (service config). Package in core.nix was for CLI tool. Module stays. ✅

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary.

## Testing Strategy

| Layer | What | Approach |
|-------|------|----------|
| Build | Flake eval for 3 hosts | `nix flake check --no-build` |
| Format | Nix formatting | `format-nix` |

## Migration

None. `git revert` restores. Each host's resolved packages identical before/after.