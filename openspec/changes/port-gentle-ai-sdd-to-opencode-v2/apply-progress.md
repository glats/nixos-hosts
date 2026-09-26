# Apply Progress: Port Gentle AI SDD to OpenCode V2

## Status

Implementation is partial. Native V2 assets, remaps, adapters, and the cutover
runbook are authored. Focused remediation R4 fixed the native V2 command-tree
activation failure; broader validation remains deferred by user instruction.

## Delivery Decision

The user accepted one direct-to-main `size:exception` for the complete port. Apply must not commit or push, and SDD verify is explicitly deferred.

## Completed Tasks

- [x] 1.3 Verified and recorded pinned package releases: `@opencode/plugin`, `@opencode/client`, and `@opencode/sdk` are all `2.0.14`; their fetched SRI hashes are `sha256-/v6kA+OWv6HXhzWfk6iRXkMuqQuu4Q9NyjyItjKrWDw=`, `sha256-a/SHih88yCzSOEtOrh74fjKak60QUFw6Z0OVzzOtktc=`, and `sha256-LQ110QxRX2WyHgKbrvf07IrunrLHCukEGKFihSJ6mUU=` respectively.
- [x] 1.6 Verified the pinned plugin declarations. `Plugin.define({ id, setup(ctx) })` is available through the exported `Plugin` namespace; `ctx.tool.hook`, `ctx.session.hook`, and `ctx.permission.hook` are available.

## Work Unit Evidence

| Work unit | Focused test command and exact result | Runtime harness command/scenario and exact result | Rollback boundary |
|---|---|---|---|
| P0 API/package gate | Prior `nix build .#opencode-v2 --no-link` — exit 0; pinned SDK declarations inspected | N/A — validation is explicitly deferred | `pkgs/opencode-npm-packages-v2/` and `lib/packages.nix` |
| P1/P2 native emission | Not run — user explicitly instructed no verification | Not run — user explicitly instructed no verification | V2-only paths in `shared/opencode/runtime-config.nix` and `shared/opencode/v2-*.nix` |
| P3 adapters | Not run — user explicitly instructed no verification | Not run — user explicitly instructed no verification | V2-only adapter sources and asset staging paths |
| P4 drops and cutover | Not run — user explicitly instructed no verification | Not run — user explicitly instructed no verification | V2 activation cleanup and `docs/opencode-v2-final-cutover.md` |

## Pending Tasks

Completed implementation tasks: 1.3, 1.6, 2.1-2.3, 3.2-3.6, 4.5-4.9, and
5.1-5.2. Remaining tasks are schema/RED, validation, smoke, formatting, and
full-matrix gates: 1.4-1.5, 1.7, 2.4, 3.1, 3.7, 4.1-4.4, 4.10, and 5.3-5.7.
V1 remains default and V2 remains opt-in.

## Focused Remediation

- [x] R1 Registered `opencode-npm-packages-v2` in the Linux and Darwin overlays.
  The V2 runtime's package reference now resolves through `pkgs` on both
  platforms.

| Work unit | Focused test command and exact result | Runtime harness command/scenario and exact result | Rollback boundary |
|---|---|---|---|
| R1 V2 npm overlay registration | `nix eval .#homeConfigurations.rog.activationPackage.drvPath` — exit 0; `nix eval .#packages.x86_64-linux.opencode-npm-packages-v2.drvPath` — exit 0 | N/A — package-attribute evaluation has no runtime boundary | `overlays/linux.nix`, `overlays/darwin.nix` |
| R2 V1/V2 activation separation | `nix eval .#homeConfigurations.rog.activationPackage.drvPath` — exit 0; `nix build .#homeConfigurations.rog.activationPackage --no-link` — exit 0 | Generated activation contains `setupOpencodePluginRuntime-default` without the V2 `sed` remap, followed by `setupOpencodePluginRuntime-v2`; exit 0 | V2 setup block in `shared/opencode/runtime-config.nix` |

R2 moved V2 skill/command copying, `subtask` → `subagent` remapping, plugin
drop cleanup, and V2 npm staging out of the V1 activation. The V2 copy now
makes copied command and skill files user-writable before `sed -i`, while V1
retains its pre-existing mutable-copy and V1-only plugin setup.

`nix eval .#homeConfigurations.macm5.activationPackage.drvPath` cannot run on
the Linux evaluator because it tries to build Darwin-only assets and fails with
`Required system: 'aarch64-darwin'; Current system: 'x86_64-linux'`; this is
unrelated to the resolved package attribute.

- [x] R3 Restored V1 activation ordering and write access for the mutable
  skill tree without changing the V1 runtime contract.
- [x] R4 Recreated the V2 command tree before staging and used non-archive
  copies so source directory modes cannot make the destination read-only.

| Work unit | Focused test command and exact result | Runtime harness command/scenario and exact result | Rollback boundary |
|---|---|---|---|
| R3 V1 writable skill-tree ordering | `nix fmt -- shared/opencode/runtime-config.nix shared/ai-assets.nix shared/skills.nix` — exit 0; `nix eval .#homeConfigurations.rog.config.home.activation.prepareOpencodeSkillTree.data` — exit 0; `nix build .#homeConfigurations.rog.activationPackage --no-link --print-out-paths` — exit 0 | Full generated activation completed `prepareOpencodeSkillTree`, `linkGeneration`, and `makeOpencodeConfigMutable-default` without V1 permission or `sed` errors, then stopped at the unrelated V2 command-copy failure. | `shared/opencode/runtime-config.nix`, `shared/skills.nix`, `shared/ai-assets.nix` |
| R4 V2 writable command-tree staging | `nix fmt -- shared/opencode/runtime-config.nix` — exit 0; `nix eval .#homeConfigurations.rog.activationPackage.drvPath` — exit 0 | `nixos-build test` reached `setupOpencodePluginRuntime-v2`, continued through `syncOpencodeSkillsToOpenfang-default` and `writeGitIdentity` with no V2 copy error; V2 commands are `755` and `sdd-apply.md` is user-owned `644`. | V2 command-tree setup in `shared/opencode/runtime-config.nix` |

- [x] R5-R13 restored the V2 plugin dependency closure and replaced the floating
  BrowserMCP process with one pinned, compatibility-patched global V2 server.

`@opencode/plugin` 2.0.14 declares `@opencode/schema` as a production
dependency, not a peer or bundled dependency. The V2 package now stages it and
the other direct production packages at the top-level Node resolution location.
BrowserMCP is pinned to 0.1.3; its initialize response keeps `tools` but no
longer advertises `resources`, while retaining the resource-list handler through
the compatible pinned MCP SDK patch.

| Work unit | Focused test command and exact result | Runtime harness command/scenario and exact result | Rollback boundary |
|---|---|---|---|
| R5/R8/R9 plugin closure | `nix build .#packages.x86_64-linux.opencode-npm-packages-v2 --no-link --print-out-paths`; `test -d "$plugin/lib/node_modules/@opencode/schema"`; ESM `import("@opencode/plugin")` from its staged `lib` — all exit 0, printed `plugin dependency closure resolves` | The five V2 adapter imports resolve from the same sibling `node_modules` topology used by the runtime. | `pkgs/opencode-npm-packages-v2/{default.nix,versions.json,node-modules.json}` |
| R6/R7 BrowserMCP compatibility package | `nix build .#packages.x86_64-linux.browsermcp-v2 --no-link --print-out-paths` — exit 0 | JSON-RPC initialize against the built binary returned `tools` and omitted `resources`; no module-resolution failure. | `pkgs/browsermcp-v2/`, `lib/packages.nix`, platform overlays |
| R10-R12 singleton configuration | Rog V2 `opencode.json` evaluation asserted exactly one `browsermcp` server command and no `npx` — exit 0 | The generated command is the pinned package binary and remains only in the global V2 map; project config stays disabled by `OPENCODE_DISABLE_PROJECT_CONFIG=1`. | `shared/opencode.nix`, `shared/opencode/mcps-base.nix`, `shared/opencode/runtime-config.nix` |
| R13 focused gate | `nix flake check --no-build` — exit 0; `nix eval .#homeConfigurations.rog.activationPackage.drvPath` — exit 0 | Built BrowserMCP completed the initialize handshake with tool capability only. | All R5-R12 files |
