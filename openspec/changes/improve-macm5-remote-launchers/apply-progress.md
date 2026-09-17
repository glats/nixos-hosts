# Apply Progress: Improve macm5 Remote Launchers

## Status

- Change: `improve-macm5-remote-launchers`
- Apply state: ready
- Delivery: `single-pr`
- Work unit: all macm5 launcher implementation and scoped Linux verification
- Mode: Standard (strict TDD disabled)

## Focused Remediation

- Moved the existing destination write-permission adjustment to immediately after the bundle copy and changed it to owner-only `u+w`, allowing the icon copy to succeed without broadening permissions.
- Preserved the strict command order after icon installation: `xattr`, `codesign`, then LaunchServices registration.
- Normalized owner-write permission recursively on an existing destination immediately before removal, allowing replacement of the read-only native bundle observed on macm5.
- Added a `writeBoundary`-ordered activation step that creates or atomically merges `$HOME/.config/freerdp/sdl-freerdp.json` with `UseLocalMouseScrollDirection: true`, preserving unrelated JSON object keys.
- The FreeRDP configuration step refuses symlinks, non-regular files, invalid JSON, and non-object JSON roots without replacing the target; temporary files are removed on every handled failure.

## Completed Tasks

- [x] 1.1 Added a native icon readability preflight before any `~/Applications` mutation.
- [x] 1.2 Added fixed, quoted source/destination/tool paths, an explicit `lsregister` preflight, and failure propagation for copy, signing, registration, and indexing.
- [x] 1.3 Added the four literal legacy bundle records and an allowlist-only cleanup loop after friendly deployment.
- [x] 2.1 Refactored the four records to stable technical ids and the exact requested friendly names while preserving hosts, protocols, viewers, ports, and invocation arguments.
- [x] 2.2 Generated friendly bundle directories and matching plist names, retained `com.glats.remote.<id>`, and referenced `GenericNetworkIcon.icns`.
- [x] 2.3 Copied the native icon into each bundle, then removed quarantine metadata, signed, registered, indexed, and cleaned only the four legacy bundles; existing destinations are normalized with recursive owner-write permission before removal.
- [x] 3.1 Formatted the module and ran scoped repository evaluation checks; Linux results are configuration-only.
- [x] Immediate scroll-direction correction: declaratively set `UseLocalMouseScrollDirection` for macm5 without changing the FreeRDP overlay or launcher arguments.

## Work Unit Evidence

| Evidence | Result |
|---|---|
| Focused test command and exact result | `nix fmt -- darwin/home/remote-desktop.nix` passed with 0 changes; `git diff --check` passed; `nix flake check --no-build` failed while evaluating unrelated Linux configuration option `home-manager.users.glats.activation` from `linux/home/tmux.nix`. |
| Runtime harness command/scenario and exact result | N/A on this Linux checkout: native macm5 activation, icon inspection, signing, registration, Spotlight/Finder discovery, and launch checks were not simulated. |
| Rollback boundary | Revert `darwin/home/remote-desktop.nix`; no unrelated files or secrets are part of the implementation change. |

## Scoped Evaluation

- `nix eval .#darwinConfigurations.macm5.config.system.build.toplevel.drvPath` was attempted and could not complete on Linux because the Darwin configuration evaluates an `aarch64-darwin` derivation (`platform mismatch`).
- `nix flake check --no-build` reached the Linux configurations but failed on the unrelated `home-manager.users.glats.activation` option in `linux/home/tmux.nix`; incompatible Darwin systems were not evaluated.
- The closest available Linux-side validation confirms formatting and diff cleanliness; native macm5 activation is still required to exercise the FreeRDP JSON branch against macOS filesystem and activation behavior.
- Native macm5 verification remains pending and must be performed on macm5 without treating Linux evaluation as native evidence.
- Native macm5 activation remains needed to confirm replacement of read-only existing bundles and the previously pending Finder, Spotlight, signing, registration, and launch behavior.

## Remaining Tasks

- [ ] 3.2 On native macm5, build/activate and inspect all four bundles with `plutil`, `test -r`, and `codesign --verify`; confirm local icon metadata/resources and unchanged connection fields.
- [ ] 3.3 On native macm5, verify LaunchServices registration, Finder and Spotlight discovery, and open each friendly bundle; retain an unrelated app while proving legacy cleanup and repeated activation.

## Deviations from Design

None — implementation follows the approved design. The existing `xattr -cr` step is now failure-propagating rather than masked; this is stricter and does not alter launcher behavior.
