# Design: Preserve Rog Snapshot with postmarketOS Compatibility

## Technical Approach

Keep `doRsync` unchanged as the complete Rog snapshot boundary. Only after it succeeds, `sync-opencode-remote` reads the copied-config source JSON, makes one narrow compatibility transform, and atomically replaces target `opencode.json` over the existing SSH boundary. The transform preserves every agent model value exactly and changes only `mcp.browsermcp.enabled` to `false` when that entry exists. It never reads or writes credential paths, creates no target profile, and does not change the source snapshot.

## Architecture Decisions

| Decision | Choice | Alternatives considered | Rationale |
|---|---|---|---|
| Adaptation location | A small Go helper in `sync-opencode-remote`, invoked after `doRsync` | Nix/Home Manager profile; rsync exclusions | Rog remains the sole snapshot generator and the OnePlus exception stays post-transfer. |
| Model handling | Do not inspect, filter, replace, or synthesize agent `model` values | Provider allowlist and OpenCode Go fallback | OnePlus local OAuth resolves the Rog-generated OpenAI graph; exact preservation is the contract. |
| BrowserMCP handling | Set only `mcp.browsermcp.enabled` to `false` in post-rsync JSON | Delete its package/plugin; disable it at the source | Disables the trace-proven failing runtime without removing BrowserMCP from Rog or unrelated flows. |
| Runtime assets | Remove only `plugins/rtk.ts` and `plugins/skill-registry.ts` with fixed target paths | Remove `plugins/`; discover paths dynamically | The fixed list preserves unrelated target plugins and skills. BrowserMCP is not an asset exclusion. |
| JSON write and failure | Stream a complete temporary file, then rename atomically; stop on parse, write, rename, or fixed-removal failure | In-place remote Python rewrite; warning-only failure | Prevents partial JSON and preserves the existing pre-transfer backup and rsync exit semantics. |

No Nix module option, CLI flag, environment variable, or credential interface is added.

## Data Flow

    Rog generated config
           │
           ├── rsync allowlist ──> OnePlus complete snapshot
           │                              │
           │                         successful only
           │                              ▼
           └── read `opencode.json` → disable `mcp.browsermcp` → atomic SSH replace
                                                               └── remove two fixed target assets

The helper decodes the document enough to address the `mcp.browsermcp` object. It leaves `agent` opaque, retaining every model string, model-less agent, and unrelated JSON member. An absent BrowserMCP entry is a no-op; invalid JSON or a malformed BrowserMCP object fails before any target asset removal. The remote write uploads to a fixed temporary file beneath `remoteDir` and renames it only after the full stream succeeds. `rm -f` receives only the two fixed asset paths. This stage precedes npm installation; existing MCP disable/provider-rename behavior remains outside this revision.

For `--dry-run`, the helper reports BrowserMCP disablement when present and both fixed asset exclusions, without an SSH write, rename, removal, source mutation, or credential-path access. A failed rsync returns through its existing error and exit path before this stage runs.

## File Changes

| File | Action | Description |
|---|---|---|
| `pkgs/nixos-scripts/cmd/sync-opencode-remote/main.go` | Modify | Remove model fallback; atomically disable BrowserMCP in JSON and retain two fixed target asset exclusions. |
| `pkgs/nixos-scripts/cmd/sync-opencode-remote/main_test.go` | Modify | Cover exact model preservation, JSON-only BrowserMCP disablement, bounded removals, failure, and dry-run behavior. |
| `openspec/changes/preserve-rog-snapshot-postmarketos-compat/design.md` | Modify | Record the revised minimal transform. |

## Interfaces / Contracts

The internal helper accepts JSON bytes and returns JSON plus ordered actions. Its only JSON mutation is `mcp.browsermcp.enabled = false`; it has no model constants or credential-path inputs. It accepts absent BrowserMCP as a no-op, rejects malformed JSON or a non-object BrowserMCP entry, and is idempotent. The asset contract is exactly `plugins/rtk.ts` and `plugins/skill-registry.ts`; BrowserMCP has no filesystem removal contract.

## Testing Strategy

| Layer | What to Test | Approach |
|---|---|---|
| Unit | Every agent model, including `openai/gpt-5.6-terra`, is byte-identical before and after; model-less agents remain unchanged | Fixture comparison of `agent` JSON before and after transform. |
| Unit | BrowserMCP is disabled only through `mcp.browsermcp.enabled`; absent entry is a no-op; malformed JSON/object fails | Table-driven JSON fixtures plus repeat-application idempotency. |
| Unit | Only the two named target paths are removal actions; BrowserMCP and unrelated assets are never removal paths | Exact action and command-shape assertions. |
| Unit | Dry run reports JSON and fixed-asset actions without SSH mutation; failed rsync suppresses compatibility; invalid JSON suppresses removals | Injected writer/remover and transfer seams. |
| Integration | Build and repository evaluation | `go -C pkgs/nixos-scripts test ./...`, `format-nix`, `nix flake check --no-build`. |

## Threat Matrix

| Boundary | Applicability | Design response | Planned RED tests |
|---|---|---|---|
| Documentation-like paths | N/A: no executable-file classification | None | None |
| Git repository selection | N/A: no Git operation | None | None |
| Commit state | N/A: no commit operation | None | None |
| Push state | N/A: no push operation | None | None |
| PR commands | N/A: no PR operation | None | None |

The process boundary uses the existing SSH/rsync flow. New commands use the existing remote directory, one fixed temporary filename, and the two fixed relative asset paths; tests assert atomic write shape, bounded removals, dry-run suppression, and rsync-failure suppression.

## Migration / Rollout

No migration required. Deploy the updated Rog binary, inspect `--dry-run`, then sync normally. The pre-transfer remote backup remains recovery; reverting the binary restores prior behavior without touching Rog configuration or either host's OAuth state.

## Open Questions

None.
