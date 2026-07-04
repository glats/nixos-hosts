# Tasks: Fix mact2 OpenCode provider drift

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~4 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | single-pr-default |
| Review focus | `flake.nix` override placement, provider parity checks, eval/flake validation |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|------|
| 1 | Add the mact2 `home.opencode.activeProviderName = "github-copilot";` override to `flake.nix` and validate both evaluation paths | PR 1 | Keep the fix inline and minimal |

## Phase 1: Implementation Scope

- [x] 1.1 Update `flake.nix` so `homeConfigurations.mact2` receives the same `home.opencode.activeProviderName = "github-copilot";` override already present in `darwin/default.nix`
- [x] 1.2 Keep `darwin/default.nix` unchanged as the authoritative source for the override value
- [x] 1.3 Do not add a new module file unless the inline `flake.nix` approach proves insufficient

## Phase 2: Validation

- [x] 2.1 Run `nix eval --raw .#homeConfigurations.mact2.config.home.opencode.activeProviderName` and confirm it returns `github-copilot`
- [x] 2.2 Run `nix eval --raw .#darwinConfigurations.mact2.config.home-manager.users.jcuzmar.home.opencode.activeProviderName` and confirm it still returns `github-copilot`
- [x] 2.3 Run `nix flake check --no-build` to confirm the flake still evaluates cleanly
- [ ] 2.4 If the deployed mact2 runtime is updated later, verify `~/.config/opencode/opencode.json` on `mact2.local` contains `github-copilot`-backed model assignments

## Phase 3: Review Notes

- [x] 3.1 Confirm the change stays limited to `flake.nix` unless a review follow-up is explicitly required
- [x] 3.2 Confirm the final diff stays near the forecasted size and does not justify chained PRs

## Apply Notes

- Optional read-only SSH check was executed against `mact2.local:/Users/jcuzmar/.config/opencode/opencode.json`.
- Current deployed JSON has top-level keys `agent`, `disabled_providers`, `instructions`, `mcp`, `permission`, `provider` and does not expose `activeProviderName`/`activeProvider` yet.
- Post-deploy verification for task 2.4 remains pending until mact2 is re-deployed from this updated flake.

## Relevant Files

- `flake.nix` — add the standalone HM override for `mact2`
- `darwin/default.nix` — authoritative existing override, unchanged
- `shared/opencode.nix` — option definition and default fallback used by both paths
- `shared/opencode/providers-base.nix` — provider default behavior for regression checks
