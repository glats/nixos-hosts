# Model catalog gate: approved repair applied, zero usable-missing

Latest status, 2026-10-09: operator-approved decision #3979 is now applied in primary source after the parent reported all six old-source Linux native closures passed (#3968). Exactly three profiles are retired; NVIDIA gains the same-backend native alias. The applied inventory matches the preview: **32 profiles, 23 built-in plus three custom selectors, zero usable-missing** against the saved public response fetched at 16:56 UTC. No new model assignment, paid fallback, policy waiver, login/model request or activation was performed by this worker. Repaired-source evaluation/native-build results are recorded in the final repair section below; historical findings and hashes remain intact.

## Historical initial findings (before decision #3979)

The current public catalog and exact OpenCode 2.0.14 implementation establish a real S8 blocker: `opencode/mimo-v2.5-free` is deprecated and removed by the native catalog loader, while eight NVIDIA review/judgment routes reference an undeclared model key. All 25 unique non-NVIDIA built-in selectors exist as raw public catalog keys, but only 24 survive the loader's deprecation filter. A raw-key-only zero-missing result would be misleading. No routing, model, product, or SDK changes were made.

## Scope and identity

This independent check ran in primary `/home/glats/.nixos` under continuous authorization #3961 on 2026-10-09. Read model-fit, OpenCode, and verify-and-stop skills; inspected S7/S8 in `specs/gentle-ai-declarative-runtime/spec.md`, provider profiles, agent generation, and native V2 projection. The parallel Linux build report was not edited. No credentials, auth directories, runtime databases/logs, account catalogs, model requests, login, SDK host creation, background service startup, MCP/provider connection, SSH, activation, Git delivery, or product edits occurred. HTTP requests were public dependency/document/catalog research only.

Actual flake evaluation identifies Gentle AI v4.0.0 source revision `ff77164d4f56f1665b22fb6fac51c2ccbb769400` at `/nix/store/ajzrynhhnm33f6n7lfz3vl6wmcbiyddl-source`; `pkgs/gentle-ai/default.nix` sets binary version and linker version to 4.0.0. The built ODD overlay contains the exact four Gentle ODD agents plus three Judge Day and six review agents. Inspection of the tagged V2 review relay found no model/provider catalog mutation that restores the absent selectors.

| Repository evidence | SHA-256 |
|---|---|
| `shared/opencode/providers-base.nix` | `189d7581403f75fe3d0c43f38b46742c4931c2d0a3eeb5aa26dc3e5e33e28429` |
| `shared/opencode/agents.nix` | `03064ef508e02aed1f6380502d8f2b93eb3d484e08d2f4a9612d0e0871578668` |
| `shared/opencode/runtime-config.nix` | `a5c835f23da33f62cd8272fa9c156c13bab3b6536af879aa97c65c4733fb153a` |
| `shared/opencode/v2-agents.nix` | `a93cb81510860db1c21b73a4f819bcf77990f1243873155149cd10be67b93ca1` |
| Evaluated `{providers,nvidiaProvider,providerAllowlist}` JSON, sorted keys, compact separators | `ea104f730f10a37928b52f49a2796a1aa545a0ff1868d10cf6ce16e1ed09e739` |

The evaluated inventory contains **35 profiles and 28 unique surviving selectors**, including three NVIDIA selectors. Retired `sdd-*` fields are not executable candidate routes: the final transformation at providers-base lines 1114–1123 removes them and maps explore/apply/verify to the three ODD workers. Inventory below covers the actual exported profiles, not regex matches in comments or removed phase assignments.

## Authoritative source and catalog acquisition

Context7 `/websites/opencode_ai_v2` was resolved and queried for provider/model catalog and SDK/API contracts. Official V2 pages read: [providers](https://opencode.ai/v2/docs/providers), [models](https://opencode.ai/v2/docs/models), and [embedded SDK](https://opencode.ai/v2/docs/build/sdk). These identify models.dev, explicit provider model maps, case-sensitive selectors split at the **first** slash, and embedded host initialization. `GET /api/provider` is a running-host API, not a pure static catalog accessor. It was not invoked.

Public GitHub tag API resolved `v2.0.14` to **`08462140ec0de1e4b17d4a353d8d5827f53cf7b0`**. Source inspected at that exact commit, not `main`:

- [`packages/core/src/models-dev.ts`](https://github.com/anomalyco/opencode/blob/08462140ec0de1e4b17d4a353d8d5827f53cf7b0/packages/core/src/models-dev.ts): normalization preserves model IDs; defaults status to active; source is `https://models.opencode.ai`; loads explicit file, then cache, then bundled snapshot; refreshes the public `/api.json` in the background.
- [`packages/core/src/plugin/models-dev.ts`](https://github.com/anomalyco/opencode/blob/08462140ec0de1e4b17d4a353d8d5827f53cf7b0/packages/core/src/plugin/models-dev.ts): `snapshots()` excludes `model.status === "deprecated"` before registering provider models.
- [`packages/core/src/config/plugin/provider.ts`](https://github.com/anomalyco/opencode/blob/08462140ec0de1e4b17d4a353d8d5827f53cf7b0/packages/core/src/config/plugin/provider.ts): explicit `providers.*.models` definitions create/recreate models; late model overrides can re-enable a model. A bare agent selector is not a model declaration.
- [`packages/core/src/plugin/provider/nvidia.ts`](https://github.com/anomalyco/opencode/blob/08462140ec0de1e4b17d4a353d8d5827f53cf7b0/packages/core/src/plugin/provider/nvidia.ts): adds request-origin headers, not shortened Nemotron aliases.
- [`packages/core/src/plugin/provider/opencode.ts`](https://github.com/anomalyco/opencode/blob/08462140ec0de1e4b17d4a353d8d5827f53cf7b0/packages/core/src/plugin/provider/opencode.ts): an authenticated Console config can add/override model entries. No account config was accessed; no speculative account-only rescue counts as verification.

Public npm `@opencode/sdk@2.0.14` is a small host wrapper, not itself the embedded model JSON. Its package manifest depends on `@opencode/core@2.0.14`, which contains the snapshot in `package/dist/chunks/model-resolver-bktrs35w.js` as `snapshot_default`. Both package archives were inspected in memory, without installation or execution.

| Exact public artifact | Evidence |
|---|---|
| `https://registry.npmjs.org/@opencode/sdk/-/sdk-2.0.14.tgz` | SHA-256 `2d0d75d10c515f65b21e029baef7f4ec8aee9eb2c70ae90418a16285227a9945`; 44 files; exact dependency manifest inspected |
| `https://registry.npmjs.org/@opencode/core/-/core-2.0.14.tgz` | SHA-256 `81ca7948d414477aeb6facb8c57d973b9a1dbc93deba8341884920c1c3b5718d`; embedded catalog and normalization/filter implementation inspected |
| `https://registry.npmjs.org/@opencode/server/-/server-2.0.14.tgz` | SHA-256 `b3363d6d96859e192bc23d9af8e5244fd72ca6cb74dd754f9a8de549b0302298`; inspected for additional static catalog files |
| Decoded bundled snapshot / exact-tag `packages/core/src/models-dev/snapshot.txt` | Both byte-identical: 4,801,665 bytes, SHA-256 `48aec259f7d81fbe291957f53a472193eea4c1d562d5a34a5a74e1665cedca3e` |
| Exact-tag `packages/core/src/models-dev.ts` | 16,889 bytes, SHA-256 `808470db329b3f6b036de23b6d5a320993e78638a4d3b198ed64cb20a58b953e` |
| Nix-pinned Linux native CLI | `/nix/store/08ckbjx2q0viv1d7pzvjnz61l9idpr6q-opencode-v2-2.0.14/bin/.opencode2-unwrapped`; 200,828,384 bytes; SHA-256 `c6e4cd4a60aa9ac286f541f95dce0973a2c283362f4a991f99e88167de8f6bf7` |
| Nix-pinned plugin dependency closure | `/nix/store/dals03h3rvllh7m6h6iknpmywim66lki-opencode-npm-packages-v2-2.0.14`; versions manifest has client/plugin/ai/schema/protocol/util 2.0.14, not an installed embedded SDK |

CLI package source is the hash-pinned `@opencode/cli-linux-x64@2.0.14` tarball in `pkgs/opencode-v2/default.nix`; native Darwin uses its separately hash-pinned platform tarball. Direct byte search did not expose a contiguous copy of the decoded core snapshot in the compiled Linux executable. Therefore this report does **not** claim extraction or execution of the CLI's compiled catalog. The package/tag-backed native implementation plus its public refresh endpoint are the catalog-contract evidence; installed fleet caches and account-dependent availability remain unobserved.

The bundled snapshot lacks seven newest built-in selectors used by this candidate: native Opus/Sonnet 5.5, Copilot Opus/Sonnet 5.5 and GPT-6.1 Sol, native GPT-6 Luna and GPT-6.1 Sol. This is **not** evidence that those current models are invalid: the shipping implementation supports public catalog refresh and the current response includes them. Offline-only bundled zero-missing cannot be certified.

Both authoritative public endpoints were fetched without supplied authorization, cookies, or credential headers. Initial Python urllib requests returned 403; webfetch encountered its 5 MiB response limit, not a missing endpoint. Code Mode public fetch and `curl -q` succeeded. No native provider API was needed.

| Public response | Observation UTC | Bytes | Raw response SHA-256 |
|---|---|---:|---|
| `https://models.opencode.ai/api.json` | `2026-10-09T16:05:17.898345+00:00` | 5,374,722 | `290958df5b714bad80c56465f07ea5a26241f4d0a2e0124b6d8863e93122cbfa` |
| `https://models.dev/api.json` | `2026-10-09T16:05:18.899107+00:00` | 5,374,722 | `290958df5b714bad80c56465f07ea5a26241f4d0a2e0124b6d8863e93122cbfa` |

Both responses contained 225 providers and were byte-identical for these observations. An earlier response had a different hash/one-byte length; catalog responses are mutable, so the table pins the actual comparison responses rather than asserting a permanent content hash. Raw bodies were processed in memory; hashes and extracted findings are retained here, not a new repository fixture. Every found inventory entry advertises `tool_call: true`; this is metadata, not a live tool-call/reliability test.

## Unique selector results

“Found” means current raw public key exists, is nondeprecated, and survives the pinned catalog filter, conditional on provider access/policy. “Runtime-added verified” means the repository declares the exact model-map key and pinned configuration code creates it; it does not certify remote service availability. NVIDIA is treated as the explicitly allowed repository-defined provider, not required to pass built-in-only membership.

| Selector | Current raw status | Candidate resolution result |
|---|---|---|
| `anthropic/claude-opus-5-5` | active | Found; bundled snapshot absent |
| `anthropic/claude-sonnet-5-5` | active | Found; bundled snapshot absent |
| `github-copilot/claude-opus-5.5` | active | Found; bundled snapshot absent |
| `github-copilot/claude-sonnet-4.6` | active | Found |
| `github-copilot/claude-sonnet-5.5` | active | Found; bundled snapshot absent |
| `github-copilot/gpt-5.3-codex` | active | Found |
| `github-copilot/gpt-5.4` | active | Found |
| `github-copilot/gpt-5.4-mini` | active | Found |
| `github-copilot/gpt-5.5` | active | Found |
| `github-copilot/gpt-5.6-luna` | active | Found |
| `github-copilot/gpt-5.6-sol` | active | Found |
| `github-copilot/gpt-6-astra` | active | Found |
| `github-copilot/gpt-6.1-sol` | active | Found; bundled snapshot absent |
| `openai/gpt-5.6-luna` | active | Found |
| `openai/gpt-5.6-sol` | active | Found |
| `openai/gpt-6-luna` | active | Found; bundled snapshot absent |
| `openai/gpt-6.1-sol` | active | Found; bundled snapshot absent |
| `opencode-go/deepseek-v4-flash` | active | Found |
| `opencode-go/deepseek-v4-pro` | active | Found |
| `opencode-go/glm-5.3` | active | Found |
| `opencode-go/glm-5.3-flash` | active | Found |
| `opencode-go/kimi-k3` | active | Found |
| `opencode-go/minimax-m3` | active | Found |
| `opencode/nemotron-3-ultra-free` | active | Found |
| `opencode/mimo-v2.5-free` | deprecated, including bundled snapshot | **Missing from native loaded catalog**; no repository declaration restores it |
| `nvidia/minimaxai/minimax-m3` | deprecated in current public catalog; active in bundled snapshot | **Runtime-added verified** through explicit NVIDIA declaration; vendor availability unverified |
| `nvidia/nvidia/nemotron-3-ultra-550b-a55b` | active | Exact custom declaration verified; also public key found |
| `nvidia/nemotron-3-ultra-550b-a55b` | absent in current and bundled catalog | **Missing**; custom map has no `nemotron-3-ultra-550b-a55b` key |

The NVIDIA declaration remains in generated native V2 configuration at runtime-config lines 169–175: package `@opencode/ai/providers/openai-compatible`, `env = ["NVIDIA_API_KEY"]`, endpoint `https://integrate.api.nvidia.com/v1`, and 12 explicit model-map keys. Only the literal environment substitution was read; no secret values were accessed. `models` includes `minimaxai/minimax-m3` and `nvidia/nemotron-3-ultra-550b-a55b`, not the shortened Nemotron key. The first slash separates provider from model; the second `nvidia/` in the valid selector is part of the actual model ID, not accidental duplication.

The complete custom declaration's model keys are `z-ai/glm-5.1`, `minimaxai/minimax-m3`, `minimaxai/minimax-m2.7`, `deepseek-ai/deepseek-v4-flash`, `deepseek-ai/deepseek-v4-pro`, `nvidia/nemotron-3-ultra-550b-a55b`, `stepfun-ai/step-3.7-flash`, `mistralai/mistral-medium-3.5-128b`, `google/gemma-4-31b-it`, `qwen/qwen3.5-397b-a17b`, `openai/gpt-oss-120b`, and `moonshotai/kimi-k2.6`. Unrouted declaration entries are recorded for completeness, not expanded into new routing/capability certification.

## Complete exported profile inventory

Every cell lists the unique selectors actually used by that profile after approved ODD transformation. The selector table above supplies each ID's exact found/missing/runtime-added result. Profiles with absent review/fixer fields preserve those absences; inherited runtime model selection is not invented as a declared route.

| Profile | Full unique selector inventory |
|---|---|
| openai-anthropic-go | `anthropic/claude-opus-5-5`, `openai/gpt-6.1-sol` |
| openai-anthropic-light | `anthropic/claude-opus-5-5`, `openai/gpt-6-luna`, `openai/gpt-6.1-sol` |
| openai-anthropic-medium | `anthropic/claude-opus-5-5`, `openai/gpt-6.1-sol` |
| openai-anthropic-full | `anthropic/claude-opus-5-5`, `openai/gpt-6.1-sol` |
| opencode-free | `opencode/mimo-v2.5-free`, `opencode/nemotron-3-ultra-free` |
| anthropic-opencode-free | `anthropic/claude-opus-5-5`, `anthropic/claude-sonnet-5-5`, `opencode-go/glm-5.3-flash`, `opencode/mimo-v2.5-free`, `opencode/nemotron-3-ultra-free` |
| work-copilot-anthropic | `anthropic/claude-sonnet-5-5`, `github-copilot/claude-sonnet-5.5`, `github-copilot/gpt-5.6-luna`, `github-copilot/gpt-6.1-sol` |
| work-copilot-anthropic-light | `anthropic/claude-sonnet-5-5`, `github-copilot/claude-sonnet-5.5`, `github-copilot/gpt-6.1-sol` |
| anthropic-light | `anthropic/claude-opus-5-5`, `anthropic/claude-sonnet-5-5` |
| anthropic-medium | `anthropic/claude-opus-5-5`, `anthropic/claude-sonnet-5-5` |
| anthropic-full | `anthropic/claude-opus-5-5`, `anthropic/claude-sonnet-5-5` |
| reliable | `anthropic/claude-opus-5-5`, `anthropic/claude-sonnet-5-5` |
| opencode-high | `opencode-go/deepseek-v4-flash`, `opencode-go/deepseek-v4-pro`, `opencode-go/glm-5.3-flash`, `opencode-go/kimi-k3` |
| quality | `anthropic/claude-opus-5-5` |
| cross-provider-review | `anthropic/claude-opus-5-5`, `anthropic/claude-sonnet-5-5`, `opencode-go/deepseek-v4-pro`, `opencode-go/glm-5.3-flash` |
| openai-opencode | `openai/gpt-5.6-luna`, `openai/gpt-6.1-sol`, `opencode-go/deepseek-v4-flash`, `opencode-go/deepseek-v4-pro` |
| openai-opencode-heavy | `openai/gpt-6.1-sol`, `opencode-go/deepseek-v4-pro`, `opencode-go/glm-5.3-flash` |
| openai-opencode-balanced | `openai/gpt-6-luna`, `openai/gpt-6.1-sol`, `opencode-go/deepseek-v4-pro` |
| opencode-go-openai | `openai/gpt-5.6-luna`, `openai/gpt-6.1-sol`, `opencode-go/kimi-k3` |
| anthropic-opencode-go | `anthropic/claude-opus-5-5`, `opencode-go/deepseek-v4-pro`, `opencode/mimo-v2.5-free`, `opencode/nemotron-3-ultra-free` |
| openai-full | `openai/gpt-5.6-luna`, `openai/gpt-5.6-sol`, `openai/gpt-6.1-sol` |
| openai-medium | `openai/gpt-5.6-luna`, `openai/gpt-6.1-sol` |
| openai-light | `openai/gpt-5.6-luna`, `openai/gpt-6.1-sol` |
| github-copilot-light | `github-copilot/claude-sonnet-5.5`, `github-copilot/gpt-5.3-codex`, `github-copilot/gpt-5.4-mini` |
| github-copilot-medium | `github-copilot/claude-sonnet-5.5`, `github-copilot/gpt-5.3-codex`, `github-copilot/gpt-6.1-sol` |
| github-copilot-full | `github-copilot/claude-opus-5.5`, `github-copilot/gpt-5.3-codex`, `github-copilot/gpt-6-astra` |
| copilot-custom | `anthropic/claude-sonnet-5-5`, `github-copilot/claude-sonnet-5.5`, `github-copilot/gpt-5.6-luna`, `github-copilot/gpt-6.1-sol` |
| nvidia | `nvidia/minimaxai/minimax-m3`, `nvidia/nemotron-3-ultra-550b-a55b`, `nvidia/nvidia/nemotron-3-ultra-550b-a55b`, `opencode-go/minimax-m3` |
| github-copilot | `github-copilot/claude-sonnet-4.6`, `github-copilot/gpt-5.3-codex`, `github-copilot/gpt-5.4` |
| github-copilot-safe | `github-copilot/claude-sonnet-5.5`, `github-copilot/gpt-5.3-codex`, `github-copilot/gpt-5.5` |
| github-copilot-pro | `github-copilot/claude-sonnet-5.5`, `github-copilot/gpt-5.3-codex`, `github-copilot/gpt-5.4` |
| github-copilot-experimental | `github-copilot/gpt-5.6-sol` |
| opencode-go-full | `opencode-go/deepseek-v4-pro`, `opencode-go/glm-5.3` |
| opencode-go-medium | `opencode-go/deepseek-v4-flash`, `opencode-go/deepseek-v4-pro`, `opencode-go/minimax-m3` |
| opencode-go-light | `opencode-go/deepseek-v4-flash`, `opencode-go/deepseek-v4-pro` |

## All four hosts: effective declarative selection

Read-only Nix evaluation of integrated and standalone host profile names and per-agent model overrides succeeded for **all eight targets with IFD disabled**. Every override map is `{}`. Thus user override precedence is preserved (`lib.recursiveUpdate defaultAgents agentOverrides`), but no declared host override repairs either blocker. Mutable user/project documents, session overrides, external model transforms, and account-discovered inventories were not read and are not represented as certified live-effective state.

| Host | Integrated and standalone profile | Model overrides | Evidence level |
|---|---|---|---|
| rog | `openai-medium` | `{}` | Direct host option evaluation; full standalone agent-model projection evaluated |
| thinkcentre | `openai-anthropic-go` | `{}` | Direct host option evaluation; full standalone agent-model projection evaluated |
| t14 | `openai-anthropic-go` | `{}` | Direct host option evaluation; full standalone agent-model projection evaluated |
| macm5 | `openai-anthropic-go` | `{}` | Direct integrated/standalone option evaluation without Darwin IFD; shared model-only projection, not new native agent-output evaluation |

| Agent | rog | thinkcentre / t14 / macm5 shared projection |
|---|---|---|
| gentle-orchestrator | `openai/gpt-6.1-sol` | `anthropic/claude-opus-5-5` |
| gentle-ai-explore | `openai/gpt-6.1-sol` | `openai/gpt-6.1-sol` |
| gentle-ai-worker | `openai/gpt-5.6-luna` | `openai/gpt-6.1-sol` |
| gentle-ai-verify | `openai/gpt-6.1-sol` | `anthropic/claude-opus-5-5` |
| jd-fix-agent | `openai/gpt-5.6-luna` | `openai/gpt-6.1-sol` |
| jd-judge-a | `openai/gpt-6.1-sol` | `anthropic/claude-opus-5-5` |
| jd-judge-b | `openai/gpt-6.1-sol` | `openai/gpt-6.1-sol` |
| review-readability | `openai/gpt-6.1-sol` | `openai/gpt-6.1-sol` |
| review-refuter | `openai/gpt-6.1-sol` | `anthropic/claude-opus-5-5` |
| review-reliability | `openai/gpt-6.1-sol` | `openai/gpt-6.1-sol` |
| review-resilience | `openai/gpt-6.1-sol` | `openai/gpt-6.1-sol` |
| review-risk | `openai/gpt-6.1-sol` | `anthropic/claude-opus-5-5` |
| review-validator | `openai/gpt-5.6-luna` | `openai/gpt-6.1-sol` |
| neutral | `openai/gpt-6.1-sol` | `anthropic/claude-opus-5-5` |

`general` and `managed-writing-task` have no explicit model; their runtime inheritance is not a new catalog selector. All explicit active-host model IDs are nondeprecated current catalog entries. This narrower active-host result does not waive S8's **all-profile** condition. The `openai-anthropic-go` candidate no longer contains a Go selector because its Go init/tasks/archive assignments were removed with the retired SDD roles; the surviving actual inventory, not the profile name, determines the result.

The initial all-model projection with `allow-import-from-derivation = false` correctly refused the Gentle assets IFD, so it was not treated as a model/config error. A Linux-only projection with ordinary IFD enabled then reused already-built `/nix/store/ia2an10mnvws4f2sksxlh1xfl7wkvs9a-gentle-ai-assets-4.0.0` and returned the three Linux agent maps above without scheduling a build. No Darwin agent/JSON projection was forced; prior native Mac build evidence belongs to `native-mac-check.md` and is not relabeled as a new catalog/runtime check.

## P1 stop conditions and minimum next step

| Stopper | Exact affected routes | Responsible boundary |
|---|---|---|
| Deprecated MiMo selector has no declared native restoration | `opencode-free`: gentle-ai-worker, jd-fix-agent; `anthropic-opencode-free`: gentle-ai-worker, jd-fix-agent; `anthropic-opencode-go`: gentle-ai-worker | providers-base lines 202/212, 249/260, 684; exact pinned loader removes the entry |
| Shortened NVIDIA Nemotron selector is neither catalog nor declared alias | `nvidia`: jd-judge-a, jd-judge-b, review-readability, review-refuter, review-reliability, review-resilience, review-risk, review-validator | providers-base lines 906–914; declaration at lines 40–42 uses the full `nvidia/nemotron-3-ultra-550b-a55b` model key |

S7's catalog subgate and S8's zero-usable-missing condition are **FAIL/STOPPER** for the declared full inventory, not merely unavailable evidence. There are zero absent *raw* non-NVIDIA keys, one native-filtered built-in key, and one unresolved custom selector. Other S7 evaluation/build results are outside this report's ownership. Any hidden authenticated Console/plugin/user override that could add the removed key is **unverified**, not assumed absent in a user's live session and not accepted as declarative proof.

Return these findings to the parent for an explicit routing/alias decision. Correcting the shortened NVIDIA model key can preserve the intended upstream model, but still requires an approved targeted routing/alias edit and preservation proof. MiMo requires an operator-selected supported replacement or explicit justified declaration; merely adding a UI-visible fallback alias would not prove genuine service availability. No model selection was proposed or applied here. An SDK/CLI upgrade is **not** an established remedy: current 2.0.14 already refreshes the newest public catalog and deliberately filters deprecated entries. Do not bump versions or silently swap routing to manufacture a pass.

## Reproduction without native services or accounts

The successful inventory command was:

```sh
nix eval --impure --offline --json --expr '
  let
    lib = import /nix/store/5b2ic4sxjc2lzgxk4hninyw22r5gv5qr-source/lib;
    p = import ./shared/opencode/providers-base.nix { inherit lib; };
  in { inherit (p) providers nvidiaProvider providerAllowlist; }
'
```

The exact public response was read with `curl -q --fail --silent --show-error --max-time 45 URL` and hashed over `stdout` bytes using Python `hashlib.sha256`. No curl configuration or custom authentication headers were supplied. Selectors were deduplicated from evaluated `providers[*].phases`, split once at `/`, checked against each provider's exact `models` map, and checked for `status == "deprecated"`; NVIDIA selectors were additionally checked against `nvidiaProvider.nvidia.models`.

All-host profile/override projections used `nix eval --impure --offline --no-write-lock-file --option allow-import-from-derivation false --json --expr` with `builtins.getFlake (toString ./.)`, mapping `homeConfigurations.<host>.config`, Linux `nixosConfigurations.<host>.config.home-manager.users.glats`, and Darwin `darwinConfigurations.macm5.config.home-manager.users.juan` to only `{ profile = c.home.opencode.activeProviderName; overrides = lib.mapAttrs (_: a: a.model or null) c.home.opencode.agentOverrides; }`. Linux-only full agent maps used `lib.mapAttrs (_: a: a.model or null) c.home.opencode.agents` with ordinary IFD enabled and existing assets. No native OpenCode commands were run.

## Read-only repair plan follow-up — 2026-10-09

The parent requested a repair **plan**, not product edits, while parallel Linux builds still use the original reviewed fingerprint. Both provider source hashes above were rechecked and remained unchanged. Only this owned report was appended. The plan below is not an applied fix, a new reviewed fingerprint, or an implicit model-selection decision.

### NVIDIA: verified alias, no profile or backend-model change

The minimal supported repair is one additional model record in the existing NVIDIA custom declaration, projected through the existing native V2 `providers.nvidia.models` map:

```json
{
  "nemotron-3-ultra-550b-a55b": {
    "name": "Nemotron 3 Ultra",
    "modelID": "nvidia/nemotron-3-ultra-550b-a55b"
  }
}
```

This is the native V2 **`modelID`** field, not legacy `id`. Keep the existing full model-map key and all 35 profiles unchanged. Eight currently broken short selectors then select the alias; the alias sends the exact same intended NIM backend identifier as the already-working full selector. Endpoint, native runtime package, policy, credentials, and all unrelated provider records stay unchanged. It is not a different model or a fallback. Adding this single record under `nvidiaProvider.nvidia.models` is sufficient because runtime-config already inherits that map; no new policy engine/integration is needed.

Context7 was queried again for native model aliases and variants; official V2 docs expressly say the `models` map key is the selectable ID and `modelID` is the ID sent to the provider. Exact 2.0.14 source confirms the complete path:

| Pinned source at `08462140ec0de1e4b17d4a353d8d5827f53cf7b0` | Exact behavior |
|---|---|
| `packages/schema/src/config/provider.ts:68–69` | `class Model ... { modelID: ID.pipe(optional), ... }` accepts the field |
| `packages/schema/src/model.ts:26–32` | `const providerEnd = input.indexOf("/")`; model ID is the remainder through an optional `#` variant, preserving additional slashes |
| `packages/core/src/config/plugin/provider.ts` | Alias base is found with `source?.models.get(config.modelID ?? id)`; copied metadata preserves the existing backend model's capabilities/limits/cost; `if (config.modelID !== undefined) model.modelID = config.modelID` |
| `packages/core/src/provider.ts:334–344` and `packages/core/src/model.ts:127–138` | After applying the copied model/override, editors restore `model.id = modelID` and `model.providerID = providerID`, then store under that selectable key; backend `model.modelID` remains distinct. Copying full-model metadata therefore does not erase the alias identity |
| `packages/core/src/model-resolver.ts:232` | `const runtime = module.model(resolved.modelID ?? resolved.id, settings)` |
| `packages/ai/src/providers/openai-compatible.ts:37–38,48–59` | Native provider builds `route.model({ id: modelID, ... })` and forwards the passed model ID |
| `packages/ai/src/protocols/openai-compatible-chat.ts` | Reuses `OpenAIChat.protocol` at `/chat/completions` |
| `packages/ai/src/protocols/openai-chat.ts:760–762` | Native body lowering returns `model: request.model.id` |

Relevant additional exact-source SHA-256 hashes: config/provider `76597aecddfc378f2ecee2db7efd93d17c494b939e218a4e134697929eea2efe`; schema/model `a90c419508aa0d81b5e992508052c49fe9cd2714aca9303bfdc4f71435aabfe7`; core/model-resolver `da0228d0ddad811861c787959215712eb5bb80085c1a3daee7de848c1891bda2`; native compatible provider `035d2a12f88d83f99fc9f48e57c4dc686d4309b70fef58cb957b7c73b8e1e61f`; chat protocol `6a8f457cbe5115298549ae03f8d671d7acfc015a0c30fd1db575bd352837ef5b`.

An empirical **pure synthetic** check imported only the shipping store packages' `effect/Schema`, native ConfigProvider schema, Model.Ref parser, and compatible provider's pure `model()` constructor. It decoded a credential-neutral alias definition and constructed a route object; it did not instantiate Core/SDK, lower/send an HTTP request, read auth/config state, start a service, or contact the endpoint. Actual result:

```json
{"schemaAccepted":true,"selector":{"id":"nemotron-3-ultra-550b-a55b","providerID":"nvidia"},"routeModelID":"nvidia/nemotron-3-ultra-550b-a55b","endpoint":"https://integrate.api.nvidia.com/v1","route":"openai-compatible-chat"}
{"fullSelector":{"id":"nvidia/nemotron-3-ultra-550b-a55b","providerID":"nvidia"}}
```

This verifies schema acceptance, exact first-slash parsing, and alias-to-native-route ID. The final wire-body field is established by the quoted pinned lowering source, not by a model request. Backend service behavior remains untested. Rewriting eight profile selectors is unnecessary with this verified alias; the preservation test should allow exactly one provider model-record addition and require **zero NVIDIA profile mapping changes**.

### MiMo: current free shortlist, explicit decision still required

The public default endpoint was rechecked for the requested current candidate shortlist at `2026-10-09T16:15:48.278617+00:00`. It returned the same 5,374,722-byte body and SHA-256 `290958df5b714bad80c56465f07ea5a26241f4d0a2e0124b6d8863e93122cbfa` as the earlier comparison. There are **11** nondeprecated `opencode` entries with explicit zero input/output prices and `tool_call = true`. The three scoped candidates below all remain within the existing `opencode` provider, with no Go/paid fallback or credential change.

| Candidate selectable ID | Catalog status and price per million tokens | Tool / structured-output metadata | Limits and current role-relevant evidence | Recommendation scope |
|---|---|---|---|---|
| `opencode/nemotron-3.5-lightning-free` | active/default; input $0, output $0, cache-read $0 | tools true; structured_output true | context 262,144; output 262,144; text input/output; reasoning_options `[]`; catalog describes fast agentic enterprise tasks; released/updated 2026-08-11 | **Preferred bounded-worker/fixer candidate**: current free, explicitly structured, capable metadata, already used for mechanical roles in the source profile history. Requires explicit operator approval and acceptance of source-backed—not runtime-certified—assessment |
| `opencode/mimo-v2.6-flash-free` | active/default; input $0, output $0, cache-read $0 | tools true; structured_output **not advertised** | context 200,000; output 32,000; text/image/audio/video input; reasoning_content interleaving; reasoning_options `[]`; released/updated 2026-09-22; closest family/limits/modality replacement for retired MiMo | Closest metadata migration, **not preferred** after fresh open tool-call evidence; do not silently promote it |
| `opencode/nemotron-3-ultra-free` | active/default; input $0, output $0, cache-read $0 | tools true; structured_output **not advertised** | context 1,000,000; output 128,000; text input/output; reasoning_content interleaving; reasoning_options `[]`; released/updated 2026-06-04; already serves these profiles' orchestration/judgment roles | Existing-inventory alternative, but less role separation and no newly proven speed/reliability advantage |

No catalog `structured_output` field was invented where absent. All three use the existing native-compatible catalog route unless a catalog package override says otherwise; none of these three advertises a model-level package override. Prices are catalog metadata, not proof of geographic eligibility, quota, or successful service access. No fabricated uptime/benchmark or live fit certification is asserted.

Fresh public, unauthenticated GitHub issue searches temper the shortlist. These are scoped risk evidence, not a reproduction against this fleet:

- [#53499](https://github.com/anomalyco/opencode/issues/53499), open, updated 2026-10-06: malformed empty tool IDs on `mimo-v2.6-flash-free` persist and poison sessions. Reporter uses **V1 1.18.25**; exact V2 impact is unverified, so do not incorrectly claim a reproduced 2.0.14 defect, but this is enough to withhold a clean model-fit/tool-call approval for the same-family candidate.
- [#51949](https://github.com/anomalyco/opencode/issues/51949), open: V2 2.0.18 MiMo free session stops direct tool use after compaction; a one-session observation, not established provider-wide failure. [#53150](https://github.com/anomalyco/opencode/issues/53150), open: V2 2.0.22 MiMo free long session produces off-topic repetition. Both counsel against calling a catalog-only replacement “reliable.”
- [#50627](https://github.com/anomalyco/opencode/issues/50627), open, updated 2026-10-08: V2 2.0.13 custom-agent shell denial triggers free-tier origin rejection; [#49723](https://github.com/anomalyco/opencode/issues/49723), open: V2 2.0.7 `explore` subagent path rejects free models while `general` succeeds. These are broader free-tier/permission-route risks; swapping free models does not prove their resolution. **Do not relax permissions or add paid fallback** to bypass them. The requested worker/fixer roles are writable executor roles, not a new read-only exploration routing change.
- [#49013](https://github.com/anomalyco/opencode/issues/49013), open, discusses free models with empty reasoning_options and no thinking variants. None of the 35 evaluated candidate routes has a `#variant`, and the three shortlist models also have `reasoning_options = []`. Preserve the bare selector; do not add `#max` or synthetic reasoning variants. [#50451](https://github.com/anomalyco/opencode/issues/50451) separately reports variant rejection for `#max` on MiMo free before an older beta free-tier version-gate failure; it is not proof that release 2.0.14 is that beta.
- [#54144](https://github.com/anomalyco/opencode/issues/54144), open, created 2026-10-09, names Ultra Free errors but supplies only an image; without decoded mechanism/version it is an unverified report, not a justified block classification or a reason to fabricate reliability data.

The recommendation is therefore **Lightning for an explicitly approved free-only catalog repair**, not a claim that all model-fit/runtime-readiness gates are now proven. MiMo Flash 2.6 is not approved by the hard tool-call evidence gate merely because its metadata closely matches 2.5. If the parent requires complete provider stability certification before any assignment, that stricter acceptance remains pending; choose whether to retain the profiles blocked/disabled rather than invent a paid escape hatch.

### Exact planned delta and preservation proof

Only after the parent approves a free replacement, change these **five effective model assignments across three profiles** from `opencode/mimo-v2.5-free` to that one approved free ID:

| Profile | Effective field | Source field before existing ODD transformation |
|---|---|---|
| opencode-free | gentle-ai-worker | sdd-apply |
| opencode-free | jd-fix-agent | jd-fix-agent |
| anthropic-opencode-free | gentle-ai-worker | sdd-apply |
| anthropic-opencode-free | jd-fix-agent | jd-fix-agent |
| anthropic-opencode-go | gentle-ai-worker | sdd-apply |

Leave the three retired `sdd-onboard` source occurrences out of the effective-delta allowlist: they are removed by the candidate transformation and are not executable assignments. No active-host profile changes, no review/judgment MiMo swap, no new variants, no profile deletion, no account or provider change, and no incidental metadata cleanup are part of this plan.

Parent-owned specs/tests must explicitly record this newly approved **deprecated-route repair exception** in addition to the earlier ODD role-mapping exception; the current full-JSON equivalence requirement does not silently authorize model replacements. Compare all 35 complete exported profile JSON objects against the reviewed candidate/baseline: only the five listed model fields may differ; all other fields and arrays must match. Separately compare the custom NVIDIA declaration: only the one new alias record is permitted. Test the alias with the actual native schema/parser and assert `modelID` equals the existing full NIM API model ID; do not merely test that its name appears in a UI list. Re-run deprecation-aware current catalog resolution and exact custom-map lookup for all unique surviving selectors, including model variants if any are later introduced.

Adding the alias changes a provider declaration; selecting a free replacement changes the declarative profile inventory. Both invalidate the old **catalog/config/full-source fingerprint** and require a new reviewed identity before subsequent gates. They do **not** change Gentle AI binary source/tag/vendorHash, CLI/SDK packages, or compiler semantics, so the old native binary build is not retroactively false. Nevertheless Home Manager/generated configuration/assets and containing system/activation derivations change—especially the always-emitted NVIDIA map—so rerun the relevant native platform configuration/evaluation/build gates after the parent applies and reviews the repair. Do not label old full-system outputs as proof of the new candidate. Wait for the parallel old-source Linux result; do not edit its inputs mid-build or mutate this report's initial reviewed-source hashes.

## Mandatory model-fit evidence recheck — 2026-10-09, 16:37 UTC

**Result: STOP on the five Lightning replacements under the unwaived two-gate policy.** The operator approved Lightning and the same-backend NVIDIA alias (parent observation #3976), but approval of the model choice is not a waiver of the evidence gates. No product edits were performed. The previously preferred Lightning recommendation was a shortlist, not a completed fit approval; the checks below do not certify it Active or runtime-ready. The alias remains independently supported and introduces no different upstream model.

Read the complete current `model-fit/SKILL.md` (version 4.1), including Gate 1's open-issue exclusion and Gate 2's Active requirement of uptime >=90% with no open blocking issues. This is a narrow retirement repair covering only the five already-listed worker/fixer assignments, not an audit or rewrite of unrelated routing. Used GitHub personal MCP `get_me` before targeted issue searches/reads, Context7 provider docs, Exa public evidence, and pinned source. No live model tests, provider calls, credentials, account initialization, or upgrades were performed.

### Gate 1: exact scope of open origin/permission failures

Both previously cited issues are still **open**, not fixed/closed historical annotations:

| Evidence | Fresh content and version | Applicability to chosen model and five proposed roles |
|---|---|---|
| [#49723](https://github.com/anomalyco/opencode/issues/49723), updated 2026-10-03T20:45:27Z | Original V2 **2.0.7** report explicitly lists **`opencode/nemotron-3.5-lightning-free`** among eight failing `explore` invocations. Control successes for `general` list other models, so do not fabricate a Lightning `general` success. [Independent comment](https://github.com/anomalyco/opencode/issues/49723#issuecomment-5730786349) reproduces on official macOS 2.0.7 with MiMo and isolates shell permission/toolset. [Exact pinned-version comment](https://github.com/anomalyco/opencode/issues/49723#issuecomment-5781342883) says “Still broken in v2.0.14, with `opencode/mimo-v2.6-flash-free`.” | Confirmed Lightning failure exists on a **read-only exploration request**, and exact 2.0.14 persistence exists for **MiMo**, not a directly documented Lightning 2.0.14 reproduction. Cannot dismiss this as unrelated to Lightning or claim an upgrade fixed it; also cannot equate that restricted request with writable worker/fixer |
| [#50627](https://github.com/anomalyco/opencode/issues/50627), updated 2026-10-08T20:33:56Z | Original **2.0.13** custom primary agent shell-deny reproduction claims all free models. [Controlled Desktop retest](https://github.com/anomalyco/opencode/issues/50627#issuecomment-5947635786) confirms **2.0.22** shell-deny failures for MiMo/Spark (plugins present; not reproduced disabled). [Latest comment](https://github.com/anomalyco/opencode/issues/50627#issuecomment-6068541885) reports **2.0.19** Gentle review/explore child-session failures with **Big Pickle** and inline deny permissions | Provider/request-shape defect, not confirmed model-generated tool truncation. Lightning not explicitly reproduced in those comments. **2.0.19 here is a reported CLI/service version, not evidence that SDK 2.0.19 fixes SDK 2.0.14**. Permission weakening is not an acceptable remedy |
| [#51315](https://github.com/anomalyco/opencode/issues/51315), open | V1 **1.18.29/1.18.32** disabling native `read` produces 403; controlled affected-model list includes Lightning | Additional confirmed Lightning free-route restriction, but V1 request/tool mapping is not proof of exact V2 worker failure |

Direct offline Nix evaluation of the current shared worker/fixer definitions returned identical permission maps: `bash/read/edit/write = allow`, `task = deny`, with memory tools allowed. `shared/opencode/v2-permissions.nix` maps `bash` to native `shell`, `task` to `subagent`, and `write` to `edit`. Global shell rules contain `* = allow` plus specific deployment/destructive-command denies; global reads allow ordinary paths with secret/environment-file exclusions. Thus the proposed five executors are **not** the shell-* deny/read-disabled reproduction configuration. This is declarative policy proof, not an outgoing-tool-list capture; project/user/plugin/session overrides and future compaction shapes were not inspected or ruled out.

Pinned `packages/core/src/session/model-request.ts:238–250` constructs the same app/session client headers and serializes tools from the hooked definition collection; an optional parent-session header is added for child sessions. It does not prove what the proprietary Console classifier currently accepts. Current official [Console model docs](https://opencode.ai/v2/docs/console/models), fetched 2026-10-09T16:37:35Z, list `nemotron-3.5-lightning-free` on **Chat Completions** and explicitly explain that the table's `@ai-sdk/openai-compatible` package is for external callers. The previously inspected exact native 2.0.14 catalog loader resolves this family to `@opencode/ai/providers/openai-compatible`; its native route uses `/chat/completions`. No Responses-vs-Chat mismatch was found. Do not replace the native package with the legacy AI SDK string.

Targeted GitHub MCP searches covered the exact free ID plus Nemotron truncation, `finish_reason`, hang, and parallel terms. They did not establish a current Lightning-native-2.0.14 stream-ending/concurrent-tool defect. Other returned reports concern V1 Windows output corruption (#50458), Ollama/V1 malformed-call repair (#47831), local/custom provider websearch exposure (#44307), or NVIDIA Ultra rather than this route. They are not promoted to confirmed fleet blockers without matching scope.

**Gate 1 disposition:** the model has open, reproduced **permission-blocked free transport** evidence; under the user's unwaived exclusion of such models, Gate 1 cannot be signed PASS. Its five writable worker/fixer requests are **not themselves shown to fail** by the public reproductions. If the parent evaluates a route-scoped policy instead, that narrower assessment must retain the exact scope distinction above; generic approval of Lightning is not permission to silently narrow the rule.

### Gate 2: measured uptime missing for the selected Console route

Fetched official [Lightning data JSON](https://opencode.ai/data/nvidia/nemotron-3-5-lightning.json) successfully at **2026-10-09T16:37:09.317Z**; payload updatedAt was **2026-10-09T15:47:02.000Z**. Actual published values:

| Official field | Value | Interpretation |
|---|---|---|
| `model.id` | `nvidia/nemotron-3.5-lightning` | Model-family aggregation, **not an isolated `opencode/...-free` endpoint measurement** |
| `usage.rankLastWeek` | 14 | Usage rank, not reliability |
| `usage.tokens` / `usage.uniqueUsers` / `usage.sessions` | 4,538,572,656,742 / 282,788 / 6,213,238 | Existing usage evidence; no request-attempt/failure or availability denominator |
| `usage.weeklyRetentionPercent` | **null** | Weekly user retention not published; this is not a zero-retention score |
| `usage.cachedInputPercent` | 83.9 | Cache utilization, not uptime |
| uptime/success percentage | **Not present** | Cannot establish >=90% |
| SWE-Bench Verified / Terminal-Bench 2.1 | 51.56 / 24.58 | Vendor-reported BF16 reasoning scores, sourced to NVIDIA Hugging Face model card via NeMo Evaluator; not transport-completeness or availability tests |

Official family page prices ($0.05 input/$0.20 output per million) describe the aggregate/base model and must **not** override the explicit free-SKU $0/$0 catalog/docs prices. Official docs confirm Lightning Free is limited-time availability; they do not publish a service-uptime percentage. Context7 also supplies the general data privacy policy, but privacy retention and weekly user retention are different metrics; neither is provider availability. No retention-to-uptime conversion is valid.

External public reliability numbers were found, but their scope does **not** satisfy this route's gate:

- [SmophyAI Lightning reliability](https://www.smophy.ai/benchmark/reliability/nemotron-3.5-lightning) reports 100.0% for several providers and 99.9% for Io Net, explicitly a daily snapshot of **OpenRouter's trailing-30-minute endpoint data**. It does not identify this Console free SKU's backend routing or measure Console's origin/permission classifier.
- [modelstatus.dev NVIDIA dashboard](https://modelstatus.dev/providers/nvidia) shows Lightning free `nvidia/nvfp4` at **99.29% (5m), 97.83% (24h), 96.92% (7d), 94.41% (30d)**. It explicitly uses OpenRouter windows for latency/throughput and describes a **1.0M-context endpoint**, whereas the selected catalog model has 262,144 context. Endpoint/quantization/route identity is not established; do not import 94.41% into the Console route's status.
- [#45132](https://github.com/anomalyco/opencode/issues/45132), open, reports selective 403 including Lightning and Ultra with V1 1.18.4/API-key auth; its only comment is a duplicate-suggestion bot, not a resolution. [#50305](https://github.com/anomalyco/opencode/issues/50305), open, mentions country unavailability for Lightning. These are account/geography stability risks, not proof that the four declarative hosts' accounts are blocked. No account/location data was accessed.

**Gate 2 disposition: Unknown uptime, with open selective-access/request-shape risks; NOT Active.** Successful public statistics retrieval does not make the required statistic available. This is a genuine **evidence/readiness stopper**, not an invented measured model failure or a fabricated <90% result. Even a parent decision to scope Gate 1 only to writable executors cannot make Gate 2 pass from these data.

### Parent handoff and stop condition

Do not apply the five Lightning assignments under the current unwaived policy. The parent can seek authoritative same-route uptime/completeness evidence or ask for an **explicit policy exception acknowledging unknown Console uptime and the scoped open free-transport issues**; observation #3976's model approval alone is insufficient. No such exception is inferred here. Do not silently replace Lightning with Ultra: #49723 and selective-access evidence also name Ultra, and the same route-specific uptime gap remains. Neither alternative has passed both gates in this follow-up.

The approved NVIDIA alias is a separate same-backend selector repair, already schema/source verified; it need not be bundled with a blocked new free-model assignment. Its implementation must still wait for the outstanding old-source Linux build and undergo a new fingerprint/configuration-gate review. Product hashes rechecked in this follow-up remain exactly `189d7581403f75fe3d0c43f38b46742c4931c2d0a3eeb5aa26dc3e5e33e28429` for providers-base and `a5c835f23da33f62cd8272fa9c156c13bab3b6536af879aa97c65c4733fb153a` for runtime-config. No formatting/build verification for a new product candidate is claimed because none was edited.

## Approved retirement preview — decision #3979, 2026-10-09

**READY for parent-controlled apply after old-source Linux build completion; not applied.** The operator superseded the Lightning proposal with retirement of exactly `opencode-free`, `anthropic-opencode-free`, and `anthropic-opencode-go`, plus the independently approved same-backend NVIDIA alias. This makes no replacement assignment and grants no fit-policy exception. All unrelated routing stays unchanged.

External preparation directory:

```text
/home/glats/.local/opencode-v2/tmp/opencode/catalog-retirement-preview/3979-6chRUIOi
```

Loaded `nix-verify`, `model-fit`, and `migration` before preparing the scratch Nix candidate. Nix MCP verified `lib.lists.filter`/`builtins.filter`; the candidate itself uses no new NixOS/Home Manager options or dependencies. Native `modelID` semantics remain established by the exact shipping 2.0.14 schema/parser/constructor and pinned source from the prior alias proof. Added dated English source-citation comments only beside the alias and retirement boundary; no blanket uptime or model-fit claims.

| External artifact | Purpose |
|---|---|
| `providers-base.nix` | Exact source preview: three complete profile blocks removed, one NVIDIA model record added |
| `approved-routing-repair.patch` | Parent source patch targeting only `shared/opencode/providers-base.nix` |
| `proof.json`, `before.json`, `after.json`, `baseline-providers.nix` | Machine-readable exact inventory/full-object comparisons and original committed baseline |
| `public-catalog.json` | Unaudited public catalog bytes used for the deprecation-aware membership proof; not account state |
| `prepare.py` | Reproducible source-precondition, profile/order/baseline parity, host-selection and catalog assertions |
| `native-alias-proof.mjs`, `native-alias-proof.json` | Pure shipping-package schema/parser/native route construction; zero requests |
| `approved-regression-update.patch` | Parent patch for the actual `shared/opencode/v2-agents.test.py` approved exceptions |
| `v2-agents.preview.test.py`, `prepare-regression.py` | External copy of the actual regression, with ROOT explicitly set to the primary repository and only the providers import redirected to scratch |
| `regression-spec-runbook-plan.md` | Exact parent-only test/spec/runbook acceptance edits, preconditions, apply and rollback order |

### Source identity and apply guard

| Identity | SHA-256 |
|---|---|
| Original `shared/opencode/providers-base.nix`, required apply precondition | `189d7581403f75fe3d0c43f38b46742c4931c2d0a3eeb5aa26dc3e5e33e28429` |
| Preview `providers-base.nix`, formatter leaves unchanged | `9cad2ce32da1f7358c8fb8cc847b9cd796bdf0c4be9a55bbc5a1a74c5b6b682b` |
| `approved-routing-repair.patch` | `23e51be639e10db0c251d9f90fb1ad6749b7453d10a8b165b5f6b106f38efd7f` |
| Original repository `v2-agents.test.py`, required test apply precondition | `61fb1c907dd577e12d1d2ba354a3c08c52efad18b034fb2d13bef04123fb7460` |
| Proposed repository test after regression patch, excluding scratch-path plumbing | `899dece3a41f43c239d4fba6260d2deba16778cd5f6f7eff081f10c5e4c9f80a` |
| `approved-regression-update.patch` | `2f4b7c901d40793416dfd8a3384dc0f681d06b1958a5b4789ab3603f9df2f45d` |

All **31** owned entry hashes in `final-v4-fingerprint.json` were checked before preparation and again after tests/formatting, including the three absent deleted files. They still match original reviewed fingerprint `3229f4238f8a9071e4790e8db6f781c60f80aff29e86f2083f9f471d8f783ed3`. No owned product path, shared report, Git index, runtime state, or background build input was modified by this preparation. If the parent sees any different source/test/owned hash before applying, STOP and explicitly rebase the proposal rather than adapt a concurrent edit silently.

### Behavioral RED/GREEN and preservation results

**RED original**: the evaluated source has 35 profiles rather than the approved 32 and lacks the short NVIDIA alias. Against the same public catalog used for GREEN, original usable-missing selectors are exactly `opencode/mimo-v2.5-free` (native deprecated filter) and `nvidia/nemotron-3-ultra-550b-a55b` (no declared alias). This is an offline declarative regression result, not a failed CLI/model invocation.

**GREEN preview**: 32 profiles; names and order equal the original list minus exactly the three approved names. Every remaining complete profile JSON object is equal to the currently reviewed ODD source. A second comparison with committed baseline `4750736cd68f517a871ac7448639c94546472390` passes for all retained profiles after only the existing three ODD phase mappings and retired SDD-role removal. No retained selector/variant/default changes. Provider allowlist is equal; NVIDIA provider JSON differs only by:

```json
"nemotron-3-ultra-550b-a55b": {
  "name": "Nemotron 3 Ultra",
  "modelID": "nvidia/nemotron-3-ultra-550b-a55b"
}
```

The endpoint, API-key placeholder, headers, full canonical model entry, and every other provider field are unchanged. Short/full NVIDIA selectors both preserve backend identifier `nvidia/nemotron-3-ultra-550b-a55b`; there is no model substitution. Re-executed the actual shipping-package pure probe using the preview alias record: schema accepted, first-slash parsing correct, native route `openai-compatible-chat`, canonical route model ID and existing NIM baseURL preserved, **requestsSent = 0**. Final native `body.model` mapping remains proven by the exact pinned lowering source quoted earlier, not by sending a request.

The external projection of the **actual existing** `v2-agents.test.py` also passed graph, executor/reviewer permissions, rendered recovery guidance, remaining full-JSON baseline ODD parity, provider policy, alias-only NVIDIA delta and last-wins overrides. Its path adaptations are confined to the external runnable copy and are **not** part of the parent regression patch. Existing limitations remain: rendered prompt-contract presence does not prove an LLM performs readback/outage/conflict compliance.

All eight integrated/standalone active-profile/override maps were freshly evaluated with IFD disabled: `rog` remains `openai-medium`; `thinkcentre`, `t14`, `macm5` remain `openai-anthropic-go`; every override map is `{}`. Every selected profile exists in the preview and is full-object equal to the original. No default-profile change, paid fallback or active-host rerouting is needed. Non-host external callers selecting retired names must make a separate explicit choice; this proof does not authorize silent default redirection.

Scratch formatting succeeded with the repository formatter via:

```text
nix fmt -- --tree-root /home/glats/.local/opencode-v2/tmp/opencode/catalog-retirement-preview/3979-6chRUIOi /home/glats/.local/opencode-v2/tmp/opencode/catalog-retirement-preview/3979-6chRUIOi/providers-base.nix
formatted 1 files (0 changed)
```

The first ordinary out-of-tree formatter attempt was rejected by the primary tree-root boundary; a subsequent unsupported `--flake` invocation and relative-path attempt also failed without modifying input. The final explicit scratch tree-root/absolute-path command succeeded. No full flake/native new-candidate build was claimed or attempted while primary source remains unapplied.

### Current catalog: zero usable-missing in the preview

No matching previously saved public catalog file was found in the approved temporary area, so one new **unauthenticated public GET** was used; no provider/model/account endpoint was contacted. Fetch started at `2026-10-09T16:56:34.480665+00:00`; response bytes were saved as `public-catalog.json`: **5,374,722 bytes**, SHA-256 **`6172b02b1955b5812647eb8a4434908b154a138fc551a74d65e7024b1329ba20`**. This is a new catalog hash, not a claim that the 16:15 body stayed constant.

The preview has **26 unique selectors: 23 built-in plus three explicit NVIDIA custom selectors; zero usable-missing**. All 23 built-in rows exist and none is deprecated in the newly fetched catalog; no `#variant` is used. Native resolution incorporates its already-source-verified deprecated-entry filtering. The complete retained built-in inventory is:

```text
anthropic/claude-opus-5-5
anthropic/claude-sonnet-5-5
github-copilot/claude-opus-5.5
github-copilot/claude-sonnet-4.6
github-copilot/claude-sonnet-5.5
github-copilot/gpt-5.3-codex
github-copilot/gpt-5.4
github-copilot/gpt-5.4-mini
github-copilot/gpt-5.5
github-copilot/gpt-5.6-luna
github-copilot/gpt-5.6-sol
github-copilot/gpt-6-astra
github-copilot/gpt-6.1-sol
openai/gpt-5.6-luna
openai/gpt-5.6-sol
openai/gpt-6-luna
openai/gpt-6.1-sol
opencode-go/deepseek-v4-flash
opencode-go/deepseek-v4-pro
opencode-go/glm-5.3
opencode-go/glm-5.3-flash
opencode-go/kimi-k3
opencode-go/minimax-m3
```

Custom inventory: `nvidia/minimaxai/minimax-m3` maps to `minimaxai/minimax-m3`; both `nvidia/nemotron-3-ultra-550b-a55b` and `nvidia/nvidia/nemotron-3-ultra-550b-a55b` map to canonical `nvidia/nemotron-3-ultra-550b-a55b`. MiniMax remains an explicit runtime-added custom declaration despite public deprecation, as documented in the initial report; backend availability is not certified. No free-provider selector remains in these 32 effective profiles.

This proves preview **catalog resolution only**, not current account entitlement, uptime, live tool-call stability, platform build success, or a blanket model-fit approval for untouched inventory. The readiness blockers from the two bad selectors are removed in scratch; they remain present in primary source until the parent applies the approved patch.

### Exact parent-owned follow-up scope

After the outstanding old-source Linux results arrive, apply the guarded source patch and regression patch; update only the retirement/alias acceptance exceptions in `specs/gentle-ai-declarative-runtime/spec.md` and the dated operational note in `docs/gentle-ai-update.md`, as drafted in external `regression-spec-runbook-plan.md`. Preserve the existing ODD exception, require exactly three profile-key retirements, all 32 remaining objects/order equal, and exactly one alias-record provider delta. Do not carry forward the superseded five-Lightning-field exception.

Then format touched source, run the actual repository regression, shared `nix flake check --no-build`, explicit standalone/Darwin evaluations and required native platform configuration/build gates under a **new reviewed fingerprint**. No activation, account migration, state copying or Git delivery is authorized by this preparation. Exact source rollback is the reverse guarded patch plus the corresponding approved test/spec/runbook delta, never a broad revert of unrelated concurrent work. Historical binary-build provenance stays valid, but old full-system/HM outputs cannot certify the new declarative candidate.

## Applied repair and new source identity — 2026-10-09

The parent authorized implementation after reporting the original-fingerprint Linux system/HM build gate completed (#3968). Rechecked source/test SHA preconditions, then used the patch tool to apply the exact approved source preview and regression delta. Updated the routing requirement with narrowly enumerated retirement/alias exceptions and three GIVEN/WHEN/THEN scenarios; updated the tagged runbook with no-fallback retirement guidance. No proposal/design history or common task/progress reports were rewritten.

| Applied path | Delta |
|---|---|
| `shared/opencode/providers-base.nix` | Exactly three profile blocks removed and one native NVIDIA alias record added; target SHA `9cad2ce32da1f7358c8fb8cc847b9cd796bdf0c4be9a55bbc5a1a74c5b6b682b` equals the approved preview |
| `shared/opencode/v2-agents.test.py` | Exactly retired-name/keyset/count/order exceptions plus alias-only provider equality; all existing graph/permission/override checks retained; SHA `899dece3a41f43c239d4fba6260d2deba16778cd5f6f7eff081f10c5e4c9f80a` equals prepared parent test |
| `specs/gentle-ai-declarative-runtime/spec.md` | Explicit three-profile retirement, 32-object/order parity, same-backend alias, no model replacement/policy waiver/default fallback; SHA `fe50d3448273e3a298099c404659083e157fbc145971ef9b833d94457c02a8f5` |
| `docs/gentle-ai-update.md` | Dated approved retirement/alias operational note and new-candidate gate distinction |

New reviewed-candidate identity receipt was written at `2026-10-09T17:34:00.126208+00:00` to **`/home/glats/.local/opencode-v2/tmp/opencode/repaired-v4-fingerprint.json`**. Its **31-owned-entry compact-manifest SHA-256 is `80c3f4be999c87e20eccb35521d5fdcae5c0e33a8ac0b98ffb52282987aea4fd`**. The original `final-v4-fingerprint.json` and original fingerprint remain untouched. Only three of those owned entries changed (provider source, regression, runbook); the acceptance spec is separately hashed in the new receipt. Baseline HEAD remains `4750736cd68f517a871ac7448639c94546472390`; three deleted entries remain absent. Actual raw Git index diff hash remains `89dfdbb95e7ce6359c3835e659285ec01ca06587b1086c43110d9a60581ca6f6`, equal to the original manifest. No staging/commit/push occurred.

An external proof initially compared an RTK-transformed shell-pipeline checksum rather than raw Git bytes. That assertion failed without any index change; direct Python subprocess Git output proved the original raw manifest hash still matches, and the external assertion now compares that raw identity. This was a proof-harness correction, not a production workaround or restoration of foreign staged work.

Applied source evaluates **exactly equal** to the approved preview JSON. All 32 retained profile objects/order and provider-policy comparisons therefore hold, and the recorded public catalog still resolves **23 built-in plus three custom selectors with zero usable-missing**. Reused the saved unauthenticated 16:56 UTC response with SHA `6172b02b1955b5812647eb8a4434908b154a138fc551a74d65e7024b1329ba20`; no newer refresh timestamp or live service availability is invented. Both host configuration modes were projected again for all four hosts and equal the preview: rog `openai-medium`, others `openai-anthropic-go`, all overrides `{}`.

Direct negative evaluations of the **actual `agents.nix` consumer**, overriding only `activeProviderName`, fail for each retired name with the exact diagnostic `No active provider found. Check activeProviderName in shared/opencode/providers-base.nix`. There is no implicit default/paid fallback. The pure shipping 2.0.14 alias schema/parser/constructor was re-executed successfully with zero requests; the final body model field remains established by the previously quoted exact source.

Completed repaired-source focused checks: repository Nix formatting (zero changes), actual ODD graph/profile/provider regression, launcher/root/proxy/session-preservation fixtures, **24 Bun transport tests with zero failures**, and existing tagged offline contract derivation (transaction: nine top-level/46 subtests; CLI: 55 top-level/197 subtests). Binary/renderer/API source is unchanged; previously established Go/API evidence is not replaced with unrelated full-suite network tests. Prompt/fixture checks do not certify organic model behavior.

A combined foreground command exceeded its 120-second tool deadline after launcher checks, before reporting ownership/Bun completion. No failed ownership assertion was inferred from the timeout. Full repaired-source shared flake-check, nine Linux derivation evaluations, all six native Linux system/standalone-HM closure builds, ownership and repeated regression/transport checks were then started in a bounded external logging runner, `verify-applied.py`, background shell `sh_121b7826c001t5PAoHHfMVo5T3`. Those results are pending until its completion receipt; they must not be borrowed from the earlier old-source build. Logs/receipt live alongside the preview artifacts. Native repaired Darwin configuration/build proof remains a separate parent/Mac-worker gate; no SSH, native provider/auth initialization, activation or live model calls were performed here.

### Completed gates, schema-check regression and final fingerprint

The background runner completed successfully at **2026-10-09T17:42:57.003196+00:00**, exit 0: shared `nix flake check --no-build`, nine Linux system/integrated-HM/standalone-HM evaluations, all six native Linux closures, actual ownership tests for V2/Claude/OpenFang, repeated 24 Bun transport tests and actual ODD/profile regression passed. Its receipt is `applied-verification.json`; its outputs certify the first repaired fingerprint, not the later schema-check correction below.

An additional **actual build** of `checks.x86_64-linux.opencode-v2-agent-schema` then failed: its jq assertion still referenced removed `sdd-explore` at `flake.nix:293–295`. `--no-build` had evaluated that check derivation but had not executed its assertions. Corrected only those three role-key references to `gentle-ai-explore`, retaining the same subagent-mode, string-system, array-permissions and all existing legacy-field/security checks. This is a narrowly scoped stale regression-check fix under the user's test-failure-fix authorization, not a routing exception or weakened schema gate. The actual check build now passes:

```text
drv: /nix/store/hvjk9fwd3xi6av0b1lshkqgfngnfj0g6-opencode-v2-agent-schema.drv
out: /nix/store/i0kjvrx62zzajn1vnmsgfq5f6jyql34z-opencode-v2-agent-schema
```

This changes a fourth owned entry (`flake.nix`). Preserved the initial repaired receipt as `repaired-v4-fingerprint-before-schema-fix.json`; the current **`repaired-v4-fingerprint.json`** now records final **31-owned-entry SHA-256 `12d82f4746470b91b04967bea52842e70537a70492c3a382606ee08b200f9dfb`**, recorded at `2026-10-09T17:46:01.720036+00:00`. The earlier `80c3f4...` repaired identity is historical, not the identity to use for subsequent Mac/runtime gates. Original reviewed `final-v4-fingerprint.json` is still untouched. Provider/test target hashes, spec companion hash, active host mapping, catalog counts and all retained profile objects remain unchanged by the schema fix.

Re-executed the shared no-build flake check, **all nine evaluations, all six native closure builds, and actual schema build** against the final source; `final-verification.json` records **2026-10-09T17:54:13.340500+00:00–18:00:56.512674+00:00**, exit 0. An initial external assumption that the flake-only correction would preserve all derivation paths failed; measured system drv paths changed while all integrated/standalone HM drv paths stayed equal. Rather than reuse system outputs or weaken a product assertion, the runner recorded the changes and rebuilt all six targets. The final measured paths are authoritative:

| Evaluated final target | Derivation path |
|---|---|
| rog system | `/nix/store/if873i67pl7pc01qp9faxl3yq9d4iw51-nixos-system-rog-26.05.20260822.a9e6d84.drv` |
| rog integrated HM | `/nix/store/s2hpc1r8rvcqp86l9qlpigwlp2915vpz-home-manager-generation.drv` |
| rog standalone HM | `/nix/store/czgfdkxyhgny5z6iipk6gqs2y5zdglc3-home-manager-generation.drv` |
| thinkcentre system | `/nix/store/97hq57si2a8861m7kl676d66xalws72m-nixos-system-thinkcentre-26.05.20260822.a9e6d84.drv` |
| thinkcentre integrated HM | `/nix/store/ysbkvqv73dkvhz29s49xkn3mgqm5abxx-home-manager-generation.drv` |
| thinkcentre standalone HM | `/nix/store/iqcj3a5hza6ljha95qxkpmj0332mlpp0-home-manager-generation.drv` |
| t14 system | `/nix/store/xxdy1q2rkwk5ds65nnc963gxw2jjgv20-nixos-system-t14-26.05.20260822.a9e6d84.drv` |
| t14 integrated HM | `/nix/store/fvivc81c8sv8sbn1bv6lx4nbqn3xjmg8-home-manager-generation.drv` |
| t14 standalone HM | `/nix/store/nbzrlz7g4pmpjhd566hld9l23sk9ka28-home-manager-generation.drv` |

| Native Linux final build | Output path |
|---|---|
| rog system | `/nix/store/8abvgyjjsqswfxmlnlkjsriympazp86b-nixos-system-rog-26.05.20260822.a9e6d84` |
| rog standalone HM | `/nix/store/lzmimq0lygglp1wvsb4zm44nwbrgfydf-home-manager-generation` |
| thinkcentre system | `/nix/store/k9l956ab70ld9xky4q8prvjmayc5rkbg-nixos-system-thinkcentre-26.05.20260822.a9e6d84` |
| thinkcentre standalone HM | `/nix/store/fq7z75vghbr1akhx4pdgn8mvzzm3c4hq-home-manager-generation` |
| t14 system | `/nix/store/7a6g2y81jpcb71j3kb103cs3hfp8x28l-nixos-system-t14-26.05.20260822.a9e6d84` |
| t14 standalone HM | `/nix/store/csf3k2xmnjcl7414ym9ayhhvl3g8y1bh-home-manager-generation` |

Ownership fixtures passed actual-tree legacy bootstrap, owned retirement, interruption/retry, historical-version and modified-file refusal, foreign/history/receipt preservation and collision refusal for all three consumers. Those fixtures and the unchanged 24-test transport/graph sources were verified in the completed first runner; the schema correction changes neither their implementations nor assertions. It does not certify organic persistence or real credentials/session behavior.

Final status: **applied catalog gate PASS (32 profiles; 23 built-in + three custom; zero usable-missing), shared evaluation PASS, nine Linux evaluations PASS, six native Linux closure builds PASS, built agent-schema gate PASS, focused routing/launcher/ownership/transport checks PASS**. Repaired Darwin native proof and separately authorized rog model/runtime proof remain outside this worker's evidence. No login, model/provider request, native server initialization, activation, Git staging or delivery occurred. The final fingerprint supersedes both old-source native outputs and the first repaired identity for future transfer/review; keep all earlier receipts as historical evidence.
