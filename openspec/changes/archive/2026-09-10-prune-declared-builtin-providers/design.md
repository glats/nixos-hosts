# Design: Prune Declared Built-in Providers

## Technical Approach

Implement ratified Approach B as pure deletion/reduction in the declarative provider catalog layer. No abstraction, option, schema, host, flake, profile, agent, runtime, or credential-export change is introduced. `providers-base.nix` continues to own provider JSON plus routing profiles; `providers.nix` becomes a direct adapter to that base catalog.

The provider section after the unchanged `nvidiaProvider` block is exactly:

```nix
  opencodeProvider = {
    opencode = {
      options = {
        timeout = 3600000;
        chunkTimeout = 3600000;
      };
    };
  };

  allProviders = nvidiaProvider // opencodeProvider;
```

`providers.nix` becomes:

```nix
# Providers configuration for shared opencode
# activeProviderName is threaded from the HM option so any host can
# override the active provider tier without editing this module.
{ lib ? throw "providers.nix must be imported with lib"
, activeProviderName ? "opencode-go-medium"
,
}:

import ./providers-base.nix { inherit lib activeProviderName; }
```

## Architecture Decisions

| Decision | Choice and rationale | Evidence |
|---|---|---|
| Built-in declarations | Remove Anthropic, GitHub Copilot, and all 33 OpenCode model pins. OpenCode loads bundled models.dev data first and `mergeDeep` only overlays configured entries, so declarations are not prerequisites. | `exploration.md` §§ Current State, Impact Verification 1–4 |
| OpenCode options | Retain both one-hour timeout values. They are valid, effective options; removing them restores the 300,000 ms default and risks long free-model streams on t14/mact2. | `exploration.md` § Impact Verification 5 |
| NVIDIA | Preserve the entire block byte-for-byte because this custom provider is absent from models.dev and autoload requires `source === "config"`. | `exploration.md` § Impact Verification 6 |
| Extras | Delete `providers-extra.nix` and its optional import/merge. Repository audit found no consumer of `extraProviders`. | `exploration.md` §§ Current State, Impact Verification 3 |
| Compatibility | Add no migration or compatibility shim: Home Manager regenerates `opencode.json` each switch, and the existing activation `cmp` refresh replaces changed content. | `runtime-config.nix:94-107,141-174` |

## Data Flow

```text
providers-base.nix ──→ providers.nix ──→ runtime-config.nix ──→ opencode.json.provider
      │                    │                       └── { nvidia, opencode(options only) }
      └── 22 profiles ─────┴──→ agents.nix ──→ phase model strings ──→ built-in runtime catalog
```

`agents.nix` keeps selecting phase strings from the unchanged profile list. OpenCode resolves built-in prefixes through its bundled catalog at runtime; NVIDIA resolves through the explicit config entry.

## File Changes

| File | Action | Description |
|---|---|---|
| `shared/opencode/providers-base.nix` | Modify | Reduce OpenCode to timeout options, remove Anthropic/Copilot blocks, update `allProviders`; leave NVIDIA and all 22 profiles untouched. |
| `shared/opencode/providers.nix` | Modify | Return the base import directly; remove extras threading. |
| `shared/opencode/providers-extra.nix` | Delete | Remove unreachable provider definitions. |
| `openspec/specs/gentle-ai-declarative-runtime/spec.md` | Optional | Reword only if archive review confirms a stale provider-catalog reference; no current block-count contract requires change. |

## Interfaces / Contracts

No Nix module option or schema changes. `providers.nix` still exports the base attributes consumed by `runtime-config.nix` and `agents.nix`; only unused `extraProviders` disappears. Hard preservation contracts are: 22 profile values byte-identical, NVIDIA byte-identical, and `shared/opencode.nix` sops exports byte-identical.

## Edge Cases

Catalog drift could remove a future models.dev ID and cause runtime model resolution failure. Mitigation is the 29-ID zero-missing catalog cross-check immediately before every host switch for this change. The `x-preview-f-free` profile-level exclusion/risk reference and Copilot plan-dependent model references remain untouched; account/API availability remains an existing runtime concern independent of static declarations.

## Testing Strategy

| Spec gate | Proof |
|---|---|
| Formatting/evaluation | Run `format-nix`, then `nix flake check --no-build`. |
| Profile preservation | A/B-evaluate baseline and candidate; assert 22 profiles and full structures are identical. |
| Catalog resolution | Cross-check all 29 unique built-in IDs against current models.dev; require zero missing and explicit NVIDIA presence. |
| Host safety | Evaluate `.#nixosConfigurations.t14.config.system.build.toplevel`. |
| Consumer/catalog cleanup | Grep tracked files for `extraProviders`, removed declarations, model pins, and `thinking`; inspect generated provider keys and timeout values. |

## Threat Matrix

N/A — this design changes no routing decision logic, shell command, subprocess, VCS/PR automation, executable classification, or process-integration boundary.

## Migration / Rollout

No migration required. Apply and verify the three-file change, then switch hosts only after all gates pass. Roll back with one revert of the change commit; the next Home Manager switch regenerates and `cmp`-refreshes `opencode.json`. There is no persistent-state migration.

## Open Questions

None.
