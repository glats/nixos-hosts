# Archive Report: nixos-host-pattern-refactor

**Status**: COMPLETED ✅
**Archived**: 2026-06-23
**Artifact Store**: hybrid (openspec + engram)

---

## What Was Done

Removed the last `hostName` conditional from `home-linux/` by decomposing `btop.nix` into focused fragments. Pure structural refactor — zero behavioral change.

**Old**: `home-linux/btop.nix` — monolithic module with `mkIf (hostName != "t14")` / `mkIf (hostName == "t14")` branches.

**New** (3 files replacing 1):
| File | Purpose | Imported by |
|------|---------|-------------|
| `home-linux/btop-theme.nix` | Shared theme file (no conditionals) | `shared-modules.nix` |
| `home-linux/btop-file.nix` | File-based config for rog/thinkcentre | `hosts/{rog,thinkcentre}/home/modules.nix` |
| `home-linux/btop-settings.nix` | HM settings for t14 (lib.mkForce) | `hosts/t14/home/omarchy.nix` |

## Files Changed

| Action | File |
|--------|------|
| Deleted | `home-linux/btop.nix` |
| Created | `home-linux/btop-theme.nix` |
| Created | `home-linux/btop-file.nix` |
| Created | `home-linux/btop-settings.nix` |
| Modified | `home-linux/shared-modules.nix` (replace `btop.nix` → `btop-theme.nix`) |
| Modified | `hosts/rog/home/modules.nix` (append `btop-file.nix`) |
| Modified | `hosts/thinkcentre/home/modules.nix` (append `btop-file.nix`) |
| Modified | `hosts/t14/home/omarchy.nix` (append `btop-settings.nix`) |

## Tasks

14/14 tasks complete. All checked in `tasks.md`.

## Verification Results

| Check | Result |
|-------|--------|
| Zero `hostName` refs in `home-linux/` | ✅ PASS |
| `btop-theme.nix` exists | ✅ PASS |
| `btop-file.nix` exists | ✅ PASS |
| `btop-settings.nix` exists | ✅ PASS |
| `btop.nix` deleted | ✅ PASS |
| Shared modules import `btop-theme.nix` | ✅ PASS |
| Rog imports `btop-file.nix` | ✅ PASS |
| Thinkcentre imports `btop-file.nix` | ✅ PASS |
| t14 imports `btop-theme.nix` + `btop-settings.nix` | ✅ PASS |
| Behavioral equivalence (all 3 hosts) | ✅ PASS |
| `nix flake check --no-build` | ✅ PASS |
| `nix fmt` formatting | ✅ PASS |

## Specs Synced

| Domain | Action | Details |
|--------|--------|---------|
| `home-manager` | Created | `openspec/specs/home-manager/spec.md` — flattened from delta spec |

## SDD Cycle Complete

All phases: explore → propose → spec → tasks → apply → verify → archive.
Ready for next change.
