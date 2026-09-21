# Apply Progress: Preserve Rog Snapshot with postmarketOS Compatibility

## Status

Revised implementation is complete and ready for independent SDD verification.

## Completed Tasks

- [x] 1.1–1.3 Focused tests for exact OpenAI model preservation, BrowserMCP validation/idempotency, and bounded asset actions.
- [x] 2.1–2.3 Opaque agent preservation, post-rsync target JSON adaptation, atomic SSH replacement, exact `rm -f` removals, and sequence preservation.
- [x] 3.1 Command-recorder coverage for transfer ordering, dry-run suppression, target reads, and bounded removals.
- [x] 3.2 Full Go tests, repository formatting, and flake evaluation.
- [x] 3.3 Final snapshot-first and scope review.

## Focused Evidence

| Scenario | Test evidence |
|---|---|
| Failed transfer suppresses compatibility | `TestSnapshotTransferFailureSuppressesCompatibility` proves the compatibility callback is not entered after a transfer error. |
| Models and BrowserMCP are bounded | `TestAdaptOpencodeJSONPreservesAgentsAndDisablesBrowserMCP` preserves the OpenAI graph and model-less agent while disabling only BrowserMCP. |
| Dry run preserves state | `TestApplyCompatibilityDryRunDoesNotUseSSH` reports BrowserMCP and the two fixed asset actions without SSH mutation. |
| Target and asset boundary | `TestApplyCompatibilityReadsTargetAndRemovesOnlyFixedAssets` reads the post-rsync target JSON and records only the two allowed removal paths. |

## Work Unit Evidence

| Evidence | Result |
|---|---|
| Focused test command and exact result | `go -C pkgs/nixos-scripts test ./cmd/sync-opencode-remote` — exit 0; 16 tests passed. |
| Full test command and exact result | `go -C pkgs/nixos-scripts test ./...` — exit 0; 314 tests passed across 33 packages. |
| Formatting and evaluation | `format-nix` — exit 0; `nix flake check --no-build` — exit 0; all checks passed. |
| Rollback boundary | Revert the compatibility changes in `main.go` and `main_test.go`; the existing pre-transfer remote backup remains the recovery point. |

## Constraints Preserved

- `doRsync` and its source snapshot allowlist were not changed.
- Agent model values are opaque and unchanged; no fallback, provider allowlist, profile, or credential interface was added.
- BrowserMCP is disabled only in the post-rsync target JSON; the source snapshot entry remains present.
- Only `plugins/rtk.ts` and `plugins/skill-registry.ts` are remote asset removal paths.
- Compatibility runs after successful `doRsync`; dry-run does not invoke SSH compatibility mutations.

## Remaining Risks

- A live deployment SSH smoke test remains outstanding by explicit scope decision.
- Invalid target JSON fails before asset removals and leaves the pre-transfer backup available.
