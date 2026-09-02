# Archive Report: mact2-openai-tls-tunnel-via-rog

**Change:** mact2-openai-tls-tunnel-via-rog
**Archived:** 2026-09-02
**Archive path:** `openspec/changes/archive/2026-09-02-mact2-openai-tls-tunnel-via-rog/`
**Mode:** hybrid (openspec filesystem + Engram observation)
**Re-run:** initial archive attempt blocked on the CRITICAL verify gate; gate cleared — the admitted Round-4 closure envelope is recorded below.

## Verify Gate

The verify-report.md carries the admitted Round-4 closure envelope (`schema: gentle-ai.verify-result/v1`):

- `verdict: pass`, `blockers: 0`, `critical_findings: 0`
- `requirements: 19/19`, `scenarios: 24/24`
- Disposition: 9 tool-verified, 8 production-evidenced, 7 owner-waived (2026-09-02 system-owner decision; WAIVED is distinct from PASS execution evidence)
- No CRITICAL findings — archive proceeds.

## Task Completion Gate — Checkbox Reconciliation (exceptional, proof-backed)

All 35 implementation tasks are marked `[x]`. Per the Task Completion Gate, unchecked USER-RUN procedural tasks (0.3, 1.5 live, 2.4–2.6, 2.5.2, 3.1–3.4, 5.1–5.5) were reconciled at archive time because the Round-4 closure envelope proves each corresponding requirement/scenario closed (tool-verified PASS, production-evidenced PASS, or owner-waived RESOLVED-BY-WAIVER). The full rationale is a header note in the archived `tasks.md`. Archive-time tasks 6.6/6.7 were completed here (6.6 = this spec sync; 6.7 = confirmed `secrets/shared/openai-tunnel.yaml` never committed — `git log --all` empty — live secret is `secrets/shared/opencode-tunnel.yaml` under `link/uuid_*` keys).

## Spec Sync

| Domain | Action | Details |
|--------|--------|---------|
| opencode-runtime-proxy | Updated (MODIFIED delta onto existing baseline) | 6 requirements; delta's 3 MODIFIED requirements (mact2 Runtime Provider Transition, Gated Gateway Availability and Retirement, Scoped Rollback) merged; baseline No Legacy Gateway / Secret Hygiene / No Functional Regression preserved with mact2 clause updated to native. Stale gateway-retention wording fixed: retirement landed first (via remove-opencode-proxy-legacy), office production proof of the native private-link path came later (production-validated in-building 2026-09-01). |
| mact2-openai-tls-tunnel | Created (NEW) | Full tunnel/transport spec; naming normalized to deployed reality (link.mode, link.directDomains/Cidrs, home-out, sing-box daemon, org.nixos.sing-box, /run/secrets/rendered/sing-box.json, bin/opencode-home, bin/device-link). |
| mact2-openai-native-auth | Created (NEW) | Native OAuth spec; names already current. |
| tunnel-device-onboarding | Created (NEW) | Device lifecycle spec; bin/tunnel-device-link normalized to bin/device-link. |

Canonical specs now present in `openspec/specs/`: `opencode-runtime-proxy`, `mact2-openai-tls-tunnel`, `mact2-openai-native-auth`, `tunnel-device-onboarding` (plus pre-existing `boot`, `hardware-nvidia`).

## Naming Normalization (synced specs only)

Synced canonical specs use current identifiers; historical pre-rename identifiers remain in the archived exploration/design (not scrubbed). Rename map applied: `tunnel-out`→`home-out`, `tunnel.mode`→`link.mode`, `tunnel.directDomains/directCidrs`→`link.*`, `sing-box-tunnel.nix`→`sing-box-link.nix`, `org.nixos.sing-box-tunnel`→`org.nixos.sing-box`, `/run/secrets/rendered/sing-box-tunnel.json`→`sing-box.json`, `bin/tunnel-device-link`→`bin/device-link`, `bin/opencode-tunnel`→`bin/opencode-home`.

## Mechanical Copy Verification

The change folder was moved with `git mv` (fallback `mv` not needed). MANDATORY `diff -r` readback of the pre-move recursive snapshot vs. the archived destination returned an **empty diff (PASS)** — byte identity preserved. `archive-report.md` is additive-only and was not in the source snapshot.

## Validation

- `nix flake check --no-build`: only the pre-existing GC'd hyprland (t14) failure is acceptable; unrelated hosts pass.
- `format-nix`: idempotent (no diff after run).
- Verify report's own `test_exit_code: 0` and `build_exit_code: 0` (preserved evidence_revision sha256:df47010c..., build_output sha256:82123ea1...).

## Engram Traceability

This report is persisted to Engram as `sdd/{change-name}/archive-report` (hybrid mode). Observation IDs for the artifacts read in the archive phase: see Engram record. Artifacts read during this phase: `tasks.md`, `verify-report.md`, all four delta specs, and the existing `openspec/specs/opencode-runtime-proxy/spec.md` baseline.
