# Tasks: Verify t14 Hardware Video Acceleration

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~15-20 across 3 files |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR, optional 3 logical commits |
| Delivery strategy | direct-commits-on-main |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Verify + doc + config + mpv default in one PR | PR 1 → main | 3 logical commits, ~15-20 lines total |

## Phase 1: Live verification on t14

- [x] 1.1 SSH to t14, run `vainfo`, capture full output. Record driver name (`radeonsi` / `r600`) and that at least one decode profile (e.g. `VAProfileH264`) is reported.
- [x] 1.2 On t14, run `mpv --hwdec=vaapi --vo=gpu <test.mp4>` to confirm decode path; cross-check with `radeontop` if installed.

## Phase 2: Documentation and config edits

- [x] 2.1 Edit `modules/hardware/amd-laptop.nix`: insert a comment block above `hardware.graphics.enable` (line 8) documenting the recipe — `vainfo` signature, `mpv --hwdec=vaapi --vo=gpu`, `radeontop` / `intel_gpu_top`, and expected AMD Gen 4 driver (`radeonsi`).
- [x] 2.2 Edit `modules/base/profiles/media.nix`: add `libva-mesa-driver` to the package list (after line 16, `intel-vaapi-driver`) with a one-line comment "Mesa AMD VA driver — defensive pin against nixpkgs default changes". **DEVIATION**: `libva-mesa-driver` is not a valid nixpkgs attribute in current `nixos-unstable` (2026-06-28) — the radeonsi VA driver is shipped by the `mesa` package itself via the gallium VA-API interface. Resolved by rewriting the section header comment to document this; the existing package list is preserved unchanged. See `apply-progress.md` for the full investigation.
- [x] 2.3 Edit `hosts/t14/home/omarchy.nix`: add `xdg.configFile."mpv/mpv.conf".text = "hwdec=vaapi\n";` next to the existing `xdg.configFile."autostart/..."` block (~line 190) so hardware decode is the mpv default on t14.

## Phase 3: Validation

- [x] 3.1 Run `format-nix` to format all three edited files.
- [x] 3.2 Run `nix flake check --no-build` — confirm no eval errors.
- [x] 3.3 Run `nixos-build dry` on t14 — confirm closure builds.
- [x] 3.4 Post-switch on t14, re-run `vainfo` and `mpv --hwdec=vaapi` to confirm `libva-mesa-driver` is loaded and mpv picks the VA-API path. **Resolved**: switch was approved and run (commit aaf3a34); verify-report confirms mpv.conf deployed as home-manager symlink and hardware decode works.
