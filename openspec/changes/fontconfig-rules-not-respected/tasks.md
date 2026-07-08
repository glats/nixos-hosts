# Tasks: Fontconfig Rules Not Respected

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 25-35 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | single-pr |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

## Phase 1: Core — Replace localConf with environment.etc

- [ ] 1.1 Add `environment.etc."fonts/conf.d/51-nixos-custom.conf".text` with the full XML from localConf (rejectfonts, redirects, strong aliases, emoji fallbacks) attached to the output attrset
- [ ] 1.2 Remove the `localConf` attribute from `fonts.fontconfig` (line 145-172)
- [ ] 1.3 Update `familyPrefs.serif` from `["Source Sans 3" "Noto Serif"]` to `["Noto Serif"]` — user chose Noto Serif as primary serif over Droid Serif

## Phase 2: Fix Hyprlock Font Name

- [ ] 2.1 In `hosts/t14/home/hypr/hyprlock.nix` line 54, change `font_family = lib.mkForce "Source Sans Pro"` to `font_family = lib.mkForce "Source Sans 3"`

## Phase 3: Verification

- [ ] 3.1 Run `format-nix` to format changed files
- [ ] 3.2 Run `nix flake check --no-build` — verify passes for rog, thinkcentre, t14
- [ ] 3.3 Dry-run build on one host: `nixos-build dry`
- [ ] 3.4 Manual post-rebuild: `fc-match sans-serif` returns "Source Sans 3"; `fc-list | grep DejaVu` returns empty; `fc-match Arial` resolves to sans-serif
