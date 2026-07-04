# Exploration: mact2 OpenCode provider mismatch

## Current State

- `darwin/default.nix:48-57` sets `home-manager.users.${primaryUser}.home.opencode.activeProviderName = "github-copilot"` for the nix-darwin host path.
- `home-darwin/shared-modules.nix:32-33` imports both `../shared/opencode.nix` and `../shared/opencode-profile.nix`, so Darwin Home Manager receives the shared OpenCode module stack.
- `shared/opencode.nix:322-329`, `shared/opencode-profile.nix:7-9`, `shared/opencode/providers.nix:5-10`, and `shared/opencode/providers-base.nix:1-4` all now default `activeProviderName` to `"opencode-go-medium"`, not `"opencode-go-full"`.
- `shared/opencode/agents.nix:12-15` threads `config.home.opencode.activeProviderName` into `providers.nix`, and `shared/opencode/providers-base.nix:263-267` selects the matching provider entry by name.
- Local evaluation confirms the nix-darwin path is correct: `nix eval --raw .#darwinConfigurations.mact2.config.home-manager.users.jcuzmar.home.opencode.activeProviderName` returns `github-copilot`.
- Remote source checkout also contains the override: `/Users/jcuzmar/.config/nix/darwin/default.nix:56` on `mact2.local` sets `home.opencode.activeProviderName = "github-copilot"`.
- However, the deployed runtime file on `mact2.local` at `/Users/jcuzmar/.config/opencode/opencode.json` currently resolves to medium-tier models:
  - `gentle-orchestrator = opencode-go/deepseek-v4-pro`
  - `sdd-explore = opencode-go/deepseek-v4-pro`
  - `sdd-apply = opencode-go/deepseek-v4-flash`
  - `neutral = opencode-go/deepseek-v4-flash`
- Remote inspection of `/Users/jcuzmar/.local/state/home-manager/gcroots/current-home/home-files/.config/opencode/opencode.json` shows the same medium-tier models as the live writable copy, so the active Home Manager generation itself currently encodes `opencode-go-medium`.
- Separate local evaluation confirms why that can happen: `nix eval --raw .#homeConfigurations.mact2.config.home.opencode.activeProviderName` returns `opencode-go-medium` because the standalone HM target does not include `darwin/default.nix`.

## Affected Areas

| Area | Evidence | Why it matters |
|------|----------|----------------|
| `darwin/default.nix` | Host override exists at lines 54-56 | Correct only for nix-darwin path |
| `flake.nix` | `darwinConfigurations.mact2 = mkDarwinHost ...` and separate `homeConfigurations.mact2 = baseHomeConfig ...` | There are two distinct deployment paths for mact2 |
| `homeConfigurations.mact2` | Evaluates to `opencode-go-medium` | A standalone `home-manager switch --flake .#mact2` can overwrite the intended Darwin config |
| `shared/opencode.nix` | Writes `.config/opencode/opencode.json` via Home Manager | This is the runtime artifact the user experiences |
| `shared/opencode.nix` activation steps | `makeOpencodeConfigMutable-*` copies the generated HM file into a writable real file | Whatever HM generation is active becomes the on-disk runtime config |
| Remote `~/.config/opencode/opencode.json` | Contains medium-tier models, no `github-copilot/...` assignments | Confirms deployed behavior does not match nix-darwin evaluation |
| Provider catalog | `providers-base.nix` includes `github-copilot`, `opencode-go-full`, `opencode-go-medium`, `opencode-go-light` | Confirms the mismatch is selection/deployment, not missing provider support |

## Approaches

| Approach | What to verify/change next | Pros | Cons | Complexity |
|----------|----------------------------|------|------|-----------|
| 1. Confirm deployment path mismatch | Prove whether mact2 was last updated with `home-manager switch --flake .#mact2` instead of `darwin-rebuild switch --flake .#mact2` | Best fit to current evidence; explains why source and nix-darwin eval are correct but deployed file is wrong | Needs deployment-history confirmation on host | Low |
| 2. Unify standalone and nix-darwin provider override for mact2 | Make `homeConfigurations.mact2` also carry the host override, or make standalone use the darwin host path | Prevents future drift if `hms` is run on mact2 | Requires design choice about whether standalone HM for Darwin should remain supported separately | Medium |
| 3. Add guard/assertion around mact2 provider selection | Add an evaluation check or assertion that `homeConfigurations.mact2` and `darwinConfigurations.mact2` cannot silently diverge on `activeProviderName` | Prevents regression and documents intended ownership | Does not by itself fix current deployment drift | Medium |

## Recommendation

Primary recommendation: treat this as a deployment-path drift issue, not a provider-threading bug.

Evidence supports this chain:

1. The provider override is present in both local and remote `darwin/default.nix`.
2. The nix-darwin evaluation path resolves `github-copilot` correctly.
3. The live and generated Home Manager runtime files on `mact2.local` both resolve to `opencode-go-medium`.
4. The standalone `homeConfigurations.mact2` path also resolves to `opencode-go-medium`.

That makes the most likely root cause: the deployed OpenCode config on mact2 came from the standalone Home Manager target, which does not inherit the Darwin host override, and then `makeOpencodeConfigMutable-*` copied that generation into the writable `~/.config/opencode/opencode.json`.

Secondary recommendation: the next proposal should decide whether `homeConfigurations.mact2` is supposed to be a supported deployment path. If yes, it should be made behaviorally identical for provider selection. If no, the repo should add a guard or documentation to stop using it for mact2.

## Risks

- The user suspected `opencode-go-full`, but current code and live evidence point to `opencode-go-medium`; a proposal based on `full` would target the wrong default.
- Because `~/.config/opencode/opencode.json` is converted into a writable real file, runtime inspection alone can look like “manual drift” unless the matching HM generation is also checked.
- mact2 has two valid-looking flake entry points (`darwinConfigurations.mact2` and `homeConfigurations.mact2`) with different provider behavior today; that ambiguity can keep reintroducing the bug.
- Linux precedent is mixed: some hosts intentionally override provider in standalone HM modules (`hosts/rog/home/modules.nix`, `hosts/t14/home/omarchy.nix`), so Darwin needs an explicit ownership decision rather than an implicit assumption.

## Evidence Summary

- Local repo:
  - `darwin/default.nix:56` -> `home.opencode.activeProviderName = "github-copilot"`
  - `shared/opencode.nix:324` -> default `opencode-go-medium`
  - `shared/opencode-profile.nix:9` -> default `opencode-go-medium`
  - `shared/opencode/providers.nix:6` -> default `opencode-go-medium`
  - `shared/opencode/providers-base.nix:3` -> default `opencode-go-medium`
  - `flake.nix:304-310` -> standalone `homeConfigurations.mact2` does not import `darwin/default.nix`
- Verified commands:
  - `nix eval --raw .#darwinConfigurations.mact2.config.home-manager.users.jcuzmar.home.opencode.activeProviderName` -> `github-copilot`
  - `nix eval --raw .#homeConfigurations.mact2.config.home.opencode.activeProviderName` -> `opencode-go-medium`
- Remote host (`mact2.local`):
  - `/Users/jcuzmar/.config/nix/darwin/default.nix` contains the override
  - `/Users/jcuzmar/.config/opencode/opencode.json` contains medium-tier `opencode-go/...` models
  - `/Users/jcuzmar/.local/state/home-manager/gcroots/current-home/home-files/.config/opencode/opencode.json` also contains the same medium-tier models

## Ready for Proposal

Yes. The proposal should focus on aligning or constraining the mact2 deployment paths so the OpenCode provider selection cannot diverge between nix-darwin and standalone Home Manager.
