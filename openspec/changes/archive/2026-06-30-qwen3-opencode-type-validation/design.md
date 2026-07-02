# Design: qwen3-opencode-type-validation

## Technical Approach

Replace two broken Qwen-based provider tiers (`opencode-go`, `opencode-go2`) with three working tiers (`opencode-go-full`, `opencode-go-medium`, `opencode-go-light`) built from OpenAI-compatible models. Expand the model catalogue from 3 to 11 entries (8 working + 3 zombie Qwen with upstream tracking). Update the system default from `"opencode-go"` to `"opencode-go-medium"` across all four declaration points, and set t14 host override to `"opencode-go-full"`.

References: `sdd/qwen3-opencode-type-validation/proposal`, `sdd/qwen3-opencode-type-validation/specs`.

## Architecture Decisions

| Decision | Choice | Alternative | Rationale |
|----------|--------|-------------|-----------|
| Default tier | `opencode-go-medium` | `opencode-go-full` | Spec mandates medium; balances quality/cost for rog and thinkcentre. t14 gets full via explicit override. |
| Zombie Qwen handling | Keep in catalogue, exclude from all tiers | Delete entirely | Enables one-line re-enable when upstream fixes opencode#23960, #32418, #29754. Comment block tracks issues. |
| Phase value format | Bare model IDs (e.g. `"kimi-k2.6"`) | Prefixed (`"opencode-go/kimi-k2.6"`) | Spec requires bare IDs matching catalogue keys. Context instructions confirm: "Model IDs are bare strings." |
| `thinking` attribute | `false` for all 8 working models | Per-model variation | No reasoning/thinking config needed per context instructions. Consistent with existing Qwen entries. |
| Tier count | 3 (full/medium/light) | 2 (full/medium) | Light tier provides minimal-cost option for high-volume phases (sdd-init, sdd-archive, sdd-onboard, neutral). |

## Data Flow

```
HM Option                    providers-base.nix
home.opencode ──(default)──→ activeProviderName ? "opencode-go-medium"
activeProviderName                    │
    │                                 ▼
    │                    ┌─── builtins.foldl' ───┐
    │                    │  scan providers list   │
    │                    │  for name match        │
    │                    └───────────┬────────────┘
    │                                │
    │                    ┌───────────▼────────────┐
    │                    │  activeProvider         │
    │                    │  (matched tier record)  │
    │                    └───────────┬────────────┘
    │                                │
    │                    ┌───────────▼────────────┐
    │                    │  getModelForPhase       │
    │                    │  phase → model ID       │
    │                    └───────────┬────────────┘
    │                                │
    ▼                                ▼
providers.nix ──────────→ allProviders (full list)
    │                            │
    ▼                            ▼
opencode.nix ──────→ writeText "opencode.json"
                     (provider + agent config)
                            │
                            ▼
                     ~/.config/opencode/
                     opencode.json (runtime)
```

## File Dependency Graph

```
providers-base.nix  ←── providers.nix (wrapper, passes activeProviderName)
      │                      ↑
      │                      │ import (default args)
      │                      │
      ├── model catalogue     opencode.nix ──→ opencode.json (runtime)
      ├── tier definitions         ↑
      └── default param            │ import
                                   │
                           opencode-profile.nix (sets HM option default)
                                   ↑
                                   │ imported by each host
                                   │
                           hosts/t14/home/omarchy.nix (overrides to full)
```

## File Changes

| File | Action | Lines | Change |
|------|--------|-------|--------|
| `shared/opencode/providers-base.nix` | Modify | 2 | `activeProviderName ? "opencode-go"` → `? "opencode-go-medium"` |
| `shared/opencode/providers-base.nix` | Modify | 61-74 | Expand models: 3 Qwen → 8 working + 3 zombie (with comment block) |
| `shared/opencode/providers-base.nix` | Modify | 119-135 | Replace `opencode-go` tier → `opencode-go-full` |
| `shared/opencode/providers-base.nix` | Modify | 136-152 | Replace `opencode-go2` tier → `opencode-go-medium` |
| `shared/opencode/providers-base.nix` | Insert | after 152 | Add `opencode-go-light` tier block |
| `shared/opencode.nix` | Modify | 309 | `lib.mkDefault "opencode-go"` → `lib.mkDefault "opencode-go-medium"` |
| `shared/opencode-profile.nix` | Modify | 9 | `lib.mkDefault "opencode-go"` → `lib.mkDefault "opencode-go-medium"` |
| `shared/opencode/providers.nix` | Modify | 6 | `activeProviderName ? "opencode-go"` → `? "opencode-go-medium"` |
| `hosts/t14/home/omarchy.nix` | Modify | 86 | `"opencode-go"` → `"opencode-go-full"` |

## Tier Structure Schema

Each tier is a record in the `providers` list:

```nix
{
  name = "opencode-go-{full,medium,light}";
  phases = {
    gentle-orchestrator = "<model-id>";
    sdd-init = "<model-id>";
    sdd-explore = "<model-id>";
    sdd-propose = "<model-id>";
    sdd-spec = "<model-id>";
    sdd-design = "<model-id>";
    sdd-tasks = "<model-id>";
    sdd-apply = "<model-id>";
    sdd-verify = "<model-id>";
    sdd-archive = "<model-id>";
    sdd-onboard = "<model-id>";
    neutral = "<model-id>";
  };
}
```

### Phase → Model Routing

| Phase | full | medium | light |
|-------|------|--------|-------|
| gentle-orchestrator | kimi-k2.6 | kimi-k2.6 | kimi-k2.6 |
| sdd-init | deepseek-v4-flash | deepseek-v4-flash | deepseek-v4-flash |
| sdd-explore | glm-5.2 | kimi-k2.6 | deepseek-v4-flash |
| sdd-propose | deepseek-v4-pro | deepseek-v4-pro | deepseek-v4-pro |
| sdd-spec | deepseek-v4-pro | deepseek-v4-pro | deepseek-v4-pro |
| sdd-design | glm-5.2 | deepseek-v4-pro | deepseek-v4-pro |
| sdd-tasks | kimi-k2.6 | kimi-k2.6 | deepseek-v4-flash |
| sdd-apply | kimi-k2.6 | kimi-k2.6 | kimi-k2.6 |
| sdd-verify | glm-5.2 | kimi-k2.6 | deepseek-v4-flash |
| sdd-archive | deepseek-v4-flash | deepseek-v4-flash | deepseek-v4-flash |
| sdd-onboard | kimi-k2.6 | deepseek-v4-flash | deepseek-v4-flash |
| neutral | kimi-k2.6 | deepseek-v4-flash | deepseek-v4-flash |

### Model Catalogue (opencodeProvider.opencode.models)

| Key | Display Name | Notes |
|-----|-------------|-------|
| `glm-5.2` | GLM 5.2 | Working |
| `glm-5.1` | GLM 5.1 | Working |
| `kimi-k2.6` | Kimi K2.6 | Working |
| `kimi-k2.7-code` | Kimi K2.7 Code | Working |
| `deepseek-v4-pro` | DeepSeek V4 Pro | Working |
| `deepseek-v4-flash` | DeepSeek V4 Flash | Working |
| `mimo-v2.5` | Mimo V2.5 | Working |
| `mimo-v2.5-pro` | Mimo V2.5 Pro | Working |
| `qwen3.7-plus` | Qwen 3.7 Plus | Zombie — upstream tracking |
| `qwen3.7-max` | Qwen 3.7 Max | Zombie — upstream tracking |
| `qwen3.8-ultra` | Qwen 3.8 Ultra | Zombie — upstream tracking |

## Testing Strategy

| Layer | What | Approach |
|-------|------|----------|
| Syntax | All 5 modified files parse correctly | `nix flake check --no-build` for rog, thinkcentre, t14 |
| Formatting | Nix formatting conventions | `format-nix` on all changed files |
| Tier resolution | Each tier resolves all 12 phases | Verify no phase returns null via `getModelForPhase` |
| Zombie isolation | No zombie model in any tier phase | Grep tier blocks for `qwen3.7` / `qwen3.8` |
| Default consistency | All 4 default points agree on `"opencode-go-medium"` | Grep for `activeProviderName` defaults |
| Host override | t14 resolves to `"opencode-go-full"` | Inspect `hosts/t14/home/omarchy.nix` line 86 |

## Migration / Rollout

No migration required. This is a pure configuration change — no secrets, no state, no package versions. Single commit, atomic switch via `nixos-build`.

## Open Questions

- None.
