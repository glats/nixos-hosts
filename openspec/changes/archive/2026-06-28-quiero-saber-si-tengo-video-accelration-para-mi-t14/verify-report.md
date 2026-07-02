## Verification Report

**Change**: quiero-saber-si-tengo-video-accelration-para-mi-t14
**Version**: N/A (no spec artifact — proposal-only change)
**Mode**: Standard
**Verification date**: 2026-06-28

### Completeness

| Metric | Value |
|--------|-------|
| Tasks total | 7 (6 implementation + 1 blocked) |
| Tasks complete | 7 |
| Tasks incomplete | 0 |

**Note**: Task 3.4 (post-switch re-verification) was marked BLOCKED in apply-progress pending `nixos-build switch` approval. The switch has since been run (commit aaf3a34 is deployed), and this verification report covers the post-switch live checks, so 3.4 is now ✅ complete.

### Build & Tests Execution

**Build**: ✅ Passed
```text
$ nix flake check --no-build
all checks passed!
warning: The check omitted these incompatible systems: x86_64-darwin

$ nixos-build dry (pre-switch, from apply-progress)
Built nixos-system-t14-26.11.20260626.e73de5b.drv
```

**Live Verification**: ✅ 4/4 checks passed

```text
$ vainfo
libva info: VA-API version 1.23.0
libva info: Trying to open /run/opengl-driver/lib/dri/radeonsi_drv_video.so
vainfo: Driver version: Mesa Gallium driver 26.1.3 for AMD Radeon Graphics (radeonsi, renoir, ACO, ...)
vainfo: Supported profile and entrypoints
      VAProfileH264ConstrainedBaseline: VAEntrypointVLD (+ EncSlice)
      VAProfileH264Main:               VAEntrypointVLD (+ EncSlice)
      VAProfileH264High:               VAEntrypointVLD (+ EncSlice)
      VAProfileHEVCMain:               VAEntrypointVLD (+ EncSlice)
      VAProfileHEVCMain10:             VAEntrypointVLD (+ EncSlice)
      VAProfileVP9Profile0:            VAEntrypointVLD
      VAProfileVP9Profile2:            VAEntrypointVLD
      VAProfileMPEG2Simple/Main, VC1Simple/Main/Advanced, JPEGBaseline: VAEntrypointVLD

$ mpv --hwdec=vaapi /tmp/test-video.mp4
[vd] Looking at hwdec h264-vaapi...
[vo/gpu/vaapi/vaapi] Initialized VAAPI: version 1.23
[vd] Trying hardware decoding via h264-vaapi.
Using hardware decoding (vaapi).

$ cat ~/.config/mpv/mpv.conf
hwdec=vaapi

$ ls -la ~/.config/mpv/mpv.conf
lrwxrwxrwx 1 glats users 83 Jun 28 21:13 -> /nix/store/...-hm_mpvmpv.conf
```

**Coverage**: ➖ Not available (no test suite in this NixOS config repo)

### Spec Compliance Matrix

No spec artifact exists for this change (proposal-only — documentation + conditional config change, no new spec-level behavior). Skipping spec compliance.

### Correctness (Static Evidence)

| Task | Requirement | Status | Evidence |
|------|------------|--------|----------|
| 1.1 | `vainfo` on t14 confirms radeonsi driver with decode profiles | ✅ Implemented | Recorded in apply-progress; re-verified live: radeonsi, H264/HEVC/VP9/MPEG2/VC1/JPEG |
| 1.2 | `mpv --hwdec=vaapi` end-to-end hardware decode | ✅ Implemented | Recorded in apply-progress; re-verified live: "Using hardware decoding (vaapi)" |
| 2.1 | Verification recipe comment in amd-laptop.nix | ✅ Implemented | Lines 15-25: 11-line comment block with vainfo, mpv, intel_gpu_top recipe |
| 2.2 | VA-API driver documented in media.nix | ✅ Implemented (deviation) | Lines 8-29: section header documents Mesa gallium origin; `libva-mesa-driver` does not exist in nixpkgs — resolved via documentation |
| 2.3 | mpv hwdec=vaapi default in omarchy.nix | ✅ Implemented | Lines 202-207: `xdg.configFile."mpv/mpv.conf".text = "hwdec=vaapi\n"` |
| 3.1 | `format-nix` | ✅ Passed | No diffs produced (per apply-progress) |
| 3.2 | `nix flake check --no-build` | ✅ Passed | All hosts evaluate; mact2 skipped (darwin on linux — expected) |
| 3.3 | `nixos-build dry` on t14 | ✅ Passed | Closure includes hm_mpvmpv.conf.drv (per apply-progress) |
| 3.4 | Post-switch re-verification | ✅ Passed | vainfo + mpv confirmed live (this report); mpv.conf deployed as home-manager symlink |

### Coherence (Design)

| Decision | Followed? | Notes |
|----------|-----------|-------|
| Option A: Document verification recipe as comments | ✅ Yes | 11-line block in amd-laptop.nix |
| Option B: Conditionally add `libva-mesa-driver` if missing | ✅ Adapted | Driver not missing (radeonsi loaded), AND `libva-mesa-driver` attribute doesn't exist in nixpkgs. Resolved by documenting the Mesa gallium origin in media.nix header. |
| Option C: Set mpv hwdec=vaapi default for t14 | ✅ Yes | omarchy.nix lines 202-207 |
| Direct-commits-on-main, single commit | ✅ Yes | aaf3a34 on master |

### Design Deviation Analysis — Task 2.2

| Aspect | Detail |
|--------|--------|
| **Deviation** | Task 2.2 specified adding `libva-mesa-driver` to `media.nix`. This package attribute does not exist in current nixpkgs (verified via `nix-instantiate --eval` and nix search). |
| **Root cause** | The radeonsi VA driver is bundled inside the `mesa` derivation (via gallium VA-API interface), not in a separate package. This was discovered during apply Phase 1. |
| **Resolution** | The media.nix section header (lines 8-29) was rewritten to document this provenance. The existing package list (`intel-vaapi-driver`, `libva-vdpau-driver`, `libva-utils`, `intel-gpu-tools`) is preserved unchanged for rog/thinkcentre Intel iGPU fallback. |
| **Intent preserved?** | ✅ Yes. The goal was to make the VA driver dependency explicit and deterministic. The documentation in media.nix achieves this — it tells future readers exactly where the radeonsi driver comes from and that no separate package pin is needed. |
| **Risk introduced?** | None. If a future nixpkgs update ever removes the Mesa gallium VA-API interface, `vainfo` would break — but that breakage would be immediately visible regardless of documentation, and the media.nix header now points readers directly at the root cause. |

**Verdict on deviation**: ACCEPTABLE. The resolution preserves the task's intent (document the VA driver dependency explicitly) while adapting to the reality that nixpkgs does not ship a separate `libva-mesa-driver` package.

### Issues Found

**CRITICAL**: None

**WARNING**: None

**SUGGESTION**: Consider adding an assertion or check in the media profile that verifies `vainfo` works at build time. Currently the VA-API stack relies entirely on runtime verification. A `nix flake check` test that runs `vainfo` in a VM would catch regressions earlier. (Out of scope for this change — suggestion for future work.)

### Verdict

**PASS**

All 7 tasks are complete. Live verification on t14 confirms the radeonsi VA-API driver is loaded, mpv uses hardware decoding with `hwdec=vaapi`, and the mpv.conf default is deployed via home-manager. The flake evaluates cleanly for all hosts. The Task 2.2 deviation is properly documented and preserves intent. Ready for archive.
