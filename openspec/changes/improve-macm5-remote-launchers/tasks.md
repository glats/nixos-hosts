# Tasks: Improve macm5 Remote Launchers

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 90–140 authored lines |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single cohesive macm5-only PR |
| Delivery strategy | single-pr |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Implement, evaluate, and verify all four macm5 bundles | PR 1 | `nix fmt -- darwin/home/remote-desktop.nix`; `nix eval .#darwinConfigurations.macm5.config.system.build.toplevel.drvPath` | Native macm5 activation plus Finder/Spotlight and launch checks | Revert `darwin/home/remote-desktop.nix` |

## Phase 1: RED Evidence and Safe Contracts

- [x] 1.1 Add a preflight RED check in `darwin/home/remote-desktop.nix` for readable `/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericNetworkIcon.icns`; prove failure stops before destination mutation.
- [x] 1.2 Add RED evidence for fixed, separately quoted source/destination/tool arguments and absent `lsregister`; prove no wildcard cleanup or masked `cp`, `codesign`, registration, or `mdimport` failure.
- [x] 1.3 Add RED evidence for the four literal legacy paths and an unrelated app; prove migration deletes only the allowlist after friendly deployment and repeated activation is idempotent.

## Phase 2: macm5 Launcher Implementation

- [x] 2.1 Refactor `darwin/home/remote-desktop.nix` records to stable ids plus exactly `Remote T14`, `Remote oneplus`, `Remote Rog`, and `Remote ThinkCentre`; preserve every current connection and invocation field.
- [x] 2.2 Update bundle generation in `darwin/home/remote-desktop.nix` to use friendly directories/plist names, retain `com.glats.remote.<id>`, and reference `GenericNetworkIcon.icns`.
- [x] 2.3 Update activation in `darwin/home/remote-desktop.nix` to copy the native icon into each bundle, then sign, register, index, and remove only the enumerated legacy bundles with failure propagation.

## Phase 3: Scoped Evaluation and Native Verification

- [x] 3.1 Run `nix fmt -- darwin/home/remote-desktop.nix` and `nix eval .#darwinConfigurations.macm5.config.system.build.toplevel.drvPath`; record non-macm5 results as configuration-only evidence.
- [ ] 3.2 On native macm5, build/activate and inspect all four bundles with `plutil`, `test -r`, and `codesign --verify`; confirm local icon metadata/resources and unchanged connection fields.
- [ ] 3.3 On native macm5, verify LaunchServices registration, Finder and Spotlight discovery, and open each friendly bundle; retain an unrelated app while proving legacy cleanup and repeated activation.
