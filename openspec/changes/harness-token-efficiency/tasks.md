# Tasks: Harness Token Efficiency

## Review Workload Forecast

| Field | Value |
|---|---|
| Estimated changed lines | 330–390 (including ~150 vendor lines and runbook) |
| 400-line budget risk | Medium |
| Chained PRs recommended | No |
| Suggested split | Single PR: package/config → integrations → runbook/verification |
| Delivery strategy | single-pr (proposal uses one PR) |
| Chain strategy | size-exception |

Decision needed before apply: Yes
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Medium

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|---|---|---|---|---|---|
| 1 | Expose, install, and privacy-configure RTK | Single | `nix flake check --no-build` | `rtk --version`; telemetry status | Revert `lib/packages.nix` and `shared/opencode.nix` |
| 2 | Deploy OpenCode and Claude integrations | Single | `nix flake check --no-build` | Representative rewrite/pass-through and hook checks | Revert integration files and vendor |
| 3 | Document and prove pilot behavior | Single | `format-nix --check` | Gain/history plus raw/intercepted exit comparisons | Revert `docs/rtk-pilot.md` and integration change |

## Phase 1: Foundation and Package Configuration

- [x] 1.1 Modify `lib/packages.nix` to expose `rtk = pkgs.rtk` in both Linux and Darwin `commonPackages`; verify all four host evaluations resolve 0.41.0. Satisfies R1, R8.
- [x] 1.2 Modify `shared/opencode.nix` to install `pkgs.rtk` and set `home.sessionVariables.RTK_TELEMETRY_DISABLED = "1"`; run `format-nix` and flake evaluation. Satisfies R1, R2, R8.

## Phase 2: Managed Runtime Integrations

- [x] 2.1 RED: inspect `hooks/opencode/rtk.ts` (read-only) from GitHub `rtk-ai/rtk` tag `v0.41.0`; record checks for `tool.execute.before`, unsupported/failure fail-open, and `RTK_DISABLED=1` behavior before editing. Satisfies R3, R7.
- [x] 2.2 Vendor the reviewed upstream `hooks/opencode/rtk.ts` into `shared/opencode/rtk.ts` (fetch/review required), then modify `shared/opencode/plugins.nix`, `shared/opencode/runtime-config.nix`, and `shared/opencode-profile.nix` for managed copy/remove and enablement. Verify lifecycle paths. Satisfies R3, R7.
- [x] 2.3 RED: exercise Claude settings containing existing values/hooks and non-Bash tools; assert one canonical RTK matcher and preservation before implementation. Satisfies R4.
- [x] 2.4 Modify `shared/claude-code.nix` with declarative `hooks.preToolUse`, append/deduplicate the Bash `rtk hook claude` entry, and preserve generated-settings authority. Verify JSON shape and Read/Grep/Glob bypass. Satisfies R4, R7.

## Phase 3: Pilot Runbook

- [x] 3.1 Create `docs/rtk-pilot.md` covering installation/privacy, Git/go/flake/nixos-build workloads, gain/history recording, shell-output-only limits, built-in-tool gaps, raw bypass, failure recall, disable/revert, and no total-spend claims. Satisfies R5, R6, R7.

## Phase 4: Integration Verification

- [x] 4.1 Verify every host with `nix eval`, then run `format-nix --check`, `nix flake check --no-build`, `rtk --version`, telemetry status, and gain/history reports. Satisfies R1, R2, R5, R8.
- [x] 4.2 Run representative commands raw (`RTK_DISABLED=1`) and intercepted, including success and intentional failure; compare outputs/results and `$?`, inspect scoped diff for prohibited files/scripts/secrets. Satisfies R3, R5, R6, R7, R8.

## Requirement Traceability

R1: 1.1–1.2, 4.1 · R2: 1.2, 4.1 · R3: 2.1–2.2, 4.2 · R4: 2.3–2.4 · R5: 3.1, 4.1–4.2 · R6: 3.1, 4.2 · R7: 2.1–2.2, 2.4, 3.1, 4.2 · R8: 1.1–1.2, 4.1–4.2.
