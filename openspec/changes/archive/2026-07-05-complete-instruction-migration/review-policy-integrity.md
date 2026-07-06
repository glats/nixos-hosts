# Exploration: Review Policy Integrity After Instruction Migration

## Content Integrity

```
$ diff shared/opencode/sdd-review-policy.md shared/opencode/instructions/orchestrator.md
EXIT_CODE=0 (no diff)
```

**Verdict**: Files are **byte-identical** (both 114 lines, same hashes). The `diff` confirms zero divergence. The old source can be removed without losing content.

## Delivery Paths

| Path | Before Migration | After Migration | Status |
|------|-----------------|-----------------|--------|
| `opencode.json` `instructions` array | `["SYSTEM_RULES.md", "sdd-review-policy.md"]` | `["instructions/universal.md", "instructions/orchestrator.md"]` | Updated (in `shared/opencode.nix` lines 72-75) |
| `home.file` deployment | `SYSTEM_RULES.md` + `sdd-review-policy.md` | `instructions/universal.md` + `instructions/orchestrator.md` | Updated (lines 92-99) |
| Activation script loop (symlink→copy) | includes `SYSTEM_RULES.md` + `sdd-review-policy.md` | includes `instructions/universal.md` + `instructions/orchestrator.md` | Updated (line 150) |
| `instructionOverlays.gentle-orchestrator` (for sub-agent prompt) | `["instructions/universal.md", "instructions/orchestrator.md"]` | `["instructions/universal.md", "instructions/orchestrator.md"]` | Unchanged (in `local-agent-overlays.json` line 43) |
| Orchestrator prompt in generated `opencode.json` | contains orchestrator.md content | contains orchestrator.md content | **Intact** |

### How the orchestrator receives the policy

The chain is:

```
local-agent-overlays.json
  → instructionOverlays.gentle-orchestrator: ["instructions/universal.md", "instructions/orchestrator.md"]
  → agents.nix: reads instructionOverlays, calls builtins.readFile for each path
  → Prepends the read content to the orchestrator's prompt field
  → Generated opencode.json: gentle-orchestrator.prompt starts with SDD Review Policy + Iteration Protocol
```

The orchestrator's `prompt` in the generated `opencode.json` was verified to contain ALL key sections:

- `# SDD Review Policy + Iteration Protocol` ✓
- `## Hard Gate After Every Apply Slice` ✓
- `## Iteration Protocol` ✓
- `## Guard Lines` ✓
- `## Verify Gate` ✓
- `## Re-Explore Protocol` ✓
- `## Proceed Escape Hatch` ✓
- `Rework level: explore|design|tasks|none` ✓
- `Iteration decision needed: Yes|No` ✓

**Verdict**: The delivery mechanism migrated from **global `instructions` array** (applied to parent agent context) to **`instructionOverlays` → inlined `prompt` field** (applied to orchestrator sub-agent context). Both deliver the same policy text to the orchestrator.

## RP-005 Compliance

**Requirement**: "The policy MUST be enforceable as instruction text the orchestrator reads from context. It MUST NOT require modifications to SDD skills. Guard lines in the review-checkpoint drive the orchestrator's decision point."

**Current state**: The policy is inlined into the orchestrator's `prompt` field at `opencode.json` generation time. The orchestrator reads it as system context — this is strictly MORE enforceable than a file reference (which requires OpenCode to resolve and inject at runtime). The inlined approach guarantees the policy is always present, cannot be missing due to file-not-found, and requires ZERO skill modifications.

**Verdict**: RP-005 compliance is **preserved and strengthened**.

## Risk Assessment

### Could the orchestrator lose the review policy?

| Scenario | Risk | Mitigation |
|----------|------|------------|
| `instructions/orchestrator.md` deleted | The next `nixos-build` would fail (Nix evaluation: `builtins.readFile` on missing path). The file is git-tracked — easy recovery. | Low — build fails before deployment |
| `local-agent-overlays.json` edited to remove orchestrator.md from overlays | Orchestrator prompt would not include policy text. | Medium — no build-time error, silent behavioral change. Mitigation: the orchestrator skill itself references review gates independently. |
| `agents.nix` overlay function changed | Could break the readFile → prepend pipeline. | Low — changes to agents.nix are infrequent and reviewed. |
| Old `sdd-review-policy.md` accidentally re-added to `instructions` array | Duplicate policy text in parent agent context. | Low — would not affect orchestrator behavior (policy is deduplicated at read time). |

**Overall risk**: LOW. The policy delivery path is:
1. Source file (orchestrator.md) → Nix evaluation (`builtins.readFile`) → inline prompt → `opencode.json`
2. No runtime file resolution, no symlinks, no agent-side injection

This is a **strict improvement** over the pre-migration approach where the orchestrator relied on OpenCode's runtime file resolution of global `instructions` entries. Inlining at build/activation time eliminates a class of runtime failures.

### Remaining references to old files

The old source files still exist:
- `shared/opencode/SYSTEM_RULES.md` — only referenced in a comment (`plugins.nix` line 53, documentation text only, not a file path)
- `shared/opencode/sdd-review-policy.md` — referenced in archived change artifacts (expected, historical) and in `bin/sync-opencode-remote` (line 164, rsync include filter) and `openspec/changes/pasar-opencode-remoto/` (in-progress change, its design references the file for deployment)

These files must be explicitly deleted as part of the migration, and `bin/sync-opencode-remote` must have its rsync include cleaned up (lines 161, 164).

## Ready for Proposal

**Yes.** The review policy is fully intact after the migration:

1. Content is byte-identical (diff = empty)
2. Delivery path is confirmed working (orchestrator prompt verified in generated `opencode.json`)
3. All key sections present and correct
4. RP-005 compliance is preserved (actually strengthened — inlining > runtime file resolution)
5. Risk of policy loss is LOW

## References

- Source: `shared/opencode/instructions/orchestrator.md` (114 lines)
- Old: `shared/opencode/sdd-review-policy.md` (114 lines, byte-identical)
- Spec: `openspec/changes/archive/2026-07-01-review-policy/specs/review-gates/spec.md` — RP-005
- Config: `shared/opencode/local-agent-overlays.json` — instructionOverlays definitions
- Builder: `shared/opencode/agents.nix` — `builtins.readFile` overlay resolution
- Deploy: `shared/opencode.nix` — instructions array + home.file + activation loop
- Generated: `~/.config/opencode/opencode.json` — orchestrator prompt with policy inlined
