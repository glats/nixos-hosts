# Archive Report: per-host-package-profiles

## Change Summary
Moved 4 hardware-specific packages (asus-fan-control, pipewire-module-xrdp, intel-vaapi-driver, libva-vdpau-driver) from shared profiles to host `environment.systemPackages`. Pure package relocation — zero new options, modules, or files.

## Archive Mode
Hybrid (filesystem + Engram)

## Artifact Observation IDs

| Artifact | Engram ID | Type |
|----------|-----------|------|
| explore | #1874 | architecture |
| proposal | #1875 | architecture |
| design | #1876 | architecture |
| tasks | #1877 (updated) | architecture |

## Specs Synced
No delta specs existed — spec creation was skipped in earlier phases. This is an intentional partial archive as no spec artifact was ever created.

## Archive Contents
| File | Status |
|------|--------|
| proposal.md | ✅ |
| design.md | ✅ |
| tasks.md | ✅ (5/5 tasks complete, reconciled from verify-report) |
| verify-report.md | ✅ |

## Archive Path
`openspec/changes/archive/2026-07-22-per-host-package-profiles/`

## Task Completion Verification
All 5 tasks verified through source inspection and build commands. Verify-report confirmed PASS WITH WARNINGS (SUGGESTION level only — extra comment block in media.nix beyond design scope). No CRITICAL or WARNING issues.

## Stale Checkbox Reconciliation
Tasks artifact had stale `- [ ]` checkboxes despite all tasks being complete. Orchestrator explicitly approved reconciliation backed by apply-progress and verify-report proof. All 5 checkboxes updated.

## Review Gate
Status: `allow` — no structured review receipt required per orchestrator instruction. All tasks verified, no delta specs.

## Source of Truth
No main specs directory (`openspec/specs/`) exists — no main spec to update.

## SDD Cycle Complete
The change has been fully explored, proposed, designed, implemented, verified, and archived.
