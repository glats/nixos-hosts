# Tasks: NixOS Host Pattern Refactor — Eliminate Last Host Conditional

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~440 (mostly cut-paste from btop.nix) |
| 400-line budget risk | Medium |
| Chained PRs recommended | Yes |
| Suggested split | Single PR with size-exception (pure refactor) |
| Delivery strategy | auto-chain |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: size-exception
400-line budget risk: Medium

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Extract theme + per-host configs, update imports, delete old file | PR 1 (size-exception) | Pure refactor; splitting would leave intermediate states non-functional |

## Phase 1: Foundation — Extract Shared Theme

- [x] 1.1 Create `home-linux/btop-theme.nix` — extract the `btopTheme` string and `home.file."~/.config/btop/themes/nix-colors.theme"` from `btop.nix`. No `hostName` parameter, no conditionals.
- [x] 1.2 Verify `btop-theme.nix` evaluates without errors: `nix fmt -- home-linux/btop-theme.nix`

## Phase 2: Core Implementation — Create Per-Host Fragments

- [x] 2.1 Create `home-linux/btop-file.nix` — extract `home.file."~/.config/btop/btop.conf"` block (rog/thinkcentre variant). No `hostName`, no conditionals.
- [x] 2.2 Verify `btop-file.nix` evaluates without errors: `nix fmt -- home-linux/btop-file.nix`
- [x] 2.3 Create `home-linux/btop-settings.nix` — extract `programs.btop.settings` block with all `lib.mkForce` values (t14 variant). No `hostName`, no conditionals.
- [x] 2.4 Verify `btop-settings.nix` evaluates without errors: `nix fmt -- home-linux/btop-settings.nix`

## Phase 3: Integration — Wire Imports Per-Host

- [x] 3.1 Update `home-linux/shared-modules.nix` — replace `./btop.nix` with `./btop-theme.nix`
- [x] 3.2 Update `hosts/rog/home/modules.nix` — append `../../../home-linux/btop-file.nix`
- [x] 3.3 Update `hosts/thinkcentre/home/modules.nix` — append `../../../home-linux/btop-file.nix`
- [x] 3.4 Update `hosts/t14/home/omarchy.nix` — replace `../../../home-linux/btop.nix` with `../../../home-linux/btop-theme.nix` and `../../../home-linux/btop-settings.nix`

## Phase 4: Cleanup — Remove Old File

- [x] 4.1 Delete `home-linux/btop.nix`

## Phase 5: Verification — Prove Zero Conditionals and Valid Eval

- [x] 5.1 Run `grep -r "hostName" home-linux/` and confirm zero matches
- [x] 5.2 Run `nix flake check --no-build` and confirm exit code 0
- [x] 5.3 Run `format-nix` to ensure all new/modified `.nix` files are formatted
