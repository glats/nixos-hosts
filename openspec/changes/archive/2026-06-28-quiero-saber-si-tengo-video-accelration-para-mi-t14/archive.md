# Archive Report

**Change**: quiero saber si tengo video accelration para mi t14
**Archived**: 2026-06-28
**Verdict**: ✅ PASS
**Commit**: `aaf3a34` on master (3 files, +43/-1)

## Artifact Contents

| Artifact | Present |
|----------|---------|
| exploration.md | ✅ |
| proposal.md | ✅ |
| tasks.md | ✅ |
| apply-progress.md | ✅ |
| verify-report.md | ✅ |

## What Was Done

Confirmed t14 has working VA-API hardware video acceleration (radeonsi driver via Mesa). Documented the verification recipe in `modules/hardware/amd-laptop.nix` (12-line comment block). Clarified Mesa VA driver provenance in `modules/base/profiles/media.nix` (rewritten section header, +25/-1 lines). Set `hwdec=vaapi` as mpv default in `hosts/t14/home/omarchy.nix` (+7 lines).

All 7 tasks complete. Live verification on t14 confirmed:
- `vainfo` reports radeonsi driver with H264/HEVC/VP9/MPEG2/VC1/JPEG decode
- `mpv --hwdec=vaapi` outputs "Using hardware decoding (vaapi)"
- `~/.config/mpv/mpv.conf` deployed as home-manager symlink with `hwdec=vaapi`

## Deviation Recorded

**Task 2.2**: `libva-mesa-driver` is not a valid nixpkgs attribute. The radeonsi VA driver ships inside the `mesa` package via the gallium VA-API interface. Resolved by documenting this provenance in the media.nix section header instead of adding a non-existent package.

## Stale Checkbox Reconciliation

- **Task 3.4** was marked `[ ]` in tasks.md with a pre-switch blocker note.
- **Verify report** confirms the switch was approved and run (commit `aaf3a34` deployed).
- **Post-switch live verification** confirmed mpv.conf deployed, `vainfo` works, and mpv uses VA-API.
- **Reconciliation**: checkbox updated from `[ ]` to `[x]` at archive time with full proof from apply-progress and verify-report. See verify-report.md for live verification output.

## Specs Synced

No spec artifact existed for this change (proposal-only — documentation + conditional config change, no new spec-level behavior). No main specs to merge.

## SDD Cycle Complete

This change has been fully explored, proposed, applied, verified, and archived. Ready for the next change.
