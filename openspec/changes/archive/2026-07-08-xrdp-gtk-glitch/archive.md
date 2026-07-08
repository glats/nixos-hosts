# Archive Report: xrdp Compositor Configuration

**Date**: 2026-07-08
**Status**: ARCHIVED
**Archive reason**: Completed SDD cycle — all requirements met, all scenarios pass, build validation green.

---

## Summary

Removed picom compositor from rog and thinkcentre host configurations and enabled MATE's built-in marco compositor for xrdp virtual X11 sessions. The picom XRender backend is incompatible with xrdp's virtual frame buffer (upstream: yshui/picom#1433), causing GTK apps and MATE panel to disappear or turn black. Marco's software XRender compositor works correctly in this environment.

## Changes Applied

| File | Change |
|------|--------|
| `hosts/rog/home/modules.nix` | Removed `../../../home-linux/picom.nix` import |
| `hosts/thinkcentre/home/modules.nix` | Removed `../../../home-linux/picom.nix` import |
| `modules/base/dconf.nix` | Changed `compositing-manager = false` to `true`, removed locks block |

## Spec Compliance

4/4 scenarios PASS:

| Requirement | Scenarios | Result |
|-------------|-----------|--------|
| External compositors NOT active on xrdp hosts | rog excludes picom, thinkcentre excludes picom | PASS |
| marco compositing enabled on MATE hosts | MATE host enables compositing, Non-MATE unaffected | PASS |
| Build validation passes | Flake check for both hosts | PASS |

## Non-Goal Compliance

3/3 PASS: t14/mact2 unchanged, picom.nix preserved, no xrdp service changes.

## Task Completion

6/6 tasks complete — all implementation, formatting, and verification tasks done.

## Verification

- `nix flake check --no-build` exits 0
- All changed files formatted via `format-nix`
- No picom references remain in rog or thinkcentre host configs

## Artifacts Present

| Artifact | Status |
|----------|--------|
| proposal.md | Present |
| spec.md | Present |
| tasks.md | Present (6/6 complete) |
| apply-progress.md | Present |
| verify.md | Present |
| archive.md | Present (this file) |

## Risks

- marco compositing may tear on rog direct HDMI console with NVIDIA 580.legacy (low likelihood). Mitigation: conditional picom wrapper for rog only if reported.

## SDD Cycle Complete

The change has been fully planned, implemented, verified, and archived.
Ready for the next change.
