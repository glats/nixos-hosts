# Design: Improve macm5 Remote Launchers

## Technical Approach

Keep `darwin/home/remote-desktop.nix` as the sole macm5 launcher builder. Replace its overloaded `name` with stable technical identity plus declarative presentation metadata. The derivation continues to compile the same native launcher and the activation continues to deploy, ad-hoc sign, register, and index each bundle; only the bundle path, visible plist values, and local icon resource change.

## Architecture Decisions

| Decision | Choice | Alternative rejected | Rationale |
|---|---|---|---|
| Identity and presentation | Separate stable `id` from `bundleName` | Reuse a single renamed `name` | `id` preserves log names and `CFBundleIdentifier`; presentation can contain spaces without changing connection metadata. |
| Icon source | Copy the approved macOS `GenericNetworkIcon.icns` during activation | Repo artwork, conversion tooling, external icon reference | It is native, dependency-free, and copied locally as required by bundle metadata. |
| Migration | Remove an explicit four-item legacy path list after friendly deployment | Wildcard or prefix cleanup | The finite allowlist is idempotent and cannot remove unrelated applications. |
| Integration failures | Preflight icon source; use quoted fixed paths; do not mask copy/sign/register failures | Continue with `|| true` or fallback icon | A successful activation must not claim deployable, signed, registered bundles when a required integration failed. |

## Data Flow

```
apps records (id + bundleName + connection) 
  ├─> mkLauncherC(connection fields unchanged) ─> native launcher
  └─> mkRemoteApp(bundleName, id) ─> .app + Info.plist
activation preflight ─> copy to ~/Applications/<bundleName>.app
  ─> copy local GenericNetworkIcon.icns ─> sign ─> LaunchServices register ─> Spotlight index
  ─> delete four literal legacy paths
```

## File Changes

| File | Action | Description |
|---|---|---|
| `darwin/home/remote-desktop.nix` | Modify | Add presentation metadata, local icon assembly, friendly deployment paths, and allowlisted legacy cleanup. |
| `openspec/changes/improve-macm5-remote-launchers/design.md` | Create | This design artifact. |

## Interfaces / Contracts

`apps` becomes the closed declarative data source; no module option is added because this is macm5-local configuration.

```nix
{
  id = "t14-tigervnc"; # stable: logs and com.glats.remote.<id>
  bundleName = "Remote T14"; # directory, CFBundleName, CFBundleDisplayName
  legacyBundleName = "remote-t14-tigervnc.app";
  protocol = "vnc";
  viewer = "tigervnc";
  host = "172.16.0.10";
  port = "5900";
}
```

The other records retain their current connection fields and use `id` values `oneplus5`, `rog`, and `thinkcentre`, with bundle names `Remote oneplus`, `Remote Rog`, and `Remote ThinkCentre`; their literal legacy paths are respectively `remote-oneplus5.app`, `remote-rog.app`, and `remote-thinkcentre.app`. `CFBundleIdentifier` remains `com.glats.remote.${id}`. The plist adds `CFBundleIconFile = "GenericNetworkIcon.icns"`; every bundle receives that exact filename at `Contents/Resources/GenericNetworkIcon.icns` from `/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericNetworkIcon.icns`.

Before modifying destinations, activation MUST require the icon source to be readable. All source, destination, icon, tool, and cleanup paths are fixed configuration values and shell-quoted; `cp`, `codesign`, `lsregister`, and `mdimport` receive separate arguments, never evaluated data. Copy/sign/register failures stop activation; the absent `lsregister` executable is a clear platform failure, not silently ignored. Friendly bundles are deployed before the explicit cleanup loop.

## Testing Strategy

| Layer | What to Test | Approach |
|---|---|---|
| Configuration | Four records, stable identities, fixed legacy list, unchanged invocation fields | Linux may run `nix eval .#darwinConfigurations.macm5.config.system.build.toplevel.drvPath`; record this as evaluation-only. |
| Build | Nix syntax and Darwin derivation wiring | On macm5, format the module and evaluate/build the macm5 toplevel. |
| Native integration | Plist names/icon references, readable local icons, signatures, registration, Finder/Spotlight discovery, launch invocation, idempotent allowlisted cleanup | On macm5 after activation, inspect each bundle with `plutil`, `test -r`, `codesign --verify`, LaunchServices/Spotlight tools, and open each app; retain an unrelated `.app` for cleanup proof. Temporarily unavailable source must make activation fail before destination mutation. |

## Threat Matrix

The matrix applies because activation invokes copy, signing, registration, and indexing subprocesses. Its VCS/classification rows are all N/A:

| Boundary | Applicability | Design response | Planned RED tests |
|---|---|---|---|
| Documentation-like paths | N/A — bundle names are fixed app paths, not executable-file classification | N/A | N/A |
| Git repository selection | N/A — no Git invocation | N/A | N/A |
| Commit state | N/A — no commit operation | N/A | N/A |
| Push state | N/A — no push operation | N/A | N/A |
| PR commands | N/A — no PR command | N/A | N/A |

The applicable process boundary is bounded by the preflight, fixed literal inputs, argument separation, and failure propagation above; native failure testing is specified in the integration row.

## Migration / Rollout

No data migration is required. A macm5 Home Manager activation replaces the four friendly destinations, then removes only the listed legacy bundles. Reverting restores prior generated paths on the next activation; Linux does not execute this rollout.

## Open Questions

None; implementation must validate the approved icon path on macm5 before relying on it.
