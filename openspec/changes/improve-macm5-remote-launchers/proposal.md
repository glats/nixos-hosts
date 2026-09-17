# Proposal: Improve macm5 Remote Launchers

## Intent

Make every generated macm5 remote-desktop app recognizable in Finder and Spotlight without changing its technical connection behavior.

## Scope

### In Scope
- Rename all generated bundles and user-visible plist names to: `Remote T14`, `Remote oneplus`, `Remote Rog`, and `Remote ThinkCentre`.
- Give every generated bundle a copied native macOS generic network `.icns` resource after validating its target-system path at implementation.
- Preserve each launcher’s protocol, viewer, host, port, executable, bundle identifier, and launch arguments.
- Remove only the enumerated obsolete generated bundles: `remote-t14-tigervnc.app`, `remote-oneplus5.app`, `remote-rog.app`, and `remote-thinkcentre.app`.

### Out of Scope
- Changing remote hosts, credentials, protocol settings, or desktop-client packages.
- Adding custom artwork, icon-conversion tooling, or a repository-managed icon asset.
- Changing Linux remote launchers or non-macm5 Home Manager configurations.

## Capabilities

### New Capabilities
- `macm5-remote-desktop-launchers`: Friendly, icon-bearing macm5 remote-desktop app bundles with safe migration from technical names.

### Modified Capabilities
None.

## Approach

Extend the Darwin launcher definitions with presentation metadata distinct from technical connection metadata. Generate each app directory and visible plist name from the exact names above (none contains a hyphen), while retaining the existing connection fields and stable technical identifiers. On macm5, validate a native generic network icon resource path, copy that `.icns` into each bundle’s resources, reference it from `Info.plist`, then sign and register the deployed bundles. During activation, replace each friendly destination and clean only the four known stale technical destinations.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `darwin/home/remote-desktop.nix` | Modified | Bundle metadata, icon resource, deployment migration, and registration for all four launchers. |
| `~/Applications` on `macm5` | Modified | Friendly app bundles replace enumerated technical-name bundles. |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Native icon resource path is unavailable | Low | Validate a readable macm5 path before copying; do not substitute an unreviewed asset. |
| Cleanup removes an unintended app | Low | Delete only the four exact legacy generated paths. |
| Finder or LaunchServices retains stale metadata | Medium | Re-sign, force-register, re-index, and verify on macm5. |

## Rollback Plan

Revert the launcher metadata and activation migration, restore the prior technical bundle destinations from the next Home Manager activation, and re-register them on macm5. Connection behavior remains unchanged throughout.

## Dependencies

- Native macm5 access to validate and copy the generic network icon resource.

## Success Criteria

- [ ] macm5 deploys exactly the four named bundles, each with a readable bundled network icon.
- [ ] Each launcher retains its current host, protocol, viewer, port, and arguments.
- [ ] No enumerated legacy technical-name bundle remains in `~/Applications` after activation.
- [ ] Native macm5 verification confirms Finder/Spotlight presentation and successful launch behavior.
