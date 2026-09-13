# Design: Replace Local Secret Guard

## Technical Approach

Replace the broken managed TypeScript plugin with `opencode-warden@1.2.0` as a shared npm plugin. The existing Nix permission denies remain the authorization boundary; Warden adds redaction, shell-environment sanitization, and sensitive-path protection. This fulfills the proposal without adding an unverified Warden configuration file: use its documented default regex-only policy, with prompt scanning and LLM features disabled.

## Architecture Decisions

| Decision | Choice | Alternatives considered | Rationale |
|---|---|---|---|
| Distribution | Nix-store package closure plus exact OpenCode plugin spec | OpenCode runtime npm install | `runtime-config.nix` already copies the Nix-built closure to `node_modules`; fixed source hashes prevent network-dependent activation. |
| Configuration | No local replacement plugin or speculative config schema | Fork Warden; write an unverified config file | The selected release supplies the desired default policy. A future policy change must be separately researched and pinned. |
| Authorization | Preserve `permissions.nix` unchanged | Delegate access control to Warden | Nix denies for `sops*`, `.env*`, `/run/secrets/**`, and other secret paths are deterministic and enforceable. |
| Legacy cleanup | Explicitly delete the deployed `plugins/secret-guard.ts` during activation | Remove its managed entry only | Once removed from `managedPlugins`, the computed disabled-plugin cleanup no longer knows its name; an explicit cleanup prevents a stale broken file from loading. |

## Data Flow

```
versions.json + node-modules.json
        -> pkgs.opencode-npm-packages (fetchurl hash verification)
        -> activation copies lib/node_modules to runtime node_modules
        -> opencode.json plugin: "opencode-warden@1.2.0"
        -> OpenCode 1.18.22 loads Warden hooks

permissions.nix -> opencode.json permission -> enforceable deny
```

## File Changes

| File | Action | Description |
|---|---|---|
| `shared/opencode-profile.nix` | Modify | Remove `secretGuard.enable`; enable the shared Warden npm entry. |
| `shared/opencode/plugins.nix` | Modify | Delete the `secretGuard` option and `activePlugins` entry; append exact `opencode-warden@1.2.0` to `npmPlugins`. |
| `shared/opencode/runtime-config.nix` | Modify | Remove the managed `secret-guard.ts` source and add legacy runtime-file removal before managed-plugin copies. |
| `pkgs/opencode-npm-packages/versions.json` | Modify | Add Warden 1.2.0 and every production runtime dependency absent from the existing closure. |
| `pkgs/opencode-npm-packages/node-modules.json` | Modify | Add matching SRI hashes for each added tarball. |
| `lib/packages.nix` | Modify | Remove `secret-guard-assets` from common packages. |
| `overlays/linux.nix` | Modify | Stop exporting `secret-guard-assets`. |
| `overlays/darwin.nix` | Modify | Stop exporting `secret-guard-assets`. |
| `pkgs/secret-guard-assets/default.nix` | Delete | Retire the local asset derivation. |
| `pkgs/secret-guard-assets/share/secret-guard/opencode/plugins/secret-guard.ts` | Delete | Retire the invalid object-export plugin. |

## Interfaces / Contracts

The generated `opencode.json` plugin array MUST contain exactly `opencode-warden@1.2.0` and MUST NOT contain `secret-guard`. The runtime npm closure MUST contain that package and all required production dependencies before activation. `permissions.nix` is unchanged.

Pin each package under the existing derivation convention: obtain its npm tarball URL (`https://registry.npmjs.org/opencode-warden/-/opencode-warden-1.2.0.tgz` for Warden), run `nix-prefetch-url`, convert with `nix hash to-sri --type sha256`, and record the exact version/hash pair in the two JSON maps. Inspect Warden's pinned tarball `package.json`; add every non-peer production dependency by the same process. `default.nix` then fetches, verifies, and extracts each listed tarball. The generated package manifest's caret ranges do not determine the deployed content; the fixed `fetchurl` hashes do.

## Testing Strategy

| Layer | What to Test | Approach |
|---|---|---|
| Evaluation | All shared host configurations and package hashes | `format-nix && nix flake check --no-build`; evaluate the package and each Linux/Darwin HM configuration. |
| Closure/config | Exact registration, package presence, and removal | Build one Linux activation package and inspect generated `opencode.json` plus `lib/node_modules`; assert Warden exact spec/payload and no `secret-guard` references outside historical OpenSpec artifacts. |
| Runtime smoke | OpenCode 1.18.22 load and safe behavior | After Home Manager activation on one Linux host and mact2, launch an offline controlled session; confirm no plugin-load error, synthetic key-shaped bash output is redacted, synthetic `SOPS_AGE_KEY` is absent from shell-tool environment, and secret-path access is denied. Never use real secrets. |

## Threat Matrix

| Boundary | Applicability | Design response | Planned RED tests |
|---|---|---|---|
| Documentation-like paths | N/A — no executable classification changes | None | None |
| Git repository selection | N/A — no VCS command integration | None | None |
| Commit state | N/A — no commit automation | None | None |
| Push state | N/A — no push automation | None | None |
| PR commands | N/A — no PR automation | None | None |

## Migration / Rollout

No data migration is required. Validate Nix evaluation first, deploy and smoke-test Linux, then mact2. Roll back by reverting the migration commit and switching Home Manager; this restores the local derivation/declarations and activation refresh removes the Warden configuration. Permission denies remain active in both states.

## Open Questions

- [ ] During implementation, does the pinned Warden tarball have production dependencies beyond the already-pinned `@opencode-ai/plugin` peer? Record every required runtime package in the fixed closure before enabling it.
