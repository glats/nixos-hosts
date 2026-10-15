# Nonlive native plugin API check

PASS — **LIMITED / APIIMPORT ONLY**, verified on 2026-10-09. The unchanged rendered Gentle v4 review relay imports through the actual shipping `@opencode/plugin@2.0.14` root export and passes strict TypeScript checking against its real Promise plugin/context/hook declarations. This closes the actual-export/import/signature gap left by the 24 mocked Bun fixtures. It does not certify organic runtime behavior, SDK initialization, provider calls, native CLI plugin loading, or fleet compatibility. STOP #3934 remains effective after continuation #3961.

## Actual artifacts and independent versions

- Shipping dependency root: `/nix/store/dals03h3rvllh7m6h6iknpmywim66lki-opencode-npm-packages-v2-2.0.14/lib/node_modules`.
- Candidate assets: `/nix/store/ia2an10mnvws4f2sksxlh1xfl7wkvs9a-gentle-ai-assets-4.0.0/share/gentle-ai/opencode-v2/plugins/opencode-review-transport.ts`. The current rog package output was obtained with read-only offline Nix evaluation.
- Exact tagged source: `/nix/store/ajzrynhhnm33f6n7lfz3vl6wmcbiyddl-source`, Gentle `v4.0.0`, commit `ff77164d4f56f1665b22fb6fac51c2ccbb769400`. Tagged relay SHA256: `e52edacb8868d227cb5ec74505fa60dc555d120ec7b5c64ceaf0291176856e94`. Rendered relay SHA256: `5daad28deb0fb675ebe1dadad8abd06f7c90e653c0170cbe796c365eb8d6850f`. Byte comparison passed after only the declared `Command: "gentle-ai"` substitution with `/nix/store/qib05gd4hc6dc0yqlbaa67ld0y5g35v9-gentle-ai-4.0.0/bin/gentle-ai`.
- Actual package manifests independently report plugin/client/schema/ai/protocol/util **2.0.14**, Effect **4.0.0-rc.112**, Zod **4.1.8**, `@ai-sdk/provider` **3.0.8**, and `@standard-schema/spec` **1.1.0**. No inferred version equality or dependency upgrade was used.
- Public `@opencode/sdk@2.0.14` metadata independently specifies core/server/client/plugin/schema/util **2.0.14** and Effect **4.0.0-rc.112**. SDK/core/server are **not** members of this shipping plugin closure and were not imported or initialized. The tagged installer expectation of SDK **2.0.4** remains separate from the package version actually checked here.

## Pre-import safety review

The OpenCode skill, official [V2 plugin guide](https://opencode.ai/v2/docs/build/plugins), and Context7 `/websites/opencode_ai_v2` plugin lifecycle/migration documentation were read first. Documentation distinguishes defining a plugin from running `setup` or passing it to `OpenCode.create`; current docs alone are not pinned-version evidence.

The actual package export map selects `dist/promise/index.js`. That root exports `Plugin` from `./plugin.js` and schema namespaces. Its actual `dist/promise/plugin.js:1–3` is:

```js
export function define(plugin) {
    return plugin;
}
```

Its actual declaration takes `Plugin`, not an unconstrained generic or `any`; the definition requires `id: string` and `setup(context: Context)` returning optional cleanup, synchronously or through a Promise. The identity behavior is the shipped implementation, **not** a recreated identity mock.

A scratch static import/re-export traversal found 234 JS files across `@opencode/plugin`, `@opencode/schema`, and Effect, with no Node builtin imports in that graph and no SDK/core/server modules. Potential filesystem/environment/persistence matches were inspected as lazy Effect functions, service definitions, or comments, not OpenCode host/account initialization. For example, Effect `ConfigProvider.fromEnv` reads environment only inside its function; filesystem and SQL helpers do not supply or start a native platform service at import. Schema credential/connection modules define data shapes, not account storage access. This is a bounded public-module review, not reverse engineering or a whole-native-binary source audit.

The candidate's only other import is Node's `child_process`; importing it does not spawn anything. `spawn` is inside `startRelay`, reachable only after a review hook is invoked. Its global relay registry, subscriptions, abort controller, registrations, and cleanup are created inside `setup`, not module import. **Setup and hooks were not invoked.** All execution used `env -i`, fresh scratch HOME/XDG directories, an explicit Bun/Node executable, and no production runtime configuration or inherited provider credentials.

## Empirical checks

Scratch evidence is retained under `/home/glats/.local/opencode-v2/tmp/opencode/plugin-api-check-3961/`: `audit.py`, `import-graph.txt`, `import-audit.log`, `relay.ts`, `check.ts`, `tsconfig.json`, `typecheck.log`, `import-check.log`, `provenance.json`, and `source-before.sha256`.

1. Copied rendered relay is byte-identical to the store candidate; its existing assertions were preserved. No product/test source edits, import rewrites, `as any`, ambient plugin shim, or mocked plugin export were introduced.
2. Public TypeScript **5.8.2** and `@types/node` **24.12.2** (matching the actual plugin manifest's development versions), plus `undici-types` **7.16.0**, were downloaded as tarballs and unpacked only into scratch. No package-manager installation, lifecycle scripts, or production dependencies/configuration were changed.
3. `node node_modules/typescript/bin/tsc --project tsconfig.json` exited **0**, empty diagnostics. Options: ES2022, ESNext, Bundler resolution, `strict: true`, `noEmit: true`, Node types. `skipLibCheck: true` excludes checking dependency declaration internals; it does **not** skip candidate TypeScript or its contextually typed hook callbacks. No claim that every transitive declaration independently typechecks is made.
4. The scratch check assigns the actual export to `Plugin.Plugin` and its setup to the actual `Plugin.Context`/`Plugin.Cleanup` signature. The unchanged relay's callback bodies therefore compile against actual `tool.hook("execute.before")`, `tool.hook("execute.after")`, `shell.hook("create.before")`, and `event.subscribe` declarations. These names are source/type-verified, **not runtime registration receipts**. Completed/error hook discrimination, mutable result/content, session deletion location/data, and shell environment field access compile without new weakening assertions.
5. Fresh `bun run --no-install ./check.ts` exited **0** and printed `PASS actual @opencode/plugin 2.0.14 root export, unchanged rendered relay import and definition signature; setup NOT invoked`. Assertions verify the plugin ID, callable setup, only `id`/`setup` definition keys, identity through the actual `Plugin.define`, and absence of the setup-owned global relay registry after import.
6. Candidate source retains all six role names: `review-risk`, `review-resilience`, `review-readability`, `review-reliability`, `review-refuter`, `review-validator`; Go entry fields, staged contract, and opaque wire ownership remain unchanged by the byte comparison. No relay process or provider/tool invocation was performed in this check.
7. Before/after SHA256 verification passed for `flake.nix`, `flake.lock`, `pkgs/gentle-ai-assets/default.nix`, `render.nix`, and `opencode-review-transport.test.ts`. The repository write for this worker is only this report; no shared progress/task records, index, refs, activation, or services were changed.

## Remaining boundary

There is no new incompatibility or new authentication blocker from this check. Actual API import and candidate implementation typing pass against the pinned shipping dependency package. Native host startup, SDK/plugin initialization, effective server registration, tool execution, receipt admission, authenticated model behavior, cleanup in the real runtime, and cross-host organic certification remain untested here. Those require the separately authorized isolated runtime cycle already blocked by STOP #3934; this PASS neither bypasses that stop nor completes task 3.4.
