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
