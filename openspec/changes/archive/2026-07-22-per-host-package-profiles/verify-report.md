# Verification Report: per-host-package-profiles

## Change
`per-host-package-profiles` — Move 4 hardware-specific packages from shared profiles to host `environment.systemPackages`.

## Mode
Hybrid — design + tasks (no spec). Spec compliance skipped (no spec artifact exists).

## Completeness Table

| Task | Status | Evidence |
|------|--------|----------|
| 1.1 core.nix: remove `asus-fan-control`, `pipewire-module-xrdp`, update comment | ✅ PASS | `core.nix` line 86: `# System utilities`, line 87: `]` — both packages gone, comment updated |
| 1.2 media.nix: remove `intel-vaapi-driver`, `libva-vdpau-driver` | ✅ PASS | `media.nix` lines 39-40: `libva-utils`, `intel-gpu-tools` remain; both target packages gone |
| 2.1 rog/default.nix: add `environment.systemPackages` with 4 pkgs | ✅ PASS | `rog/default.nix` lines 192-197: all 4 packages present before closing `}` on line 199 |
| 2.2 thinkcentre/default.nix: add `environment.systemPackages` with 3 pkgs (no asus-fan-control) | ✅ PASS | `thinkcentre/default.nix` lines 90-94: 3 packages present, no asus-fan-control, before closing `}` on line 96 |
| 3.1 Run `format-nix` then `nix flake check --no-build` | ✅ PASS | `format-nix` exit 0 (no reformatting needed); `nix flake check --no-build` exit 0 ("all checks passed!" for rog, thinkcentre, t14) |

**Task completion: 5/5 tasks verified.**

## Build/Test Evidence

| Command | Exit Code | Output Hash (sha256) | Notes |
|---------|-----------|----------------------|-------|
| `format-nix` | 0 | `2388be123bed7a57059527d9855115a6566eb972e7d65ff55308c53c1650fea1` | "Formatting complete." — 0/369 files reformatted |
| `nix flake check --no-build` | 0 | `ea44292f4469eef44e25b4920c44073326160a3627f955ba86df3a7400401bf9` | "all checks passed!" — rog, thinkcentre, t14 evaluated successfully |

## Spec Compliance Matrix

**Skipped** — no spec artifact (`spec.md`) exists for this change. Only proposal, design, and tasks artifacts were provided.

## Design Coherence Table

| Design Element | Status | Evidence |
|----------------|--------|----------|
| Decision: Inline `environment.systemPackages` over new option/module | ✅ PASS | Both host files use inline `environment.systemPackages = with pkgs; [...]` — no new options, modules, or files created |
| File changes: core.nix (remove 2 pkgs) | ✅ PASS | Confirmed — packages removed, comment updated |
| File changes: media.nix (remove 2 pkgs) | ✅ PASS | Confirmed — packages removed. NOTE: additional comment block (lines 8-29) was added beyond design scope |
| File changes: rog/default.nix (add 4 pkgs) | ✅ PASS | Confirmed — 4 packages in `environment.systemPackages` block |
| File changes: thinkcentre/default.nix (add 3 pkgs) | ✅ PASS | Confirmed — 3 packages (no asus-fan-control) in `environment.systemPackages` block |
| Edge case: docker CLI on thinkcentre | ✅ PASS | `virt.nix` stays in sharedProfiles (core.nix unchanged); docker CLI available |
| Edge case: t14 loses all 4 packages | ✅ PASS | t14 `default.nix` — no hardware packages in `environment.systemPackages` (only teams-for-life wrapper); t14 does not import xrdp.nix |
| Edge case: asus-fan-control module stays | ✅ PASS | rog imports `hardware/asus-fan-control.nix` (line 38) — module config remains; package now in host systemPackages |
| Threat matrix: N/A | ✅ PASS | Correct — no routing/shell/subprocess/VCS boundaries |
| Testing strategy: format-nix + nix flake check --no-build | ✅ PASS | Both commands passed (exit 0) |

## Correctness Table

| Dimension | Status | Notes |
|-----------|--------|-------|
| Task completion | ✅ PASS | 5/5 tasks verified through source inspection |
| Design coherence | ✅ PASS | All design decisions match implementation; 1 minor documentation deviation |
| Spec compliance | 🔲 SKIPPED | No spec artifact exists; not applicable |

## Issues

### CRITICAL
None.

### WARNING
None.

### SUGGESTION
1. **media.nix extra comment block** — The implementation added a 22-line explanatory comment block (lines 8-29) documenting VA-API driver architecture, which was not specified in the design's before/after. The design showed a simple comment `# GPU acceleration (VA-API stack)` but the actual code uses `# GPU acceleration (VA-API stack — see comment block above)`. This is a documentation enhancement, not a functional deviation — the package removal is correct. Consider updating the design artifact to reflect this addition, or trim the comment block if the extra context is unnecessary.

## Final Verdict

**PASS WITH WARNINGS**

All 5 tasks are complete and verified through source inspection and runtime build evidence. Design decisions are coherent with the implementation. The only note is a non-functional documentation addition in `media.nix` beyond the design's specified before/after (SUGGESTION level). No CRITICAL or WARNING issues. The change is ready for archive.