# Tasks: qwen3-opencode-type-validation

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~100 across 5 files |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | single-pr |
| Chain strategy | size-exception (under budget) |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

## Phase 1: Model Catalogue Expansion (`shared/opencode/providers-base.nix`)

- [x] 1.1 Add 8 working models to `opencodeProvider.opencode.models`: `glm-5.2`, `glm-5.1`, `kimi-k2.6`, `kimi-k2.7-code`, `deepseek-v4-pro`, `deepseek-v4-flash`, `mimo-v2.5`, `mimo-v2.5-pro` (each with `name` + `thinking = false`)
- [x] 1.2 Insert upstream-tracking comment block above the 3 Qwen zombie entries citing `opencode#23960`, `#32418`, `#29754`

## Phase 2: Tier Definitions (`shared/opencode/providers-base.nix`)

> Phase values MUST use **bare** model IDs per spec (e.g. `kimi-k2.6`), not prefixed — this is a behavior change from current `opencode-go/{model}` form.

- [x] 2.1 Replace `opencode-go` tier record (lines 119-135) with `opencode-go-full` tier using bare IDs from spec "Tier Phase Routing" table (uses glm-5.2, deepseek-v4-pro, kimi-k2.6, deepseek-v4-flash)
- [x] 2.2 Replace `opencode-go2` tier record (lines 136-152) with `opencode-go-medium` tier using bare IDs from spec table (uses deepseek-v4-pro, kimi-k2.6, deepseek-v4-flash)
- [x] 2.3 Insert new `opencode-go-light` tier record after medium, 12 phases per spec table (uses deepseek-v4-pro, kimi-k2.6, deepseek-v4-flash)
- [x] 2.4 Verify all 3 new tiers resolve all 12 phases without null (manual check against spec table)

## Phase 3: Default `activeProviderName` (4 files)

- [x] 3.1 `shared/opencode/providers-base.nix:2` — default arg `"opencode-go"` → `"opencode-go-medium"`
- [x] 3.2 `shared/opencode.nix:309` — `lib.mkDefault "opencode-go"` → `lib.mkDefault "opencode-go-medium"`
- [x] 3.3 `shared/opencode-profile.nix:9` — `lib.mkDefault "opencode-go"` → `lib.mkDefault "opencode-go-medium"`
- [x] 3.4 `shared/opencode/providers.nix:6` — default arg `"opencode-go"` → `"opencode-go-medium"`

## Phase 4: Host Override

- [x] 4.1 `hosts/t14/home/omarchy.nix:86` — plain assignment `"opencode-go"` → `"opencode-go-full"` (per spec "Host Provider Mapping")

## Phase 5: Validation

- [x] 5.1 Run `nix flake check --no-build` for rog, thinkcentre, t14 — must pass
- [x] 5.2 Run `format-nix` on all 5 changed files — no diff on commit
- [x] 5.3 Zombie isolation: `rg "qwen3\.[78]" shared/opencode/providers-base.nix` outside catalogue + comment block must return zero matches in tier phase values
- [x] 5.4 Default consistency: 4 grep hits for `"opencode-go-medium"` across declaration points; 1 hit for `"opencode-go-full"` in `hosts/t14/home/omarchy.nix`
- [x] 5.5 Verify t14 host evaluates `home.opencode.activeProviderName` to `"opencode-go-full"` via `nix eval` (optional — flake check covers syntax)
- [x] 5.6 Verify rog/thinkcentre evaluate to `"opencode-go-medium"` via default (no host override present)

## Notes

- Default is **`opencode-go-medium`** per spec (not `opencode-go-full` as in early proposal draft — spec wins).
- t14 keeps its override but flips to `opencode-go-full` (was `opencode-go`).
- Single commit. Pure config change — no secrets, hardware, or package versions touched.
- Rollback: `git revert` the single commit. Old tier names and Qwen model entries are in git history.
