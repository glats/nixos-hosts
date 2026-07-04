# Apply Progress: Fix mact2 OpenCode provider drift

## Status

- Implementation: COMPLETE
- Validation: COMPLETE (local eval + flake check)
- Optional remote runtime verification: PARTIAL (read-only inspection done, redeploy still pending)

## Completed Tasks

- [x] 1.1 Update `flake.nix` so `homeConfigurations.mact2` receives the same `home.opencode.activeProviderName = "github-copilot";` override already present in `darwin/default.nix`
- [x] 1.2 Keep `darwin/default.nix` unchanged as the authoritative source for the override value
- [x] 1.3 Do not add a new module file unless the inline `flake.nix` approach proves insufficient
- [x] 2.1 Run `nix eval --raw .#homeConfigurations.mact2.config.home.opencode.activeProviderName` and confirm it returns `github-copilot`
- [x] 2.2 Run `nix eval --raw .#darwinConfigurations.mact2.config.home-manager.users.jcuzmar.home.opencode.activeProviderName` and confirm it still returns `github-copilot`
- [x] 2.3 Run `nix flake check --no-build` to confirm the flake still evaluates cleanly
- [ ] 2.4 If the deployed mact2 runtime is updated later, verify `~/.config/opencode/opencode.json` on `mact2.local` contains `github-copilot`-backed model assignments
- [x] 3.1 Confirm the change stays limited to `flake.nix` unless a review follow-up is explicitly required
- [x] 3.2 Confirm the final diff stays near the forecasted size and does not justify chained PRs

## Implementation Notes

- `flake.nix` was updated in `homeConfigurations.mact2` to append:
  `{ home.opencode.activeProviderName = "github-copilot"; }`
- No other implementation files were changed.

## Verification Evidence

Commands executed locally in `/home/glats/.nixos`:

1. `format-nix`
2. `nix flake check --no-build` → passed
3. `nix eval --raw .#homeConfigurations.mact2.config.home.opencode.activeProviderName` → `github-copilot`
4. `nix eval --raw .#darwinConfigurations.mact2.config.home-manager.users.jcuzmar.home.opencode.activeProviderName` → `github-copilot`

Optional read-only SSH check executed:

- `ssh mact2.local` inspection of `/Users/jcuzmar/.config/opencode/opencode.json`
- File exists and currently has top-level keys: `agent`, `disabled_providers`, `instructions`, `mcp`, `permission`, `provider`
- `activeProviderName`/`activeProvider` keys are not present in the current deployed JSON, so final runtime provider confirmation remains pending until redeploy.

## Risks / Follow-up

- Residual risk: runtime config on `mact2` can remain stale until a deploy from updated flake is run.
- Follow-up: run `darwin-rebuild switch --flake .#mact2` or `home-manager switch --flake .#mact2` on mact2, then verify provider assignments in `opencode.json`.
