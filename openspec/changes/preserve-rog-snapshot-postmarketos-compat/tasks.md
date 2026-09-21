# Tasks: Preserve Rog Snapshot with postmarketOS Compatibility

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 160–260 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | single-pr |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Preserve OpenAI models and disable BrowserMCP only in the OnePlus post-rsync stage | PR 1 | `go -C pkgs/nixos-scripts test ./cmd/sync-opencode-remote` | N/A: injected writer/remover tests prove command ordering without a live target | Revert the two Go files; restore the pre-transfer remote backup if needed |

## Phase 1: OpenAI Preservation and BrowserMCP RED Tests

- [x] 1.1 Add focused fixtures asserting every `openai/*` model, including `openai/gpt-5.6-terra`, and model-less agents remain unchanged; assert no fallback model or replacement action exists.
- [x] 1.2 Add focused tests for `mcp.browsermcp.enabled=false`, absent BrowserMCP no-op, malformed JSON/non-object BrowserMCP failure, unrelated MCP preservation, and repeat-application idempotency.
- [x] 1.3 Add boundary tests proving the compatibility stage uses no credential path and only `plugins/rtk.ts` plus `plugins/skill-registry.ts` are removal actions; BrowserMCP is never an asset-removal path.

## Phase 2: Narrow Go Implementation

- [x] 2.1 Replace the model-rewrite logic in `pkgs/nixos-scripts/cmd/sync-opencode-remote/main.go` with opaque agent preservation; no model constants, provider fallbacks, credential inputs, or profile logic are used.
- [x] 2.2 Implement the post-rsync target JSON transform changing only `mcp.browsermcp.enabled`; atomically stream the fixed temporary file, rename it, then remove only the two fixed plugin paths.
- [x] 2.3 Keep `doRsync` and Rog source handling unchanged; run this stage only after successful transfer, preserve existing later npm/MCP/provider steps, and make parse/write/rename/removal failures fatal.

## Phase 3: Integration, Verification, and Rollback

- [x] 3.1 Add command-recorder tests for successful-transfer ordering, rsync-failure suppression, OnePlus-only BrowserMCP disablement, dry-run reporting without SSH mutation, invalid-JSON suppression, and backup preservation boundaries.
- [x] 3.2 Run `go -C pkgs/nixos-scripts test ./...`, `format-nix`, and `nix flake check --no-build`.
- [x] 3.3 Roll back by reverting the two Go files and deploying the prior binary; Rog config, non-OnePlus BrowserMCP, and local OAuth remain untouched by this change.
