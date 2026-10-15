# Organic readiness awaits user-performed isolated authentication

## Current boundary — explicit reopening

User approval #3983 explicitly reopens the stopped cycle for a private native
login and a bounded rog model/MCP test. STOP #3934 is therefore historical, not
the current authorization blocker. No production database/account copy, secret
inspection, activation, or Git delivery is authorized.

The private compiled runtime is prepared and statically checked (#3989). The
remaining immediate human step is native OAuth authentication by the user in
their own terminal. No account database, provider request, session, or receipt
has been created by the preparation. The command and private paths are recorded
in `login-isolation-check.md`. Before model execution, establish the actual
cycle-budget controls; the previously proposed six-request ceiling is not yet
an enforced limit. Configuration/build regates for the approved routing repair
remain independently tracked.

The analysis below records the earlier stopped state and credential-forwarding
investigation. It must not override the later explicit approval.

## Historical stopped-cycle analysis

The single immediate organic-gate stopper is **no currently authorized isolated authenticated test cycle**. STOP #3934 remains effective after the general continuation request #3961. An account route and specific permission for its use must both exist before task 3.4 can produce real evidence. No permitted credential-forwarding escape hatch was verified in the public V2 documentation or inspected 2.0.14 package source; that route is closed for this continuation.

## Preflight stage and provenance

The existing preflight stopped before candidate runtime initialization, session creation, delegation, provider requests or MCP canaries. It recorded zero provider/MCP requests and no session or receipt IDs. Reuse `apply-progress.md:493–545` and its sanitized preflight evidence rather than reading any production database or account/session files. Its presence-only check established no inherited `OPENAI_API_KEY`; this analysis did not repeat that check or inspect other environment variables.

The native kernel/CLI and SDK remain 2.0.14; Gentle remains 4.0.0 at `ff77164d4f56f1665b22fb6fac51c2ccbb769400`. Recorded native version-only probes are sufficient provenance, not compatibility receipts. `pkgs/opencode-v2/default.nix:11–32` pins the platform-native npm binaries and hashes. `pkgs/opencode-npm-packages-v2/versions.json` pins the shipped plugin/client dependency closure; the separately inspected public SDK 2.0.14 depends on core/server/client/plugin/schema 2.0.14. No upgrade, native invocation, account access or candidate initialization was performed here.

## Public evidence and forwarding boundary

Official [provider account storage](https://opencode.ai/v2/docs/cli/providers#storage) says saved API keys and OAuth tokens live in the server SQLite database. Its [environment method](https://opencode.ai/v2/docs/cli/providers#environment) reads supported variables from the model-request server process without saving them. There is no documented global OAuth namespace that an isolated candidate can inherit without account resolution. Context7 `/websites/opencode_ai_v2` independently returned this storage statement; its plugin `integration.connection.resolve` example explicitly resolves credentials, not credential-free forwarding.

The [embedded SDK](https://opencode.ai/v2/docs/build/sdk) assembles an OpenCode host and routes its API calls in memory without an HTTP listener. That removes a network hop; it does not make initialization nonlive or make account resolution cease to be credential use. Exact public package source confirms:

| Public package / source | Inspected boundary |
|---|---|
| [SDK 2.0.14 tarball](https://registry.npmjs.org/@opencode/sdk/-/sdk-2.0.14.tgz), `dist/chunks/tool-xcejgzf0.js:19–22` | `OpenCode.create` acquires an embedded host and directs its client to `host.fetch`; it does not forward to an already authenticated production provider service. |
| Same package, `dist/chunks/tool-b54z5jwe.js:30–40` | Creates embedded routes with default `database.path = ":memory:"`, permitting an explicit database override, acquires services and resumes suspended sessions. Using the production credential root is not a harmless structural probe. |
| [Core 2.0.14 tarball](https://registry.npmjs.org/@opencode/core/-/core-2.0.14.tgz), `dist/chunks/model-resolver-4j9e7cf8.js:168–179` | OpenAI plugin initialization calls `integration.connection.active("openai")` and `integration.connection.resolve(connection)` to load OAuth. This is runtime credential use even if the agent never prints tokens. |
| Same core package, `dist/chunks/model-resolver-g0jvtwam.js:53–76,78–98,128–145` | Credential service obtains the database, reads credential rows and exposes transactional create/update operations. A shared credential DB is not proven to be a read-only, credential-free source. |
| Same core package, `dist/chunks/model-resolver-pknna89w.js:5–15` | Defines the SQLite credential table, including JSON credential value and active state. |
| [CLI 2.0.14 metadata](https://registry.npmjs.org/@opencode/cli/2.0.14), [tarball](https://registry.npmjs.org/@opencode/cli/-/cli-2.0.14.tgz), `postinstall.mjs:17–23,112` | Public launcher selects a platform-native package and copies its executable. Repository packaging likewise installs that native binary. This launcher is not an OAuth relay. The compiled native implementation was not executed or reverse-engineered; no unsupported whole-binary source audit is claimed. |

The public SDK tarball SHA-256 is `2d0d75d10c515f65b21e029baef7f4ec8aee9eb2c70ae90418a16285227a9945`; core is `81ca7948d414477aeb6facb8c57d973b9a1dbc93deba8341884920c1c3b5718d`. Tarballs were read/decompressed in memory, not installed, imported or executed.

The [network client](https://opencode.ai/v2/docs/build/client#local-background-service) authenticates to an OpenCode server, not to a credential-free model gateway. `Service.ensure` may start a service; `Service.headers` supplies server authentication. Calling production session/generate endpoints would run models and write runtime state. Neither is permitted here. The public [API reference](https://opencode.ai/v2/docs/api) lists provider discovery, integration connect, credential management and generation/session operations, not a documented read-only provider-request relay that supplies production OAuth while leaving that runtime untouched. No authenticated endpoint was contacted to investigate this.

[Provider HTTP transport and endpoint overrides](https://opencode.ai/v2/docs/providers#websockets) select how requests reach providers; [endpoint overrides](https://opencode.ai/v2/docs/providers#endpoint) retain the existing connection. They do not supply an account. Custom gateways need their own approved endpoint/authentication and would not automatically preserve the selected native OpenAI OAuth route or candidate acceptance identity. A public models.dev catalog fetch is static public metadata, not an authentication gateway, entitlement check or account-access certification.

## Exact acceptance consequence

S9 still needs real configured lens/refuter/validator delegation and bound admitted receipts. S10 still needs organic configured-runtime refusal evidence, not merely tagged offline negatives. S11 still needs observed model/runtime authorization adherence; guidance and fixtures do not enforce arbitrary Git delivery. S12 still needs organic ODD identity/readback/outage/conflict/pending-mirror recovery. Structural full-behavior assertions, read-only file/mirror contracts and public catalog work cannot certify these behaviors.

At least one appropriately bounded rog-first authenticated candidate cycle is necessary to begin closing task 3.4; one cycle is not sufficient to certify every scenario, host or recovery case. No blocked test is evidence of native 2.0.14 incompatibility, unsupported models or a permanent API-key requirement. Linux build, catalog and lifecycle workers can finish their independent nonlive gates without duplicating this analysis or crossing this boundary.

## What can actually unlock the stopped stage

A future explicit reopening of the stopped auth/test scope, together with a suitable test account, can authorize native OAuth login into a genuinely isolated candidate database and the bounded model/delegation/MCP cycle. Alternatively, a separately approved securely inherited provider credential can enable an isolated cycle if that authentication route preserves the acceptance identity. Neither choice is provisioned, requested or executed here; no secret should be pasted into chat. Consent without an account route, or an account route without renewed test authority, does not unlock the stage.

Reusing the production database, letting the SDK read it indirectly, copying account/session material, extracting endpoint credentials, starting an authenticated proxy, or automatically giving workaround login instructions is not an authorized substitute. The general request to continue nonlive readiness work does not silently reopen STOP #3934. Activation and Git delivery remain separately unauthorized even after a future successful test cycle.

This analysis wrote only this report and project-scoped Engram observations/summary. It did not modify task checkboxes or shared worker progress, access secrets/credentials/session databases, dump environment values, start services, call providers, contact Mac SSH, activate or publish anything.
