# Apply Progress: Port Gentle AI SDD to OpenCode V2

## Status

Implementation is partial. Native V2 assets, remaps, adapters, and the cutover
runbook are authored. Focused remediation R25 made the generated V2 `cli.json`
activation idempotent; broader validation remains deferred by user instruction.

R27 corrects the pinned OpenCode 2.0.14 agent schema: the V2 emitter now uses
the singular `agent` map and preserves native `prompt`, `disable`, and
`permission` fields, mapping only legacy `maxSteps` to `steps`. `nix fmt` and
`nix flake check --no-build` passed. macm5 must activate this revision to show
the primary orchestrator through Tab and SDD subagents through `@` mentions.

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

### BrowserMCP singleton transport remediation

- [x] R15 removed the BrowserMCP 0.1.3 startup invocation of
  `killProcessOnPort(port)`. The package still preserves its 12 tool schemas
  and tools-only initialize capability; a busy port is now left untouched
  instead of terminating an unrelated process.
- [x] R16 captured the pre-bridge RED condition. The Rog V2 evaluator still
  produces a global `browsermcp` entry with `type = "local"`, which causes each
  OpenCode V2 workspace to launch its own fixed-port child. This is not a valid
  singleton transport.

| Work unit | Focused test command and exact result | Runtime harness command/scenario and exact result | Rollback boundary |
|---|---|---|---|
| R15 kill-neutralized BrowserMCP | `nix fmt -- pkgs/browsermcp-v2/default.nix`, `nix build .#packages.x86_64-linux.browsermcp-v2 --no-link --print-out-paths`, and `nix flake check --no-build` — exit 0. The built `dist/index.js` has no `killProcessOnPort(port);` invocation, advertises `tools: {}` without `resources: {}`, and retains 12 tool union members. | Built source inspection confirms `createWebSocketServer` waits for a free port without calling the process-killer. A multi-client service runtime is blocked by R14/R17. | `pkgs/browsermcp-v2/default.nix` |
| R16 local-emission RED | `nix eval --raw '.#homeConfigurations.rog.config.home.file.".config/opencode-v2/opencode.json".source'` and `nix build .#homeConfigurations.rog.activationPackage --no-link` — exit 0. Current V2 generator source emits `browsermcp = { type = "local"; ...; }`. | N/A — the proof deliberately captures the unsafe pre-bridge configuration; running multiple workspaces would reproduce the fixed-port conflict. | No production change; evidence targets `shared/opencode/runtime-config.nix` |

### BrowserMCP broker remediation

- [x] R14 introduced `browsermcp-broker`, a standard-library Go loopback HTTP
  broker. It starts one proxy-scrubbed BrowserMCP stdio child, performs and
  caches synthetic `initialize`/`tools/list`, and maps random child JSON-RPC
  IDs back to each caller's ID. The final design's safe default retains that
  child until broker shutdown rather than closing it on idle, preserving the
  extension pairing until R24 proves idle shutdown safe.
- [x] R17 added concurrent JSON-RPC correlation coverage, loopback bind and
  occupied-port rejection coverage, and proxy-scrub coverage.
- [x] R18-R20 added the `bridgePackage` and `bridgePort` options plus supervised
  `browsermcp` systemd and launchd services with restart-on-failure policies.
- [x] R21-R23 replaced the V2 local entry with exactly one global remote
  `http://127.0.0.1:9008/mcp` entry and checked its generated Rog configuration.
- [x] R14a resolved the package build blocker: the previously authored broker
  command and internal package were untracked, so Nix's Git flake source omitted
  them despite `default.nix` registering `cmd/browsermcp-broker`. They are now
  registered in Git's index without a commit.

| Work unit | Focused test command and exact result | Runtime harness command/scenario and exact result | Rollback boundary |
|---|---|---|---|
| R14/R17 broker | `go -C pkgs/nixos-scripts test ./...` — exit 0; concurrent client test preserves each caller ID, uses one child, rejects an occupied loopback port, and scrubs proxy variables. `nix build --impure path:/home/glats/.nixos#packages.x86_64-linux.nixos-scripts --no-link` — exit 0. | In-process `httptest` concurrently sends 24 `tools/call` requests after the cached discovery handshake; all responses retain their originating IDs. This is safe without a paired browser extension. | `pkgs/nixos-scripts/{cmd/browsermcp-broker,internal/browsermcp,default.nix}` |
| R18-R23 configuration | `nix build --impure path:/home/glats/.nixos#homeConfigurations.rog.activationPackage --no-link` — exit 0; Nix assertion confirms the systemd broker service. | Rog generated config assertion confirms one global remote URL at `127.0.0.1:9008`, no local command, and one restart-on-failure service. | `shared/opencode.nix`, `shared/opencode/v2-mcps.nix`, `shared/opencode/runtime-config.nix` |
| R14a tracked broker source | `go -C pkgs/nixos-scripts test ./...` — exit 0; `nix build .#nixos-scripts --no-link` — exit 0; `nix eval .#homeConfigurations.rog.activationPackage.drvPath` — exit 0. | N/A — this fixes flake source inclusion; the existing broker unit tests exercise the HTTP/child boundary. | Git index entries for `pkgs/nixos-scripts/{cmd/browsermcp-broker,internal/browsermcp}` |
| R25 V2 `cli.json` activation | `nix fmt -- shared/opencode/runtime-config.nix`; `nix eval .#homeConfigurations.rog.activationPackage.drvPath` — both exit 0. | `home-manager switch --flake .#rog` — exit 0 with a pre-existing `~/.config/opencode-v2/cli.json.backup`; activation ran `cleanupOpencodeV2CliBackup-v2` before `linkGeneration`, and the backup was absent afterward. | V2 `cli.json` `home.file` and `cleanupOpencodeV2CliBackup-v2` in `shared/opencode/runtime-config.nix` |

- [x] R25 declared V2 `cli.json` as a forced generated `home.file` and added a
  pre-`linkGeneration` cleanup for only
  `~/.config/opencode-v2/cli.json.backup`. The V1 runtime configuration and all
   other V2 state are not touched.
- [x] R26 diagnosed the deployed `127.0.0.1:9008` listener as rog's
  `code-server.service` child (PID 2242), not a stale broker. The bridge now
  defaults to `9010`; the broker maps `EADDRINUSE` to exit status `78` and the
  Linux user unit sets `RestartPreventExitStatus=78`. A foreign listener is
  therefore neither replaced nor retried in a restart loop.

| Work unit | Focused test command and exact result | Runtime harness command/scenario and exact result | Rollback boundary |
|---|---|---|---|
| R26 deployed bridge ownership | `go -C pkgs/nixos-scripts test ./...`; `nix eval .#homeConfigurations.rog.activationPackage.drvPath`; `nix build .#nixos-scripts --no-link` — all exit 0. The broker occupied-port unit test now preserves `EADDRINUSE`. | `home-manager switch --flake .#rog` — exit 0. `sudo -n ss` attributes 9008 to code-server and 9010 to browsermcp-broker. A direct broker start at occupied 9008 exits 78; `systemctl --user` shows the actual broker active with `NRestarts=0`; JSON-RPC `initialize` at `http://127.0.0.1:9010/mcp` returns HTTP 200. | `shared/opencode.nix`, broker command/error classifier, and BrowserMCP V2 port contract |

## Current Blocker

R24 requires a paired BrowserMCP extension and activation on rog, then the
remaining hosts. It was intentionally not started during apply: a real
unpaired extension must report unpaired rather than be faked healthy, and the
user deferred independent SDD verification. The broker and generated runtime
are ready for that runtime gate.
