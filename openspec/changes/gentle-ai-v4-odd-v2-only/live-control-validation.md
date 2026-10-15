# Private control validation stopped before native plugin activation

**STOP — no model launch is authorized by this result.** The owned private native 2.0.14 HTTP server started, but its public `/openapi.json` endpoint returned HTTP 401. An explicit native `api --server <private-loopback-URL> get /api/info` client also exited 1. The guard ready marker and budget snapshot were not emitted: location/plugin activation has not been demonstrated. No prompt, title request, provider generation, MCP tool call, credential-value inspection, SQLite read/copy, activation, commit or push was performed.

Authorization #3983 permits the fresh private account and bounded rog cycle, not production credential reuse. The user's login confirmation is retained as confirmation only; this failure does not establish a bad OpenAI login, missing model entitlement or MCP incompatibility. No shared service was contacted. No parallel generation process or second location was created to reset a budget.

## Checks completed

- Read `login-isolation-check.md`, `live-budget-check.md`, the entire proposed guard, actual shipping plugin declarations and public 2.0.14 loader implementation. Loaded the OpenCode, ponytail, investigate-first and verify-and-stop skills; consulted official V2 plugin/SDK/API documentation and Context7 for the new server/location/plugin-order questions.
- Checked matching process argv and cwd metadata, without reading process environments, credentials or databases. No matching existing user private TUI/native process was found before startup; no user process was killed.
- Verified all 31 public owned-source entries against the final receipt before and after validation: `12d82f4746470b91b04967bea52842e70537a70492c3a382606ee08b200f9dfb`. No product source, shared task/progress, Git index or ref was edited.
- Installed the reviewed guard only under private configuration, preserving the existing subscription plugin, managed Go relay/registry, grants, role routes and MCP declarations. Added a fail-closed parent-launch gate to both model preparation and HTTP admission; the authorization file was never created.
- Actual TypeScript 5.8.2 strict/no-emit checking against shipping 2.0.14 dependencies exited 0. Pure regression checks distinguished the original guard's missing launch gate from the installed guard's refusal with **zero preparation and HTTP admissions**. These are pure checks, not native hook-execution certification.
- Tested the watchdog against a newly created harmless synthetic process group: a SIGTERM-ignoring Python parent and finite `sleep 30` child. TERM followed by KILL stopped both; parent exit was SIGKILL and the child was absent or nonrunning zombie. No existing service/user process was signalled.

## Installed private controls and ordering

Private root: `/home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-live-rog/login.ibv0_799`.

The installed plugin is `home/.config/opencode-v2/plugins/private-controls/guard/index.ts` beneath that root. The immediate `private-controls` directory has no entrypoint, so it contributes no auto-discovered plugin. Its nested `guard` directory is the final explicitly configured plugin, after `opencode-claude-subscription@0.1.4`. Public pinned `model-resolver-pnc3prtr.js:96–134` processes discovered operations before configured operations; `model-resolver-zxq2ej10.js:14–31` establishes immediate directory discovery. This proves intended source ordering, **not actual loaded ordering**; the latter remains blocked.

The guard registers genuine `Plugin.define/setup` handlers, not a fake SDK. It edits only private provider transport to `http` and agent step ceilings, registers 20-preparation/20-HTTP-admission independent counters, token ceiling 8192, no automatic retry, compaction/WebSocket refusal, sticky failure and a 15-minute deadline. No request bodies, account identity, authentication headers or credential fields are logged. The added gate requires the private `parent-launch-authorized` file, which remains absent. Unexpected session preparation before parent launch would latch refusal before incrementing counters.

Production OpenAI OAuth defaults to WebSocket. Even a later successful private HTTP-only cycle would **not certify the production default WebSocket transport**. These counters are neither a dollar ceiling nor a bound on every raw network/auth/catalog/MCP exchange; direct non-session generation remains outside the proposed hook envelope and must not be invoked.

## Actual native attempt and stop

Scratch `control.py` owns only the process group it creates, with a 900-second watchdog and an explicit stop-file control. It invoked the compiled private launcher:

```text
/nix/store/3khlkav73hhzg98kw6m37mi4svsg5shz-gentle-v4-private-login/bin/opencode-private serve --hostname 127.0.0.1 --port <fresh-loopback-port> --log-level none
```

The cwd was the private `project`. This is an owned native HTTP server, not a managed shared service; `serve` does not accept the TUI's `--standalone` flag. The HTTP probe returned 401 before a usable API contract or authenticated location activation was obtained. Native API access was attempted only with the explicit private server, never auto-discovery of a production service. Its exit 1 is recorded without unsafe raw stdout/stderr. No raw server logs were retained; only fixed guard markers/integer counters would have been persisted to `control-public.jsonl`, which remained empty.

The controller stop file was created, and the native process subsequently exited 130. An independent process-group metadata check found **zero remaining members** of the owned group. Final scratch controller review made its watchdog thread non-daemon so the owner cannot exit between TERM and descendant KILL; the harmless synthetic watchdog check passed again. No native restart was attempted. The server is no longer launch-ready. Private account/database state is preserved without inspecting its contents. Scratch `controller.json` retains public PID/PGID/deadline/loopback metadata only. The controller deliberately refuses an existing controller record rather than silently starting a replacement cycle.

## Required next step

Resolve the authenticated **private native controller connection** using a verified native capability flow or native stdio protocol without reading/copying production secrets or inspecting private credential values. Any fresh controller attempt requires explicit parent review of this stopped, unactivated attempt; do not remove the record and call that continuous-process budget proof. Then prove actual guard loading, last ordering, private HTTP route and zero live counters before parent launch. Do not create the parent-launch file on this failed result.

No MCP status was obtained and no MCP call was made. If subsequent native startup reports unavailable authentication, report the specific semantic failure and stop rather than borrowing production GitHub accounts, disabling servers or spoofing connected status. There is no validated session endpoint/controller protocol handoff from this attempt, and no PASS or organic acceptance claim.

## Latest result: native controls PASS; model launch remains blocked by OAuth visibility

This section supersedes the initial controller-access blocker above, while preserving its history. Following explicit parent authorization, fresh preflight 2 established the native capability connection, actual guard load and HTTP route. It expired during the usage interruption with **zero preparations and zero HTTP admissions**. Its owned process group was independently confirmed empty. No previous record was deleted and no paid cycle was resumed or reset. Fresh preflight 3 is a separately documented zero-admission startup, not continuous-process proof from either earlier attempt.

Actual preflight 3 establishes **control readiness PASS**, not organic acceptance or permission to submit a prompt. Normal native integration metadata still reports **no available OpenAI OAuth connection** in this private runtime. The parent must resolve that status through the authorized private native account interface before launching. This is not a provider request failure, entitlement determination or reason to substitute an account/key/model. No account labels, identities, credential values, authorization headers, process environments or SQLite contents were inspected or printed.

### Verified controller authentication, without credential inspection

The actual compiled 2.0.14 binary's embedded public CLI source establishes the mechanism: default `serve` generates a random password; bare `api --server` supplies no capability unless the native password context is present. This explains the original 401. Native `serve --service` writes its own private registration/capability; shipping `Service.discover({ file, version: "2.0.14" })` and `Service.headers(endpoint)` consume that capability internally. The agent never reads or dumps the native registration, password or provider credential values.

Public evidence is retained under scratch `controller-public-source/native-embedded`: extracted CLI `chunk-2.js` contains private service path selection; `chunk-3.js` contains native server registration/startup; `chunk-4.js` contains the native standalone stdio bootstrap; `chunk-5.js` contains the explicit-server and native-discovery connection branches. These are immutable binary source strings, not runtime logs. The public CLI npm package contains a launcher rather than readable CLI implementation. Public package tarball SHA-256 values are `44a4eba6067533fbdd561097f39a212ca88b3af8be469480eb6cc8fb85263e01` for CLI 2.0.14 and `b3363d6d96859e192bc23d9af8e5244fd72ca6cb74dd754f9a8de549b0302298` for server 2.0.14. No package install or lifecycle script ran.

Fresh preflight 3 uses the same compiled private launcher, with `serve --service --hostname 127.0.0.1 --port <fresh-port> --log-level none`, owned by the scratch watchdog. It is registered **only beneath private XDG state**, not the user's production service. Inherited controller password/handoff variables are removed by name without examining values. Native `debug paths state` confirms `home/.local/opencode-v2/state/opencode`; native `debug paths config` confirms the private configuration directory. Because service mode changes cwd to private HOME, every location-scoped API call explicitly selects the private `project` directory.

### Actual guard, ordering, route and role caps

The native API reports all **93 plugins active**, including the existing Engram, host-config, tagged Go review relay, RTK, registry and subscription plugins. The guard is the **last external plugin**, and its actual `PRIVATE_CYCLE_GUARD_READY` marker and integer-only snapshot are recorded. Native builtin configuration plugins follow it: claiming it is literally the final plugin would be incorrect. Source audit of all 16 following builtin configuration plugins found no `ctx.session.hook` or `ctx.tool.hook` registration; `preflight2-native-suffix-source-proof.json` records their exact public source files. Thus no later builtin hook overwrites the guard's model/HTTP/retry/token/tool controls.

An actual native regression check exposed a different ordering issue: late `opencode.config.agent` creates the 16 configured agents after the guard's early agent transform. Their runtime steps were initially unset. The narrow repair adds **only `steps: 8` to those 16 private JSON definitions**, leaving every other configuration field structurally identical to the pre-repair private candidate. Native fresh preflight readback now reports **all 22 agents at eight steps**, including every configured role. The configured 13 managed roles, Sol/Luna IDs, grants, authentication methods and compiled Gentle Go relay remain unchanged. No production source/configuration was edited. The intermediate same-process readback remained stale before its watchdog expiry; it was not used as passing evidence.

Actual native `provider.get` reports OpenAI `settings.transport === "http"`. The ready snapshot is `preparations: 0`, `httpAdmissions: 0`, `stopped: false`, `deadline: null`, with the parent launch file absent. The loaded typed guard registers 20 independent preparation/HTTP-admission ceilings, `maxTokens = 8192` for context/generate/title, no automatic retry, compaction refusal, unexpected-WebSocket refusal and sticky failures. No model hook was deliberately exercised through a generation call: dispatch-body/token usage and organic admission enforcement remain evidence for the later authorized cycle, not manufactured preflight receipts.

Pure checks against the real plugin import now additionally verify an idle preflight does not consume the live deadline: the nullable deadline starts once at the first authorized admission and never extends. Admission 21 is refused independently for both counters, failure remains sticky, the exact 900000-ms deadline refuses admission, and a closed launch gate refuses before incrementing either counter or starting the deadline. Strict shipping-API typing passes. The harmless process-group TERM/KILL watchdog check passes again.

The watchdog has a **finite 900-second preflight lease**. Only the parent's later creation of `parent-launch-authorized` starts a separately latched 900-second live watchdog; it cannot be extended by changing/removing/recreating the file. The guard starts its own fixed deadline on first authorized admission. These are conservative complementary limits, not an idle-preflight expiration disguised as a paid-cycle budget reset. The authorization file remains absent and the live watchdog unstarted.

### Native readiness status and current handoff

After guard proof, native MCP status-only readback reports all seven declared servers **connected**: browsermcp, context7, engram, exa, github-personal, github-work and nixos. Initial pending states were transient startup snapshots, not fabricated connection failures. No MCP tool call was made; connected status does not certify tool permissions, GitHub account entitlement or the later canary. No MCP declaration was disabled and no token was copied to repair connectivity.

OpenAI native `integration.list` and subsequent `integration.get({ integrationID: "openai" })` both produced `privateOpenAIOAuthAvailable: false`, reporting only that boolean. The latter check occurred after full activation. Account metadata/credential values were not printed or resolved by the controller helper. The human's prior login confirmation remains preserved, but this runtime availability mismatch is a real **pre-model stop**. Do not create the launch file or test entitlement with a paid prompt to work around it.

At final validation the bounded preflight-3 controller was alive:

| Public controller metadata | Value |
|---|---|
| Owned native PID / PGID | `541995` / `541995` |
| Watchdog controller PID | `541992` |
| Loopback URL | `http://127.0.0.1:33331` |
| Sole guarded location | scratch `login.ibv0_799/project` |
| Preflight lease expiry, Unix seconds | `1791580761.1468837` |
| Live watchdog deadline | `null` — parent launch not authorized |
| Preparation / HTTP admission counts | `0` / `0` |
| Manual stop control | scratch `stop-private-preflight3` |

The controller is not an unbounded service: it kills its owned process group when that finite lease expires unless the parent has legitimately started the live lease after resolving the stop. If it expires before handoff, report expiry, do not silently restart or claim the same process remains ready. The stop-file path affects only this owned group. No user TUI/service was killed.

Scratch `connect-private.ts` provides `connectPrivate()`, using **only native `Service.discover` plus `Service.headers`** and checking the returned server version/PID against public owned-controller metadata. It returns `{ client, location }`, never returns the raw endpoint capability, never calls `Service.ensure`, and never spawns a generation host. A parent script can import it and use the shipping native session API in this same process after all launch gates are satisfied. Verified 2.0.14 routes are `POST /api/session`, `POST /api/session/{sessionID}/prompt` and `POST /api/session/{sessionID}/interrupt`; the shipping interrupt input is `{ sessionID, resume: false }`, not the newer documentation's `continue` spelling. No session was created and none of these generation-related operations was invoked here.

For a human-only account-status correction while the lease is live, the compiled private launcher from the same private project can use native implicit discovery **without `--standalone` or bare `--server`**, attaching to this already registered private process. The parent must check the exact same controller remains alive first; no secret should be copied into chat. Do not run a prompt in that interface, and do not launch another standalone server as if it retained this ledger.

Sanitized receipts are scratch `preflight3-public.json`, `native-readiness-public.json`, `preflight3-final-public.json`, `control-preflight3-public.jsonl` and `controller-preflight3.json`. The controller connection and preflight sources strictly typecheck against shipping 2.0.14. All 31 owned public source entries again match `12d82f4746470b91b04967bea52842e70537a70492c3a382606ee08b200f9dfb` before/after. Only this report was appended in the repository; shared tasks/progress and product sources remain untouched. Production-default WebSocket transport remains uncertified, and no organic acceptance or spend/raw-network ceiling is claimed.

## Narrow OAuth root trace: no saved OpenAI connection in the authorized private runtime

Before recommending another human action, the same live private controller was traced through public shipping source and normal native **metadata-only** APIs. This narrows the stop to **zero saved OpenAI connections**, rather than an inactive selection, different provider ID, transport mutation or documented standalone in-memory behavior. It does not establish where the human's earlier authentication occurred or whether an external browser flow finished persistence; those facts cannot be recovered by inspecting other account roots, credential files, logs or SQLite under this authorization.

Actual native `provider.get` reports provider ID `openai`, integration ID `openai` and HTTP transport. Actual native `integration.list` metadata reports OpenAI key/environment methods and the native OAuth method IDs `chatgpt-browser` and `chatgpt-headless`, but **connection count 0, saved-connection count 0, OAuth false, key false and environment-connection false**. Metadata for other connected integrations contains environment connections only, not saved accounts. No account ID, label, name, value or environment variable value was printed. `oauth-diagnostic-public.json` retains only provider IDs, method kinds/IDs, counts and availability booleans.

Public source eliminates account-selection masking: `model-resolver-fbfs1p3d.js:194–209,438–451` projects **all** saved connections for an integration and only orders them for active selection; it does not hide inactive accounts. Its credential service is a global node, and `model-resolver-g0jvtwam.js:72–73` filters saved records by integration ID, not by Location/project/user label. Native OpenAI OAuth declares and persists integration ID `openai` for both browser and headless methods (`model-resolver-4j9e7cf8.js:46–51,119–124`). There is therefore no existing private account available to reactivate via a selection change, and no demonstrated `openai-codex` alias mismatch to repair.

The exact previously supplied login launcher and current service launcher are the same immutable ELF wrapper. Its public `candidate.nix:15–26` forces the same private HOME, XDG roots, configuration directory and **absolute `OPENCODE_DB`** path. Both use the same private project; service mode changes its process cwd to private HOME, but explicit API Location selects the project and credential storage is global. The native standalone bootstrap inherits the wrapper environment and starts the same binary with `serve --stdio --port 0` (`root-trace-8cf2cd5834dc.js`). Both stdio and service modes pass `database.path = Jy(privateDataRoot)` to the same server startup implementation. `root-trace-d0c8e27d7895.js` establishes `Jy`: an absolute `OPENCODE_DB` is honored unchanged, and `:memory:` requires that explicit value. The supplied wrapper forces a real absolute file, not `:memory:`. Standalone changes server ownership/authentication, not this persistence path.

The compiled launcher's source-only `debug paths db` returns exactly:

```text
/home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-live-rog/login.ibv0_799/home/.local/opencode-v2/data/opencode.db
```

File **stat only** confirms that path exists (inode `1082753483`, size `12382208` bytes at the diagnostic); the hypothetical nested `data/opencode/opencode.db` is absent. No file contents, WAL contents or SQL were read. This rules out the suspected extra `opencode/` suffix for the declared launcher without probing any production database. The guard spreads existing provider settings and changes only `transport`, never credentials, integration identity, account methods or saved account records; the private JSON repair changes only 16 `steps` values. Both mechanisms are independent of global credential persistence.

The genuine remaining stop is consequently **no persisted OpenAI account visible through the native private runtime at the expected root**. It is not a request to reconnect merely because HTTP authentication failed—the controller 401 was already fixed—and not a claim that the human is mistaken. No account can be recovered or selected automatically from the permitted metadata because the count is zero. Looking elsewhere or borrowing production account state is forbidden; initiating/completing a new human OAuth challenge belongs to the user, not this worker.

While PID `541995` is still alive within its finite lease, the precise human diagnostic is to attach to **that existing private server**, not create another standalone process:

```sh
(umask 077; cd /home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-live-rog/login.ibv0_799/project && /nix/store/3khlkav73hhzg98kw6m37mi4svsg5shz-gentle-v4-private-login/bin/opencode-private)
```

Open `/connect`, select OpenAI, and first inspect the account state in the user's own terminal. If an account is shown there, report that discrepancy for another metadata-only check rather than repeating authorization blindly. If no account is shown, finish an offered native ChatGPT OAuth method in that exact interface; completion must produce a visible saved account there before exiting. Do not submit any model prompt, copy a key/code/token into chat, use `--standalone`, or use bare `--server`. The parent must verify the controller is still alive **before** giving this command: ordinary native discovery can otherwise start a new private process, which would be a new preflight, not this ledger. If the lease has expired, report that and explicitly plan a new zero-admission preflight rather than silently claiming continuity. The launch gate remains absent throughout.

### Preflight 3 lease subsequently expired — no live controller remains

The watchdog completion notification confirms `PRIVATE_NATIVE_EXIT -9` and `PRIVATE_CONTROLLER_STOPPED`. A subsequent owned-PGID metadata check found **zero remaining members** of group `541995`; the parent launch gate is still absent. The last recorded native snapshot remains zero preparations, zero HTTP admissions, no stop latch and an unstarted live deadline. No paid cycle started and no replacement process was launched. The preceding human attach command must **not** now be presented as attaching to a live existing controller: explicit preparation of a new zero-admission preflight is required first. Private account state remains preserved without contents inspection; the missing-saved-OpenAI-connection finding and historical control-readiness proof remain unchanged.

## Tested correction for the user's native `service.ensure` timeout

The user subsequently ran the plain private launcher and received `Starting background server...` followed by native `service.ensure` timeout. That command did **not** attach to preflight 3: its lease had already expired. At diagnosis, actual clock `1791593036.5300665` exceeded expiry `1791580761.1468837`, and matching private native argv/cwd metadata showed no live private server or user TUI. No user/production process was killed and no production service was restarted or queried.

The immutable compiled 2.0.14 source explains why plain invocation is unsafe after expiry: without an explicit server, connection resolution enters native `Service.ensure`, which may spawn detached native service contenders rather than fail closed. Native service mode uses default port `49374` when no private port is configured. Public listening-socket metadata showed that port already occupied at diagnosis. This supports a fallback port conflict; the historical contenders' exact failure is **not claimed**, since unsafe historical raw logs and authentication records were not inspected. The established error in our earlier recommendation was its reliance on a controller that no longer existed and implicit auto-start behavior. Increasing timeout or prewarming an uncontrolled service is not the repair.

Fresh preflight **4** was explicitly prepared as a new zero-admission startup, preserving all earlier records and private account state. It uses native `serve --service` registration at a fresh loopback port, the same compiled private wrapper, the same guarded project, and the existing finite watchdog. No actual paid cycle has ever been restarted or reset. Actual native readback again passes guard load, last-external/relevant-hook ordering, HTTP route, 8192-token handler registration, all 22 agent step caps, independent 20/20 counters at zero, no stop latch and an unstarted live deadline. All seven MCP servers subsequently report connected; no MCP tool was called. Saved OpenAI account count remains **0** and OAuth availability remains false.

The replacement human attachment is executable scratch **`attach-private.ts`**, not another bare launcher invocation. It calls shipping native `Service.discover` against only the private registration, checks the finite lease and owned URL/PID/version, and performs an authenticated native health check using `Service.headers`. It never calls `Service.ensure`, never starts a background server, never reads an authentication file itself, and fails with a fixed redacted message if that owned endpoint is unavailable/expired or the parent model gate has been opened.

For the healthy endpoint, the helper starts the existing compiled private TUI with explicit `--server <owned-loopback-URL>`. The native-generated **local controller capability** is consumed in memory through native discovery and passed only into that child’s `OPENCODE_PASSWORD` environment; it is never printed, placed in argv, written to another file, or used as a provider credential. This is authorized normal private controller authentication, not inspection/copying of the user's provider tokens. The compiled wrapper still forces all private HOME/XDG/database/configuration roots, and the explicit native connection branch bypasses `service.ensure` entirely. Actual shipping declarations strictly typecheck; the official V2 client/authentication documentation and Context7 were consulted alongside the exact embedded source.

Regression proof is empirical, not a proposed command:

- With no preflight-4 record, the helper's health mode failed closed with the fixed message and did not auto-start a service.
- Against the owned preflight-4 endpoint, `attach-private.ts --check` printed only `PRIVATE_NATIVE_ATTACH_HEALTH_PASS`.
- A real **12-second pseudo-terminal startup** of the exact executable helper remained alive and rendered the native ANSI TUI and OpenCode branding. No keyboard input was sent, no OAuth attempt or model prompt was initiated, and no screenshot/raw terminal log was retained or printed. The test observed no `Starting background server`, no native ensure timeout and no unauthorized error. The owned server PID remained unchanged. Cleanup stopped only this newly spawned test client's process group, not the server or any user client. Sanitized boolean evidence is `attach-pty-public.json`.
- Post-test native status readback still reports no saved OpenAI account, all seven MCP servers connected, and public guard counters `0/0`, `stopped: false`, `deadline: null`; the parent launch file remains absent. All 31 public owned source entries match `12d82f…` before/after.

The tested human command is now just:

```sh
/home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-live-rog/login.ibv0_799/attach-private.ts
```

This automatically selects the correct private project and exact owned endpoint; no manual server URL, password, cwd, `--standalone` or bare implicit-discovery command is needed. In the user's own TUI, open `/connect`, select OpenAI and inspect its accounts first. If none appear, complete an offered native ChatGPT OAuth method there and verify the saved account appears before exiting. If an account does appear, report that discrepancy rather than repeating OAuth blindly. Do not enter a model prompt or share an account label, code, key or token in chat. This worker did **not** perform the human OAuth interaction or certify login completion.

At the final check, preflight 4's owned native PID/PGID is **`741355`**, watchdog controller PID **`741351`**, URL **`http://127.0.0.1:34115`**, finite preflight expiry **`1791594155.7467477`** Unix seconds, with live deadline `null` and approximately 801 seconds remaining. Public ownership record is `controller-preflight4.json`; stop file is `stop-private-preflight4`; `connect-private.ts` now validates this owned preflight-4 endpoint. The helper refuses after expiry instead of silently creating another process. A later expiry requires explicit parent handling, not reuse of this readiness claim. Receipts are `preflight4-public.json`, `preflight4-readiness-public.json`, `control-preflight4-public.jsonl` and `attach-pty-public.json`. Only this report was appended in the repository; all operational helper changes remain private scratch. The genuine remaining stop is human private OAuth persistence, not native TUI attachment.

## Latest post-login readiness: PASS on the same owned preflight-4 server

After the user's `listo`, native private metadata confirms **one saved OpenAI connection and one OAuth connection**, with provider and integration IDs both `openai`. The previous missing-account stop is resolved. This is normal native metadata access only: no account identity/name/label, token, credential value, authentication record, database contents or raw headers were read or printed by the worker. OAuth availability is **not** proof of Sol/Luna entitlement, quota or a successful provider generation; no paid compatibility probe was performed.

At **`2026-10-10T00:57:32.091062+00:00`**, the same owned native PID/PGID **`741355`** remained alive with watchdog PID **`741351`**, loopback **`http://127.0.0.1:34115`**, sole guarded location `login.ibv0_799/project`, preflight expiry **`1791594155.7467477`** Unix seconds and approximately **303 seconds remaining**. No controller restart or budget reset occurred after the human login. The parent must use or revalidate that finite lease promptly; this receipt does not make it timeless or authorize an automatic replacement after expiry.

The actual native readiness proof is now complete:

- Saved OpenAI connections **1**, OAuth connections **1**; private provider transport **HTTP**.
- All plugins active, including the actual real guard, last among external plugins; the already-audited native suffix adds no later competing session/tool hooks.
- All **22 native agents**, including all **16 configured definitions**, have **eight steps**. Structural private-config comparison again shows only those 16 step limits differ from the original private candidate; model routes, grants, authentication methods, profile and compiled Go relay remain unchanged.
- Native `PRIVATE_CYCLE_GUARD_READY:20_preparations:20_http_admissions:8192_maxTokens:8_steps:15_minutes` marker is present; latest public ledger is **0 preparations / 0 HTTP admissions**, `stopped: false`, `deadline: null`.
- Parent launch gate is **absent**, live watchdog deadline is **null**. Independent 20/20 ceilings, 8192-token hook settings, retry/compaction/WebSocket refusal and sticky failures remain installed and typed. The already-tested synthetic process-group watchdog and pure exact-deadline/counter/gate checks remain applicable to the unchanged controller/guard sources.
- All **seven MCP servers connected** in actual status-only readback; no MCP tool was called.
- All **31 public owned-source entries** again match final fingerprint `12d82f4746470b91b04967bea52842e70537a70492c3a382606ee08b200f9dfb`.

The sanitized comprehensive receipt is scratch **`post-login-ready-receipt.json`**, alongside metadata-only **`post-login-readiness-public.json`**. It records the actual ready timestamp, owned process/lease metadata, account-kind counts, caps, counters, source identity and the connection helper path. No session, model prompt, provider generation, native Gentle cycle stage or synthetic receipt was created here. Shared tasks/progress, production sources/configuration, accounts and services were not modified.

### Parent's exact native connection and launch boundary

The shipping native client connection is available without exposing a capability or creating a new host:

```ts
// Connection only; this does not submit a model request.
import { connectPrivate } from "/home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-live-rog/login.ibv0_799/connect-private.ts"
const { client, location } = await connectPrivate()
```

`client` is the actual pinned **2.0.14 Promise client**, whose resource is singular **`client.session`**, not an embedded SDK `host.sessions`. It verifies the owned preflight-4 PID/version/URL using native opaque capability discovery and never calls `Service.ensure` or spawns a server. Do not print the client, authentication headers or raw endpoint descriptor. Use `location` explicitly for every created session; native role/child/resume work must remain at this one location in this one owned server process. The verified native session interfaces are `client.session.create({ location, agent, model, title })`, `client.session.prompt({ sessionID, text })`, and `client.session.interrupt({ sessionID, resume: false })`; no such call was executed by this worker.

Only the parent runner, after reviewing this PASS and the organic plan/remaining native consent gates, may create **`/home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-live-rog/login.ibv0_799/parent-launch-authorized`**. That starts the controller's once-latched **900-second live watchdog**; first authorized preparation/admission starts the guard's fixed **900000-ms deadline**. All roles/auxiliary title/continuation requests share the same independent 20/20 ledger. Do not modify/remove/recreate the gate to extend the watchdog, restart after any admission, create another generation host, use non-session generation, enlarge the budget, retry a failed stage or switch models/accounts. If the current preflight lease expires before launch, stop and explicitly classify that zero-admission expiry before any new preparation—never call it continued live proof.

Human per-candidate native Gentle typed consent remains a separate future gate: OAuth completion and this readiness receipt do not answer it, invent candidate selections, force review roles or satisfy organic receipt authority. Production-default WebSocket transport and raw-network/dollar ceilings remain outside this HTTP-only control proof. **Status: PASS_READY_FOR_PARENT_LAUNCH; model launch still untouched by this worker.**

### Subsequent preflight-4 expiry invalidates the live-controller handoff

The watchdog subsequently reported `PRIVATE_NATIVE_EXIT -9` and `PRIVATE_CONTROLLER_STOPPED`. Owned-PGID metadata verification found **zero remaining members** of group `741355`; the launch gate remains absent. The final emitted ledger stayed **0/0**, `stopped: false`, `deadline: null`: no paid cycle started. The positive native OAuth metadata and historical control-readiness receipt remain valid evidence, but **there is no live controller now**, so the preceding PASS must not be treated as a current launch-ready process. No automatic replacement was started. The preserved private database/account must be reused through an explicitly authorized new zero-admission preflight, followed by fresh account/control/lease checks; no repeat human login is indicated by lease expiry itself.

## Fresh preflight 5: PASS_READY_FOR_PARENT_RUNNER

Under the existing explicit private-cycle authorization, a fresh zero-admission preflight was prepared for the offline strict-typed native runner in `organic-runner-3983`. Before startup, preflight 4's expired lease, empty owned process group, final zero/zero ledger and absent launch gate were verified again. All old records and the persisted private OAuth were preserved. No paid cycle was reset, no new login was requested and no user/production process was signalled.

The actual fresh native readiness receipt is **`preflight5-ready-public.json`**, timestamp **`2026-10-10T01:24:37.839Z`**. It verifies **one saved OpenAI account / one OAuth connection**, native HTTP transport, all 93 plugins active with the guard last external, all 22 agents at eight steps, all seven MCP servers connected, the actual fixed guard marker and ledger **0 preparations / 0 HTTP admissions**, `stopped: false`, `deadline: null`. The parent launch gate remains absent; no model prompt or MCP tool call was made. Normal native private capability use stays inside shipping `Service.discover`/`Service.headers`; no credential-bearing native registration, token, account identity or headers were printed or manually inspected.

| Current public lifecycle field | Verified value |
|---|---|
| Owned native PID / PGID | `775892` / `775892` |
| Watchdog controller PID | `775871` |
| Loopback endpoint | `http://127.0.0.1:50375` |
| Private Location | `login.ibv0_799/project` |
| Preflight expiry, Unix seconds | `1791596282.5065508` |
| Live watchdog deadline | `null` |
| Remaining lease at final check | approximately **697 seconds** |
| Public ownership record | `controller-preflight5.json` |
| Public counter ledger | `control-preflight5-public.jsonl` |
| Owned-group stop file | `stop-private-preflight5` |

The lifecycle helper **`connect-private.ts`** is now bound to **preflight 5's owned record**, returning the same actual pinned `{ client, location }` Promise-client interface without `Service.ensure` or a new host. The new public ownership JSON retains exactly the runner-required `pid`, `pgid`, `url`, `preflightDeadline` and `liveDeadline` fields; it contains no credential. Its initial and live-watchdog-latch writes now use a private temporary public-metadata file plus atomic `os.replace`, so the foreground runner cannot observe a partially written JSON record. The deadline behavior is unchanged: finite 900-second preflight lease, once-latched 900-second external live watchdog on the parent gate, and fixed 900000-ms guard deadline from first authorized admission. The synthetic owned-group watchdog check passed again.

The runner's README, actual validation predicates and `offline-ready.json` were read before rebinding. Strict typechecking of the **whole existing organic runner** passes after the helper change. No runner predicate was weakened or runner source edited. Its expected guard source hash remains exactly **`f3d8e6e78f08ea8325f96072908c89cc58a5f804ea0c9d902cd212383f9e9466`**. Native suffix-hook evidence and the unchanged guard's pure counter/token/gate proofs remain applicable; actual new-process readiness was independently checked rather than borrowed from an expired server. Private-config structural comparison again preserves all models, grants, methods, profile and Go relay apart from the approved 16 step limits, and all 31 public owned-source entries match final `12d82f…` before/after.

The **parent's next foreground runner command**, not executed by this preflight worker, is:

```sh
bun /home/glats/.local/opencode-v2/tmp/opencode/organic-runner-3983/run.ts \
  --execute \
  /home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-live-rog/login.ibv0_799/controller-preflight5.json \
  /home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-live-rog/login.ibv0_799/control-preflight5-public.jsonl
```

That existing driver revalidates the supplied owner, source, guard hash, OAuth, native controls, zero ledger and lease before its own one-time gate creation. This worker did **not** create the gate, a session, prompt, fixture, consent answer or native Go receipt. The parent should execute promptly within this finite lease, retain this single server/Location/ledger throughout the live stages, and follow the driver's actual stop/consent boundaries. Historical OAuth and readiness do not authorize a restart after an admission, budget enlargement, model fallback or fabricated continuation. If this lease expires first, classify it explicitly; no automatic replacement or continued-process claim is made.

### Preflight 5 later entered its live lease and the owned server stopped

The controller completion notification reports `PRIVATE_LIVE_WATCHDOG_STARTED`, followed by `PRIVATE_NATIVE_EXIT -9` and `PRIVATE_CONTROLLER_STOPPED`. Public owner metadata records a latched live deadline of **`1791596575.7857938`** Unix seconds; the parent launch gate is now **present**. Owned-PGID metadata verification confirms **zero remaining members** of group `775892`.

The last retained public guard snapshot is still `0/0`, `stopped: false`, `deadline: null`, but it is a last-emitted snapshot, not an independent audit of the parent's subsequent session/runner activity. This lifecycle worker therefore does **not** infer that no paid cycle was attempted or authorize another zero-admission restart from this notification. The parent must reconcile its actual runner receipts/failure outcome and classify the stopped live attempt. The gate and historical records were not removed, no account was inspected, and no replacement process was launched. Preflight 5 is no longer a live-controller handoff.

## Explicit corrected-attempt authorization 4046: preflight 6 stopped before launch

The user explicitly authorized one corrected private attempt after the first attempt was closed. Before preparing preflight 6, owned group `775892` was verified empty and its terminal watchdog stop file present. The previous launch gate was **renamed**, preserving its bytes and inode, to `parent-launch-authorized-attempt1-archived`; its SHA256 is `0f4a1cde4a2c292086c55710815bcc826412b50960f79c8ce2b4eb35d7887d7b`. No prior owner/deadline/counter record was reset. The explicit new-attempt boundary and archive are recorded in `attempt2-preflight6-init-public.json`. This is a separately authorized attempt, not continuation of preflight 5.

The corrected runner source hash was verified as `e160ac878fdd0262040b1001b4a227356930f8aad81a1df8522ca19e859ef966`; its README and native model-binding predicates were read. Only private lifecycle mode `fresh-preflight6` and the existing helper's owned-record binding were added. The complete runner passed strict typechecking after rebinding; pure model-binding and failure-metadata checks and the synthetic process-group watchdog passed. The guard remains byte-identical at `f3d8e6e78f08ea8325f96072908c89cc58a5f804ea0c9d902cd212383f9e9466`. No route, grant, provider, guard predicate or runner source was changed, and private account/database contents were neither read nor copied.

Fresh native PID/PGID **`848999`**, watchdog **`848998`**, endpoint **`http://127.0.0.1:45397`**, preflight deadline **`1791600952.317807`** emitted the genuine guard marker and zero/zero initial ledger. However, the single normal native readiness operation returned **`STOP_NATIVE_PREFLIGHT6_READINESS_NO_RETRY`**. Its sanitized wrapper did not retain an individual failed predicate or exception class, so the exact early readiness failure is **unknown**; account positivity, all-seven MCP readiness and full runtime route/cap validation are **not certified for preflight 6**. This is a diagnostic limitation, not evidence that OAuth disappeared, and no repeat login is requested.

The worker stopped rather than rerunning the readiness operation or restarting the server. It used only `stop-private-preflight6`, allowing the existing owned-group watchdog to terminate that server. Completion reported `PRIVATE_NATIVE_EXIT -9` and `PRIVATE_CONTROLLER_STOPPED`; subsequent metadata verification found **zero remaining members** of group `848999`. The parent launch gate remained absent, live deadline `null`, and public ledger **0 preparations / 0 HTTP admissions**, `stopped: false`, `deadline: null`. No session, prompt, model generation, MCP tool call or parent runner execution occurred here. The sanitized terminal receipt is **`preflight6-stop-public.json`**. All 31 public source entries matched final `12d82f…` before/after. **Status: STOP, not ready for parent execution; no automatic retry or replacement.**

### Offline diagnostic correction: preserve each readiness stage, not a generic STOP

The parent's clarification is recorded: preflight 6's metadata-only failure did **not** spend authorization 4046's corrected **model** attempt. No session, prompt, generation or HTTP admission occurred. A generic STOP was not sufficient root-cause resolution; this follow-up therefore investigated and corrected diagnostic loss **offline**, without another native connection, server startup, readiness retry or login request.

The original inline wrapper has two information-loss points: many independent readiness predicates share a single `throw Error("STOP")`, and the catch discards every caught error and prints only `STOP_NATIVE_PREFLIGHT6_READINESS_NO_RETRY`. It writes the positive receipt only after all predicates pass, so no partial API results or failed-stage name survive. The controller merges its owned child's stderr into stdout but intentionally retains only fixed guard markers and narrowly validated budget snapshots (`control.py:73–88`); it does not retain an early native exception. Parsing only fixed/validated fields from the **owned preflight-6 shell output** independently confirms guard readiness, zero/zero, exit `-9`, controller stop and no live-watchdog start. No raw log text was printed. These retained records cannot distinguish native discovery/API failure from OAuth, agent route/cap, plugin, pending MCP or later ledger/identity predicate failure. None of those possibilities is promoted to an established cause.

Public native source explains the necessary diagnostic distinctions: shipping `Service.discover` returns no endpoint unless its registration probe is compatible, version-matched and ready (`promise/service.js:25–33`), and can collapse several probe failures internally (`155–196`). `connect-private.ts` converts that condition into fixed `PRIVATE_CONTROLLER_UNAVAILABLE`, and separately checks PID/version identity. Shipping `ClientError` declares a safe fixed `reason` enum but **does not expose an HTTP status field**; the new diagnostic reports `httpStatus: null` rather than inventing a status or inspecting headers/body/cause. No native registration or database was manually read.

Private **`readiness-staged.ts`** now records a named stage *before every native metadata operation*, and persists each predicate's boolean result and permitted partial summaries before proceeding. Distinct stages cover public owner/closed gate, unchanged guard, opaque discovery/identity, integration activation, saved/OAuth counts, all-agent caps, configured Sol/Luna references (including unchanged variant), HTTP transport, active plugins/guard order, status-only seven-MCP readiness, fixed guard marker, zero budget and final same-owner lease. A failure receipt includes the exact stage, completed checks, sanitized summaries, an allowlisted exception class/native reason and only an allowlisted fixed message. Arbitrary exception text, cause, headers, account identities, tokens and raw response fields are never copied. No readiness predicate was loosened and there is no retry, sleep loop, provider generation or server-start code.

The new helper **`readiness-diagnostics.ts`** and its pure tests demonstrate the original catch's ambiguity, distinct failed-predicate stage retention and hostile error-field redaction. Strict TypeScript checking against the actual pinned client declarations passes. Pure tests pass. Running `readiness-staged.ts --offline` exits **1 before any control-file read or native connection**; only explicit `--execute-metadata` can enter its metadata path, and that path was **not executed**. The scripts are private mode-0600 scratch files. The actual original readiness exception remains unrecoverable from retained evidence; instrumentation fixes future diagnosis, not historical uncertainty or current runtime readiness.

Receipt: **`preflight6-offline-diagnostic-public.json`**. Owned group `848999` remains empty, current launch gate absent, old gate archive unchanged, corrected runner/guard unchanged and all 31 public source entries still match final `12d82f…`. **Status: OFFLINE_DIAGNOSTIC_INSTRUMENTATION_PASS_NOT_RUNTIME_READINESS. Authorization 4046's one corrected model attempt remains unspent; no restart/retry/model call or renewed-permission request occurred in this follow-up.**

## Preflight 7: staged native readiness PASS for the unspent corrected attempt

Under the explicit instruction to execute one instrumented metadata-only preparation, the terminated preflight-6 group was verified empty, the current launch gate absent and all prior receipts preserved. The existing lifecycle helper and staged checker were bound to **`controller-preflight7.json`** and **`control-preflight7-public.jsonl`**; no guard, route, grant, account, database or runner source was changed. One owned native server was started, then **`readiness-staged.ts --execute-metadata` ran exactly once** and returned **`PASS_METADATA_ONLY`**, exit 0, at **`2026-10-10T02:50:04.197Z`**.

Every named predicate passed with retained expected/actual primitives and allowed partial summaries: native opaque discovery and same-process identity; saved OpenAI **1** / OAuth **1**; **22 agents**, all steps **8**; actual configured parent **`openai/gpt-6.1-sol`** and worker **`openai/gpt-5.6-luna`**, both with native variant absent rather than an invented override; private HTTP transport; **93 active plugins**, guard last external; genuine fixed guard marker; **0 preparations / 0 HTTP admissions**, `stopped: false`, `deadline: null`; same final owner/lease and closed launch gate. The immutable shipping native suffix and unchanged guard retain their earlier hook/budget/token/watchdog source evidence. No model entitlement or generation was probed.

The shipping declarations explicitly include MCP `pending`, `connected`, `failed`, `disabled` and `needs_auth` status variants. The first actual seven-MCP status contained only connected/pending startup states. The checker therefore used a **fixed, at-most-30-second metadata-only startup barrier**, bounded also by the preflight lease, polling only while all seven states were connected/pending and at least one was pending. It records five pending snapshots followed by **all seven connected**. A failed API call, non-startup status or deadline would stop immediately; no failed API call, provider request, reconnect or server startup was retried. This observed sequence supports treating pending startup as a bounded readiness transition, but **does not retroactively establish preflight 6's lost cause**.

Current public ownership is native PID/PGID **`857799`**, watchdog PID **`857798`**, URL **`http://127.0.0.1:57043`**, sole unchanged Location `login.ibv0_799/project`, finite preflight expiry **`1791601494.769691`** Unix seconds, live watchdog deadline **`null`**. Approximately **816 seconds** remained at final independent ownership/counter/source verification. The existing finite setup lease is 900 seconds; opening the parent's gate later latches a separate once-only 900-second live watchdog, while first authorized admission latches the guard's fixed 900000-ms deadline. No deadline was opened or extended by this worker.

Receipts: **`preflight7-staged-diagnostic-public.json`** (all named stages and startup states) and **`preflight7-ready-public.json`** (comprehensive sanitized handoff). Strict staged-checker and whole-corrected-runner typechecks pass after rebinding; pure stage/redaction tests pass. The corrected runner hash remains `e160ac878fdd0262040b1001b4a227356930f8aad81a1df8522ca19e859ef966`; the guard hash remains `f3d8e6e78f08ea8325f96072908c89cc58a5f804ea0c9d902cd212383f9e9466`. All 31 owned source entries again match final `12d82f…` before/after; private structural configuration comparison again preserves everything apart from the previously authorized 16 agent step caps. No native registration, SQL, account identity, raw exception, authentication header or token was manually read or printed.

The parent's **next foreground command**, not executed here, is:

```sh
bun /home/glats/.local/opencode-v2/tmp/opencode/organic-runner-3983/run.ts \
  --execute \
  /home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-live-rog/login.ibv0_799/controller-preflight7.json \
  /home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-live-rog/login.ibv0_799/control-preflight7-public.jsonl
```

The same native `{ client, location }` helper is bound to owned preflight 7 without `Service.ensure` or another host. The parent driver must revalidate and execute promptly inside this finite lease, opening its gate only once and preserving the single process/Location/20-20 ledger through all live stages and actual consent boundaries. The worker leaves this leased server alive for that handoff. **Status: PASS_READY_FOR_CORRECTED_PARENT_ATTEMPT. The corrected model attempt remains unspent: no session, prompt, provider generation or MCP tool call occurred here; no additional permission or login is requested.**

### Subsequent preflight-7 live-controller stop

The lifecycle completion notification subsequently reported `PRIVATE_LIVE_WATCHDOG_STARTED`, followed by `PRIVATE_NATIVE_EXIT -9` and `PRIVATE_CONTROLLER_STOPPED`. Public ownership metadata records live deadline **`1791601648.5794408`** Unix seconds and the launch gate is now **present**. Owned-group metadata verification confirms **zero remaining members** of PGID `857799`; the earlier readiness PASS is therefore historical, not a current live-controller handoff.

The last emitted public guard snapshot remains `0/0`, `stopped: false`, `deadline: null`. That snapshot alone does not independently audit subsequent parent runner/session activity or establish whether the corrected model attempt was consumed. The parent must reconcile actual runner receipts and failure outcome before making that determination. This worker did not remove or archive the current gate, reset records, inspect account data, retry the runner or launch a replacement. This completion establishes a stopped owned server, not the exact termination trigger or an automatic-restart authorization.

## Preflight 8: PASS for the native-equivalence and binding-order corrected runner

The parent subsequently reconciled its earlier metadata-only failures as zero-message/zero-provider-HTTP preparations and instructed one new preparation under the still-unspent corrected-model authorization 4046. The parent's offline native omitted/default-variant equivalence correction and metadata-before-gate correction are reflected in the verified runner hash **`111d648fc8c1aa23f4e1e22774d9f19879542408e0d488fdc304d2d8926e0a51`**. The actual runner source was read: it now creates and validates its parent metadata under the closed preflight gate, verifies the zero ledger again, and only then opens the live gate. This worker did not create a parent or exercise that runner path.

Before startup, prior group `857799` was verified empty and its lease expired. All previous records were preserved; the prior gate was renamed without changing its bytes to **`parent-launch-authorized-preflight7-archived`**, SHA256 **`5ed184fdbc3a76e3d15e52e478cdb76dbe17b10a12b2bc4b4dfa48ebf9ffb583`**. `preflight8-init-public.json` records this explicit new metadata-preparation boundary rather than claiming continued process/budget proof. The current gate was absent. Only existing private lifecycle/helper/staged-checker record bindings were advanced to preflight 8; no provider/model/grant/guard/account/database/runner source was changed.

One owned server startup and **one** instrumented readiness execution returned **`PASS_METADATA_ONLY`**, exit 0, at **`2026-10-10T03:19:00.344Z`**. Every named readiness predicate passed: native same-owner opaque capability connection; OpenAI **1 saved / 1 OAuth**; **22 agents**, all **eight steps**; configured parent **`openai/gpt-6.1-sol`** and worker **`openai/gpt-5.6-luna`**, with absent native configured variants preserved; HTTP; **93 active plugins**, guard last external; genuine fixed guard marker; all seven MCP servers connected. Five recorded connected/pending-only startup snapshots transitioned to steady connected through the existing fixed-30-second bounded metadata barrier. There was no failed API retry, MCP tool call, provider probe, fallback or second startup.

The live handoff is native PID/PGID **`885541`**, watchdog **`885540`**, endpoint **`http://127.0.0.1:48055`**, unchanged sole private Location `login.ibv0_799/project`, preflight expiry **`1791603231.4084024`** Unix seconds. At final independent ownership/source/counter verification, approximately **872 seconds** remained. Parent launch gate **absent**, watchdog live deadline **`null`**, public ledger **0 preparations / 0 HTTP admissions**, `stopped: false`, guard deadline **`null`**. Independent 20/20 ceilings, 8192-token setting, eight-step limits, no retry/WebSocket fallback and fixed 900-second live bounds remain unchanged. The immutable guard's prior type/pure-hook/watchdog/suffix evidence applies to its unchanged source; actual runtime readiness was freshly checked here.

Strict staged-checker and whole-current-runner TypeScript checks pass after rebinding; pure diagnostic tests pass. All **31 source entries** match final `12d82f…` before/after; private structural comparison again preserves models, grants, methods and other fields apart from the previously authorized 16 step caps. Guard SHA remains **`f3d8e6e78f08ea8325f96072908c89cc58a5f804ea0c9d902cd212383f9e9466`**. Public receipts are **`preflight8-ready-public.json`** and **`preflight8-staged-diagnostic-public.json`**; the helper returns the actual pinned native `{ client, location }` bound to **`controller-preflight8.json`** without `Service.ensure` or another server.

The parent's next foreground command, **not executed by this worker**, is:

```sh
bun /home/glats/.local/opencode-v2/tmp/opencode/organic-runner-3983/run.ts \
  --execute \
  /home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-live-rog/login.ibv0_799/controller-preflight8.json \
  /home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-live-rog/login.ibv0_799/control-preflight8-public.jsonl
```

This server is left alive under its finite lease for prompt parent execution and revalidation. The driver owns its metadata preparation and one-time live gate; all resulting prompts/child/auxiliary requests must share this process/Location/ledger/deadline and stop at actual error or consent boundaries. No session, prompt, model request, provider generation, MCP tool call, new permission question or OAuth login occurred here. **Status: PASS_READY_FOR_CORRECTED_PARENT_ATTEMPT; corrected model attempt remains unspent.**

## October 13 — new cycle 4066: preflight 9 stopped at missing pinned launcher

The parent reports that preflight 8 subsequently consumed authorization 4046 with one prompt and ten actual preparation/HTTP admissions, ending in `STOP_NO_RETRY/native_operation_failed`. Its previous readiness/unspent statements were timestamped pre-launch evidence, not the final cycle outcome. The user explicitly approved a **new** bounded cycle under **4066** after offline telemetry correction 4064; this preparation does not retry or reset consumed 4046. The latest runner README was read and its hash verified as **`350623344a906c5fe3f9a862d803dff7a6e4c8116a47178d0a91690906bb2c71`**. Strict staged-checker and whole-current-runner TypeScript checks and pure diagnostic tests passed before startup.

Old native PID `885541`, watchdog `885540` and the old owned group were verified absent/empty, with lease expired. All prior owner/counter/attempt records were preserved. The previous launch gate was renamed byte-identically to **`parent-launch-authorized-preflight8-attempt4046-archived`**, SHA256 **`96a71418fecd9751db2410c440c8225988be372c1048dbbcc0e3c1b44ba6eaa3`**; the preserved old public-ledger hash is **`8731ef59f83efa0abb72bf6ac602457208910cf5cffae02d19921041f744a814`**. `preflight9-init-public.json` records the separately authorized boundary. Only the existing private lifecycle mode and helper/staged record bindings were advanced to 9. The current launch gate remained absent.

The **single** controlled startup failed at **`owned_native_process_spawn`**, before any native controller or watchdog child was established: Python `subprocess.Popen` raised **`FileNotFoundError`, errno `2`**, naming the pinned launcher **`/nix/store/3khlkav73hhzg98kw6m37mi4svsg5shz-gentle-v4-private-login/bin/opencode-private`**. Independent filesystem metadata confirms that both this launcher and its containing store output are absent, while the private project directory exists. Why that store output disappeared is not established; garbage collection is not asserted as fact.

No `controller-preflight9.json` or `control-preflight9-public.jsonl` was created. The staged native readiness operation was **not executed**. Native API calls, sessions, prompts, provider HTTP admissions and MCP tool calls are all **zero** for this preparation, and the gate remains absent. No runtime OAuth/catalog/agent/plugin/MCP readiness is certified for preflight 9; this startup failure says nothing about account persistence or entitlement and does not justify another login. No alternate launcher, rebuild, automatic startup retry or fallback was attempted. No process was signalled and no account/database/credential/production log was inspected or copied.

Receipt: **`preflight9-startup-stop-public.json`**. All 31 owned source entries match final `12d82f…` before/after; the guard and runner were not modified. **Status: STOP_STARTUP_LAUNCHER_MISSING, not ready for parent execution. New cycle 4066 has not made a model request; historical consumed 4046 remains preserved.** The next prerequisite is recovery of the exact pinned private launcher through a separately scoped action, not a paid retry or an unverified binary substitution.

## Exact launcher recovery and preflight 10: PASS for new cycle 4066

Under the explicit recovery/build instruction, the saved **`candidate.nix`** was read and evaluated unchanged. It resolves to the **exact original** output `/nix/store/3khlkav73hhzg98kw6m37mi4svsg5shz-gentle-v4-private-login`; no scratch Nix expression rewrite, alternate binary, version upgrade or production activation was needed. Its SHA256 remains `d66f56cccc5030137b45453d944b6624f8278275d06ed1c3a3c548403650cd8e`. The actual realization command was:

```sh
nix build --impure --no-write-lock-file \
  --out-link /home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-live-rog/login.ibv0_799/private-launcher-result \
  --expr '(import /home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-live-rog/login.ibv0_799/candidate.nix).launcher'
```

The first build-client invocation hit the tool's 120-second timeout while realizing the exact dependencies; repeating the same realization with a 600-second tool timeout completed successfully. This was Nix build recovery, not a native API/provider retry or another model attempt. The scratch Nix out-link **`private-launcher-result`** now retains the exact restored closure. The compiled launcher's actual `--version` prints **`opencode v2.0.14`**. The native output `08ck…`, SDK output `dals…`, Gentle managed output `nljdip…`, private HOME/runtime root and `openai-medium` profile match saved **`metadata-final.json`**. No rendered configuration was copied over the private account state, no database/credential was read or copied, and no service was activated. The restoration receipt is **`launcher-restoration-public.json`**.

Preflight 9's failed startup receipt and all consumed-4046 records remain preserved. A separate public-record namespace **preflight 10** was prepared for one metadata-only startup after recovery. The existing private control parser was minimally corrected to parse the whole numeric suffix instead of its last character, so label `fresh-preflight10` cannot accidentally reuse `controller.json`; its pure label check and synthetic owned-group watchdog test pass. Strict staged-checker and whole-current-runner typechecks and pure diagnostic tests pass after binding the helper/checker to preflight 10. No guard, runner, model, grant or account configuration changed.

One owned native startup and **one** staged readiness operation returned **`PASS_METADATA_ONLY`**, exit 0, at **`2026-10-13T13:12:04.235Z`**. Actual normal native metadata confirms **1 saved OpenAI / 1 OAuth connection**, **22 agents at eight steps**, configured parent **`openai/gpt-6.1-sol`** and worker **`openai/gpt-5.6-luna`** without configured variants, private HTTP, **93 active plugins**, guard last external, genuine fixed control marker and all **seven MCP servers connected**. Five connected/pending-only startup snapshots passed through the existing fixed-30-second bounded metadata barrier; no failed API call or provider request was retried. OAuth/catalog routing metadata is not proof of generation entitlement.

The fresh owned controller is native PID/PGID **`54132`**, watchdog PID **`54128`**, endpoint **`http://127.0.0.1:34263`**, unchanged Location `login.ibv0_799/project`, finite preflight expiry **`1791898011.9586394`** Unix seconds. Approximately **861 seconds** remained at final independent source/config/ownership/counter verification. The launch gate is **absent**, live watchdog deadline **`null`**, ledger **0 preparations / 0 HTTP admissions**, `stopped: false`, guard deadline **`null`**. Independent 20/20, 8192-token, eight-step and once-latched 900-second live bounds remain installed; no setup or paid deadline was extended.

All **31 owned source entries** match final `12d82f…` before/after; structural private-config comparison again differs from the retained original only by the approved 16 step caps. Current runner SHA remains **`350623344a906c5fe3f9a862d803dff7a6e4c8116a47178d0a91690906bb2c71`**; guard SHA remains **`f3d8e6e78f08ea8325f96072908c89cc58a5f804ea0c9d902cd212383f9e9466`**. Receipts are **`preflight10-staged-diagnostic-public.json`** and **`preflight10-ready-public.json`**. The actual native helper now binds **`controller-preflight10.json`** without `Service.ensure` or another host.

The parent's next foreground command, **not executed here**, is:

```sh
bun /home/glats/.local/opencode-v2/tmp/opencode/organic-runner-3983/run.ts \
  --execute \
  /home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-live-rog/login.ibv0_799/controller-preflight10.json \
  /home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-live-rog/login.ibv0_799/control-preflight10-public.jsonl
```

The server is left alive under its finite lease for prompt parent revalidation/execution. All subsequent parent/child/auxiliary requests must use this single process/Location/ledger and fixed live deadline, with no provider retries, fallback, account/model substitution, activation or Git delivery. Stop at actual errors and native consent boundaries. **Status: PASS_READY_FOR_NEW_CYCLE_4066. No session, prompt, generation or MCP tool call occurred in this recovery/preparation; new cycle 4066 remains unspent and consumed 4046 is not reclassified or reset.**

### Subsequent cycle-4066 admissions and preflight-10 owned-server stop

The lifecycle completion subsequently reported live-watchdog start, a monotonic public ledger reaching **16 preparations / 16 model HTTP admissions**, and finally `PRIVATE_NATIVE_EXIT -9` / `PRIVATE_CONTROLLER_STOPPED`. Public ownership metadata records live watchdog deadline **`1791898185.128901`** Unix seconds; the guard's fixed deadline is **`1791898185408`** milliseconds. The parent launch gate is now **present**, and owned-group metadata verification confirms **zero remaining members** of PGID `54132`.

Authorization 4066 is therefore no longer an unspent model cycle: actual middleware admissions occurred after this worker's timestamped zero-admission handoff. These admissions establish neither successful provider responses nor organic-stage completion. The last emitted `stopped: false` is not a current sticky-state proof; the owned server has stopped. The completion alone does not identify whether the external deadline, explicit stop file or another termination condition caused shutdown, nor which runner stage succeeded or failed. The parent must reconcile its actual runner telemetry/receipts and stage evidence. This worker did not retry, reset the ledger/deadlines, remove/archive the current gate or start a replacement. No continuation or fresh cycle is authorized by unused space below the 20/20 ceilings.

## Cycle 4084: fresh preflight 11 PASS after offline driver corrections

The parent subsequently diagnosed consumed cycle 4066's readback failure as reuse of an expired 30-second driver `AbortSignal`, not a demonstrated native crash. Its README records that the original owned server/listener remained alive during diagnosis and was explicitly closed through its owned stop protocol afterward. The offline fresh-signal/original-deadline fix and three acceptance fixes were followed by scoped independent PASS; the user explicitly approved a **new** cycle **4084**. This preparation preserves consumed-4066 history and is not an automatic model retry or extension of its deadline.

Before the new lease began, the latest README was read, runner SHA **`debc37d433517461f59b14fa2b6eb66b745d7065f4ab36243218ceaa18bc73c6`** verified, and strict staged-checker plus whole-runner TypeScript checks and all **eight pure runner suites** passed. Proof SHA is **`13c5bc6a4ac3ff431859bdde7e494a2d353deaa0c856d672b2745d3206863522`**. These are offline regression proofs, not organic completion evidence. The exact retained private launcher exists and prints **`opencode v2.0.14`**; no rebuild, binary substitution or activation was needed.

Old PGID `54132` was verified empty and its owned stop file present. Its gate was renamed byte-identically to **`parent-launch-authorized-preflight10-attempt4066-archived`**, SHA256 **`2ee9ca99f9ee2cd1735de27bbd9d3a176f2bac5b5bb733994b89093589eadd4e`**. Its preserved ledger SHA is **`dd9ac5e80b9b59e279aebf1fc79c3c6d518ff78b98411dcf84ef1eb9bad79136`**. All previous receipts remain intact. **`preflight11-init-public.json`** records the explicit new-authority boundary; only existing private lifecycle mode/helper/staged record bindings were advanced to 11.

One owned native startup and **one** instrumented metadata readiness operation returned **`PASS_METADATA_ONLY`**, exit 0, at **`2026-10-13T14:58:25.424Z`**. Every predicate passed: normal opaque same-owner authentication, OpenAI **1 saved / 1 OAuth**, **22 agents at eight steps**, configured parent **`openai/gpt-6.1-sol`** and worker **`openai/gpt-5.6-luna`** with absent configured variants preserved, private HTTP, **93 active plugins**, guard last external, genuine fixed control marker, and all **seven MCP servers connected**. Five pending-only startup snapshots transitioned through the unchanged bounded metadata barrier; no failed API operation, MCP reconnect or provider request was retried.

The handoff is native PID/PGID **`150468`**, watchdog PID **`150466`**, endpoint **`http://127.0.0.1:47709`**, sole unchanged private Location `login.ibv0_799/project`, finite preflight expiry **`1791904393.127821`** Unix seconds. Approximately **860 seconds** remained at final independent verification. Gate **absent**, live watchdog deadline **`null`**, ledger **0 preparations / 0 HTTP admissions**, `stopped: false`, guard deadline **`null`**. The existing 20/20, 8192-token, eight-step, no-retry/fallback and once-latched 900-second live bounds remain unchanged. No native entitlement or paid compatibility probe was performed.

All 31 owned source entries match final `12d82f…` before/after; private structural configuration comparison again preserves all fields except the previously approved 16 step caps. Guard SHA remains **`f3d8e6e78f08ea8325f96072908c89cc58a5f804ea0c9d902cd212383f9e9466`**. Public receipts are **`preflight11-staged-diagnostic-public.json`** and **`preflight11-ready-public.json`**. Normal native capability/account use remained opaque: no SQL, token, account identity, raw headers, database copy or production log access occurred.

The parent's next foreground command, **not executed here**, is:

```sh
bun /home/glats/.local/opencode-v2/tmp/opencode/organic-runner-3983/run.ts \
  --execute \
  /home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-live-rog/login.ibv0_799/controller-preflight11.json \
  /home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-live-rog/login.ibv0_799/control-preflight11-public.jsonl
```

The native helper binds owned preflight 11 without `Service.ensure` or another host. The server is left alive under its finite lease for prompt parent revalidation/execution; the parent validates its metadata binding before opening the one-time gate. All subsequent work must preserve this one process/Location/ledger and original live deadline, and stop at actual errors or consent boundaries without automatic provider retry, fallback, activation or Git delivery. **Status: PASS_READY_FOR_NEW_CYCLE_4084. No session, prompt, generation or MCP tool call occurred here; new authorization 4084 remains unspent.**

### Subsequent cycle-4084 admissions and preflight-11 owned-server stop

The controller completion subsequently reported live-watchdog start, monotonic admissions reaching **4 preparations / 4 model HTTP admissions**, then `PRIVATE_NATIVE_EXIT -9` / `PRIVATE_CONTROLLER_STOPPED`. Public ownership metadata records live watchdog deadline **`1791904548.9551477`** Unix seconds and guard deadline **`1791904549267`** milliseconds. The launch gate is now **present**; owned-group metadata verification confirms **zero remaining members** of PGID `150468`. The earlier readiness PASS is historical, not a current live-controller handoff, and authorization 4084 is no longer an unspent model cycle.

Admissions do not establish successful provider responses, actual prompt count or organic-stage completion. The last emitted `stopped: false` is not current sticky-state proof. Completion alone does not identify the shutdown trigger or distinguish an explicit owned stop from deadline termination; the parent must reconcile actual runner telemetry/receipts and stage evidence. No ledger/deadline reset, gate change, retry, replacement or additional model call was performed by this lifecycle worker. Remaining capacity below 20/20 does not authorize a continuation or fresh cycle.

## Cycle 4102: corrected Engram read gate and fresh preflight 12 PASS

The user explicitly authorized verification of the corrected private Engram scope through **model-free normal MCP discovery/search**, followed by one new bounded cycle only after that gate passes. Consumed cycle 4084's account/memory failure and four-admission history are not reset or reclassified. The private configuration already supplied by the parent sets Engram cwd `/home/glats/.nixos`, canonical `ENGRAM_DATA_DIR=/home/glats/.engram`, and `ENGRAM_CLOUD_AUTOSYNC=0`, while provider HOME and all account/database roots remain private. This worker did not change that configuration or inspect any database, token, account identity or raw authentication header.

### Actual model-free Engram gate

The pinned 2.0.14 Promise client declaration exposes MCP list/add/remove/connect/disconnect/resource catalog but **no model-free MCP tool-call endpoint** (`generated/client.d.ts:128–137`). No endpoint was invented and no SDK host or model session was initialized. Instead, the explicitly permitted direct-stdio alternative used the **same configured command, cwd and environment**, including private HOME and the corrected canonical Engram store, and executable `/etc/profiles/per-user/glats/bin/engram`. Public MCP server source was consulted for the standard stdio tool envelope and empty-search format; actual runtime `tools/list` discovered and validated the required input schemas before invocation.

Exactly **two** real, read-only MCP tool calls were made: `mem_current_project` returned **`nixos-hosts`**, then `mem_search` used that exact discovered project, limit 1 and a fresh unpredictable UUID query. The second call returned a semantic-success empty search bound to the same project. Both the MCP error flag and semantic error envelopes were checked; no arbitrary memory text, user account identity, headers or token was printed or retained. Only allowed booleans/counts and the stable project identity were saved. The separate MCP test child was closed; it was not a model agent or native OpenCode host. Receipt: **`preflight12-engram-read-gate-public.json`**, status **`PASS_ENGRAM_MODEL_FREE_READ_GATE`**. This gate establishes corrected read-side project/store accessibility, **not** native organic Code Mode execution, write/mirror/recovery proof or model entitlement.

### New owned controller and readiness

Before startup, prior PGID `150468` was verified empty and its owned stop file present. Previous records were preserved; the prior gate was renamed byte-identically to **`parent-launch-authorized-preflight11-attempt4084-archived`**, SHA256 **`e17056148b65dff6a39b24e97f5847f37eb9fed3478ba2084e62fee93209d7a2`**. Its old ledger SHA is **`7eea67733331646d490531f20b68d36ec05fd1e6200071ac55e3ab0ff4a9cdf3`**. **`preflight12-init-public.json`** records the explicit new authority and prior gate preservation. Only the existing private lifecycle/helper/staged-checker record bindings were advanced to 12.

Actual current hashes were verified rather than relying on the stale historical `offline-ready.json`: runner **`e15298ea6cdb7b8f62e1815fe121a777307bd15c581a228472b37ebf8b3037ee`**, private config **`7541422a031ed45c45a3417c9591a634be47700bab5274156493a4b2f2a86d62`**, and already-approved safe-error-journal guard **`a45e31988a1c407f58798e92d3e9f84796a7bc17da1a4fa32c6a4f5675665421`**. The guard was not edited by this worker. Strict staged-checker and whole-runner TypeScript checks and all **ten pure runner suites** passed **before** the finite lease started. These offline checks are not organic stage receipts.

After the actual Engram gate PASS, **one** owned startup and **one** staged native readiness operation returned **`PASS_METADATA_ONLY`**, exit 0, at **`2026-10-13T17:09:54.198Z`**. Every predicate passed: opaque same-owner native connection, OpenAI **1 saved / 1 OAuth**, **22 agents at eight steps**, configured parent **`openai/gpt-6.1-sol`** and worker **`openai/gpt-5.6-luna`**, private HTTP, **93 active plugins**, guard last external, genuine fixed control marker and all **seven MCP servers connected**. Six connected/pending-only startup snapshots passed through the unchanged bounded metadata barrier; no failed API/tool/provider call was retried.

Current native PID/PGID is **`272586`**, watchdog PID **`272579`**, endpoint **`http://127.0.0.1:43043`**, sole unchanged private Location `login.ibv0_799/project`, finite preflight expiry **`1791912280.0401082`** Unix seconds. Approximately **852 seconds** remained at final independent verification. Parent launch gate **absent**, watchdog live deadline **`null`**, guard ledger **0 preparations / 0 HTTP admissions**, `stopped: false`, guard deadline **`null`**. The approved 20/20, 8192-token, eight-step and once-latched 900-second live bounds remain in force. No paid compatibility/entitlement probe was performed.

All **31 owned source entries** match final `12d82f…` before/after. Structural private-config comparison confirms only the approved 16 step caps and the three explicit Engram cwd/store/autosync changes differ from the retained original; all provider roots, methods, models and grants remain unchanged. The exact private launcher remains retained by its scratch Nix out-link. Receipts: **`preflight12-staged-diagnostic-public.json`** and **`preflight12-ready-public.json`**. The real native helper binds **`controller-preflight12.json`** without `Service.ensure` or another host.

The parent's next foreground command, **not executed by this lifecycle worker**, is:

```sh
bun /home/glats/.local/opencode-v2/tmp/opencode/organic-runner-3983/run.ts \
  --execute \
  /home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-live-rog/login.ibv0_799/controller-preflight12.json \
  /home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-live-rog/login.ibv0_799/control-preflight12-public.jsonl
```

The finite leased server is left alive for prompt parent revalidation/execution. The parent binds metadata before its one-time launch gate; all subsequent parent/worker/auxiliary work must share this process/Location/ledger/original live deadline and stop at actual errors or consent without automatic retries, fallback, activation or Git delivery. **Status: PASS_ENGRAM_GATE_AND_NATIVE_READY_FOR_NEW_CYCLE_4102. Exactly two authorized model-free MCP read calls occurred; no session, prompt, provider generation or model HTTP admission occurred here. New cycle 4102 remains unspent.**

### Subsequent cycle-4102 admissions and preflight-12 owned-server stop

The controller completion subsequently reported live-watchdog start and monotonic admissions reaching **7 preparations / 7 model HTTP admissions**, followed by `PRIVATE_NATIVE_EXIT -9` / `PRIVATE_CONTROLLER_STOPPED`. Public owner metadata records live watchdog deadline **`1791912474.054886`** Unix seconds and guard deadline **`1791912474304`** milliseconds. The launch gate is now **present**; owned-group metadata verification confirms **zero remaining members** of PGID `272586`. The readiness and model-free Engram gate PASS remain historical evidence, not current controller availability. Cycle 4102 is no longer unspent.

Admission counts do not establish successful provider responses, prompt count, native Code Mode/MCP success or organic-stage completion. The last emitted `stopped: false` is not current sticky-state proof. The notification alone does not identify which runner stage failed or succeeded or whether explicit owned cleanup, deadline termination or another condition caused shutdown. The parent must reconcile actual runner telemetry/receipts before classifying the outcome. This worker preserved the gate/ledger/deadlines and performed no retry, replacement, additional model call or reset. Unused 20/20 capacity does not authorize continuation.

## Cycle 4116: fresh-fixture prompt correction and preflight 13 PASS

The user explicitly authorized one new cycle **4116** after consumed 4102. The parent's post-run diagnosis identifies that cycle's foreground worker failure as reads of absent fresh-fixture files; its offline initial-prompt/TDD-handoff correction is recorded in **`fresh-fixture-prompt-offline-ready.json`**. That artifact was read and actual runner/proof/guard/config hashes matched before preparation. No synthetic files were seeded by this worker and no implementation was executed. Strict staged-checker and whole-runner checks plus all **eleven pure runner suites**, including `fresh-fixture-prompt.test.ts`, passed **before** the new finite lease began. Those checks are not model compliance or organic completion evidence.

The corrected normal model-free Engram gate was repeated **once**, using the same configured stdio command/environment/cwd, canonical `/home/glats/.engram`, cloud autosync off and private provider HOME. Runtime tool-schema discovery preceded exactly **two** read calls: current-project discovery returned **`nixos-hosts`**, and a unique random scoped search returned zero results with semantic success. No raw memory content, account identity, header, token, database read/copy or model request occurred. Receipt: **`preflight13-engram-read-gate-public.json`**, `PASS_ENGRAM_MODEL_FREE_READ_GATE`. This is not native organic Code Mode/write/mirror/recovery proof.

Old owned groups `272586` / `272579` were verified empty and the old stop file present. All previous records were preserved. The prior consumed-cycle gate was renamed byte-identically to **`parent-launch-authorized-preflight12-attempt4102-archived`**, SHA **`d490c52e6f54996f697f854152d228e064329c28660de904a8f21d8f86ce5344`**; old ledger SHA is **`f875fbd4e52d0ffb476c629319270eab7950dbdd027e180d2ab16d68a29f3d9d`**. **`preflight13-init-public.json`** records the explicit new-cycle boundary. Only existing private lifecycle/helper/staged/gate receipt bindings advanced to 13; no provider/agent/grant/guard/configuration source was changed.

One controlled startup and **one** instrumented metadata operation returned **`PASS_METADATA_ONLY`**, exit 0, at **`2026-10-13T17:49:03.569Z`**. Actual checks pass for opaque same-owner authentication, OpenAI **1 saved / 1 OAuth**, **22 agents at eight steps**, parent **`openai/gpt-6.1-sol`**, worker **`openai/gpt-5.6-luna`**, private HTTP, **93 active plugins**, guard last external, genuine fixed control marker and all **seven MCP servers connected**. Five connected/pending-only startup snapshots transitioned through the existing bounded barrier without failed API/provider retries or another startup.

Owned native PID/PGID **`310023`**, watchdog **`310022`**, endpoint **`http://127.0.0.1:59731`**, unchanged sole private Location `login.ibv0_799/project`, finite preflight expiry **`1791914633.2171981`** Unix seconds. Approximately **869 seconds** remained at final independent ownership/counter/source/hash verification. Gate **absent**, watchdog live deadline **`null`**, guard ledger **0 preparations / 0 HTTP admissions**, `stopped: false`, guard deadline **`null`**. The exact retained launcher prints CLI **2.0.14**; no build, activation or binary fallback was required. Native 20/20, 8192-token, eight-step and fixed once-latched 900-second live bounds remain in force.

All 31 source entries match final `12d82f…` before/after. Runner SHA **`20e1c60a6d5cf1f0f578e5ca9f9eac94c6a64b6b0fadebe509bf0c1d046983f3`**, proof SHA **`24c76bbb1a8e627edd35c9fff761791957a0461ba44f55e2b945192d2778c355`**, guard SHA **`a45e31988a1c407f58798e92d3e9f84796a7bc17da1a4fa32c6a4f5675665421`**, private config SHA **`7541422a031ed45c45a3417c9591a634be47700bab5274156493a4b2f2a86d62`** all remain matched to the offline artifact. Fresh receipts: **`preflight13-staged-diagnostic-public.json`** and **`preflight13-ready-public.json`**. The actual helper binds **`controller-preflight13.json`** without `Service.ensure` or another host.

The parent's next foreground command, **not executed here**, is:

```sh
bun /home/glats/.local/opencode-v2/tmp/opencode/organic-runner-3983/run.ts \
  --execute \
  /home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-live-rog/login.ibv0_799/controller-preflight13.json \
  /home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-live-rog/login.ibv0_799/control-preflight13-public.jsonl
```

This owned server is left alive under its finite lease for prompt parent revalidation/execution. The parent alone creates metadata and its one-time launch gate; subsequent work shares this process/Location/ledger/original live deadline and stops at actual failure or native consent, without provider retry, fallback, activation or Git delivery. **Status: PASS_ENGRAM_GATE_AND_NATIVE_READY_FOR_NEW_CYCLE_4116. Exactly two authorized model-free MCP read calls occurred; no session, prompt, generation or provider HTTP admission occurred here. New cycle 4116 remains unspent.**

### Subsequent cycle-4116 admissions and preflight-13 owned-server stop

The controller completion subsequently reported live-watchdog start and monotonic admissions reaching **14 preparations / 14 model HTTP admissions**, followed by `PRIVATE_NATIVE_EXIT -9` / `PRIVATE_CONTROLLER_STOPPED`. Public ownership records live watchdog deadline **`1791914777.8821206`** Unix seconds and guard deadline **`1791914778179`** milliseconds. The launch gate is now **present**; owned-group metadata verification confirms **zero remaining members** of PGID `310023`. The previous readiness PASS is historical rather than a current live-controller handoff, and cycle 4116 is no longer unspent.

Admission counts do not establish provider-response success, prompt count, native worker/tool/MCP success or organic-stage completion. The last emitted `stopped: false` is not current sticky-state proof. Completion alone does not identify the shutdown trigger or the runner stage outcome; the parent must reconcile actual telemetry/receipts and native evidence before classifying the result. This lifecycle worker did not change the gate, ledger or deadlines, retry, launch a replacement or make any model call. Unused capacity below 20/20 does not authorize continuation or a fresh cycle.

## Cycle 4128: setup-batching prompt correction and preflight 14 PASS

The user explicitly approved one new cycle **4128** after consumed 4116. The parent reports genuine prior foreground worker lineage and assertion RED, but no GREEN before the unchanged eight-step limit. The offline setup-batching correction is recorded in **`scheduling-prompt-offline-ready.json`**; this artifact was read and its current runner/proof/guard/private-config hashes verified. No step, token, admission or deadline cap was enlarged and no fixture was preseeded. Strict staged-checker and whole-runner TypeScript checks plus all **eleven pure runner suites** passed **before** the new lease. Offline scheduling proof is not model-compliance or organic completion proof.

The configured canonical Engram model-free read gate was repeated **once** before any model work, with actual tool-schema discovery and exactly **two** read calls: current project **`nixos-hosts`**, then unique random project-scoped search with zero results and semantic success. Private provider HOME, canonical store/cwd and cloud-autosync-off configuration remain unchanged. No SQL/database copy, unrelated observation read, account identity, token, header or raw environment output occurred. Receipt: **`preflight14-engram-read-gate-public.json`**. This direct configured-stdio gate is not native organic Code Mode/write/mirror proof.

Prior native/watchdog groups `310023` / `310022` were verified empty and the prior stop file present. Prior ledger and receipts are preserved. The old gate was renamed byte-identically to **`parent-launch-authorized-preflight13-attempt4116-archived`**, SHA **`bf68ee6b5c7ae8f052623528e72e0b2f4a2d5ef4b2af4c527ab48b586ca2cc0d`**; the preserved ledger SHA is **`a80e266233b889131c4e3ae80b4e4d44cbb59110a6b8c0f82c05d251e71e13e8`**. **`preflight14-init-public.json`** records the explicit new-cycle boundary. Only existing private lifecycle/helper/staged/gate output bindings advanced to 14. No guard, account, provider, grant, model or production source was edited.

One owned startup and **one** instrumented metadata operation returned **`PASS_METADATA_ONLY`**, exit 0, at **`2026-10-13T21:36:18.235Z`**. All predicates passed: opaque same-owner capability use, OpenAI **1 saved / 1 OAuth**, **22 agents at eight steps**, parent **`openai/gpt-6.1-sol`**, worker **`openai/gpt-5.6-luna`**, private HTTP, **93 active plugins**, guard last external, genuine fixed guard marker and all **seven MCP servers connected**. Four connected/pending-only startup snapshots transitioned through the existing bounded metadata barrier; no failed API/provider/tool call was retried.

Native PID/PGID **`512033`**, watchdog **`512032`**, endpoint **`http://127.0.0.1:38837`**, sole unchanged private Location `login.ibv0_799/project`, preflight expiry **`1791928268.235887`** Unix seconds. Approximately **872 seconds** remained at final independent verification. Current gate **absent**, live watchdog deadline **`null`**, ledger **0 preparations / 0 HTTP admissions**, `stopped: false`, guard deadline **`null`**. The approved independent 20/20, 8192-token, eight-step and once-latched 900-second live bounds remain unchanged. Exact retained private CLI 2.0.14/native SDK/Gentle closure remains available; no build, binary substitution or activation was necessary. No model entitlement probe occurred.

All **31 source entries** match final `12d82f…` before/after. Runner SHA **`56e4be61ae3036708e9a6a6417438243b2b722b7b5c808ae99e143973840fd3d`**, proof SHA **`24c76bbb1a8e627edd35c9fff761791957a0461ba44f55e2b945192d2778c355`**, guard SHA **`a45e31988a1c407f58798e92d3e9f84796a7bc17da1a4fa32c6a4f5675665421`**, config SHA **`7541422a031ed45c45a3417c9591a634be47700bab5274156493a4b2f2a86d62`** remain matched to the scheduling artifact. Fresh sanitized receipts are **`preflight14-staged-diagnostic-public.json`** and **`preflight14-ready-public.json`**. The actual helper binds **`controller-preflight14.json`** without `Service.ensure` or another host.

The parent's next foreground command, **not executed here**, is:

```sh
bun /home/glats/.local/opencode-v2/tmp/opencode/organic-runner-3983/run.ts \
  --execute \
  /home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-live-rog/login.ibv0_799/controller-preflight14.json \
  /home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-live-rog/login.ibv0_799/control-preflight14-public.jsonl
```

The finite owned server is left alive for prompt parent revalidation/execution. The parent alone creates metadata and its one-time gate; all subsequent work must share this process/Location/ledger/original live deadline and stop at actual errors or native consent, without automatic provider retry, fallback, activation or publication/delivery. **Status: PASS_ENGRAM_GATE_AND_NATIVE_READY_FOR_NEW_CYCLE_4128. Exactly two authorized model-free MCP read calls occurred; no session, prompt, generation or provider HTTP admission occurred here. New cycle 4128 remains unspent.**

### Subsequent cycle-4128 admissions and preflight-14 owned-server stop

The controller completion subsequently reported live-watchdog start and monotonic admissions reaching **13 preparations / 13 model HTTP admissions**, followed by `PRIVATE_NATIVE_EXIT -9` / `PRIVATE_CONTROLLER_STOPPED`. Public ownership records live watchdog deadline **`1791928386.5408735`** Unix seconds and guard deadline **`1791928386834`** milliseconds. The launch gate is now **present**; owned-group metadata verification confirms **zero remaining members** of PGID `512033`. The readiness PASS is historical rather than current controller availability; cycle 4128 is no longer unspent.

Admission counts do not establish provider-response success, prompt count, worker/tool/MCP success or organic-stage completion. The last emitted `stopped: false` is not current sticky-state proof. The completion does not identify the shutdown trigger or runner stage outcome; the parent must reconcile actual runner telemetry and native receipts. This worker preserved the gate/ledger/deadlines and performed no retry, reset, replacement or model call. Unused capacity below 20/20 does not authorize continuation or a fresh cycle.

## Cycle 4140: worker terminal-scope correction and preflight 15 PASS

The user explicitly authorized one new cycle **4140** after consumed 4128. The parent reports actual TDD success followed by an excluded worker Git-status operation and correct parent stop. The offline terminal-scope correction is recorded in **`terminal-scope-offline-ready.json`**: return immediately after GREEN, no Git/optional closure, and no failure masking. That artifact was read and current runner/proof/guard/config hashes matched before preparation. Strict staged-checker and whole-runner TypeScript checks plus all **eleven pure runner suites** passed **before** the new lease. These remain offline proofs, not native model-compliance or organic completion evidence; no fixture or receipt was fabricated.

The corrected canonical Engram model-free gate was repeated **once**, with runtime tool-schema discovery and exactly **two** read calls: current-project discovery **`nixos-hosts`**, then a random unique scoped search returning zero results with semantic success. Private provider HOME, canonical Engram store/cwd and autosync-off settings remained intact. No direct SQL, account identity, token/header/raw environment output or unrelated observation read occurred. **`preflight15-engram-read-gate-public.json`** records PASS; this configured-stdio gate is not native organic Code Mode/write/mirror proof.

Previous owned native/watchdog groups `512033` / `512032` were verified empty and the old stop file present. Previous receipts and ledger were preserved. The old gate was renamed byte-identically to **`parent-launch-authorized-preflight14-attempt4128-archived`**, SHA **`8c57c32f6a69270ffd941e3f601ca84eeb181ad7c04827c63fd2eff0c9a04ed5`**; old ledger SHA is **`2aac0972024af87dba96f4cbc17f1729e0f31cd5c0012af52f7933bd2bdbea50`**. **`preflight15-init-public.json`** records the explicit new-cycle boundary. Only private lifecycle/helper/staged/gate output bindings advanced to 15; no guard, grants, models, account configuration or production source changed.

One controlled startup and **one** staged metadata operation returned **`PASS_METADATA_ONLY`**, exit 0, at **`2026-10-13T22:03:12.534Z`**. Every predicate passed: opaque same-owner native connection, OpenAI **1 saved / 1 OAuth**, **22 agents at eight steps**, parent **`openai/gpt-6.1-sol`**, worker **`openai/gpt-5.6-luna`**, private HTTP, **93 active plugins**, guard last external, genuine fixed marker and all **seven MCP servers connected**. Five connected/pending-only startup snapshots transitioned through the existing fixed bounded barrier without failed API/provider retries or another startup.

Native PID/PGID **`536812`**, watchdog **`536801`**, endpoint **`http://127.0.0.1:48499`**, unchanged sole private Location `login.ibv0_799/project`, finite preflight expiry **`1791929882.7473278`** Unix seconds. Approximately **873 seconds** remained at final independent verification. Current launch gate **absent**, live watchdog deadline **`null`**, guard ledger **0 preparations / 0 HTTP admissions**, `stopped: false`, guard deadline **`null`**. The approved 20/20, 8192-token, eight-step and once-latched 900-second live bounds remain unchanged. Exact pinned retained private CLI/native SDK/Gentle closure remains available; no rebuild, binary substitution, activation or entitlement probe was needed.

All **31 source entries** match final `12d82f…` before/after. Runner SHA **`f6766b4f55cc51005167e37e203a2b00ef028f04492bd3e471480c69680f8cc0`**, proof SHA **`24c76bbb1a8e627edd35c9fff761791957a0461ba44f55e2b945192d2778c355`**, guard SHA **`a45e31988a1c407f58798e92d3e9f84796a7bc17da1a4fa32c6a4f5675665421`**, config SHA **`7541422a031ed45c45a3417c9591a634be47700bab5274156493a4b2f2a86d62`** match the terminal-scope artifact. Fresh receipts: **`preflight15-staged-diagnostic-public.json`** and **`preflight15-ready-public.json`**. The actual helper binds **`controller-preflight15.json`** without `Service.ensure` or another host.

The parent's next foreground command, **not executed here**, is:

```sh
bun /home/glats/.local/opencode-v2/tmp/opencode/organic-runner-3983/run.ts \
  --execute \
  /home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-live-rog/login.ibv0_799/controller-preflight15.json \
  /home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-live-rog/login.ibv0_799/control-preflight15-public.jsonl
```

The finite owned server is left alive for prompt parent revalidation/execution. Only the parent creates metadata and its one-time gate; subsequent work shares this process/Location/ledger/original live deadline and stops at actual errors or native consent, without automatic provider retry, fallback, activation or publication/delivery. **Status: PASS_ENGRAM_GATE_AND_NATIVE_READY_FOR_NEW_CYCLE_4140. Exactly two authorized model-free MCP read calls occurred; no session, prompt, generation or provider HTTP admission occurred here. New cycle 4140 remains unspent.**

### Subsequent cycle-4140 admissions and preflight-15 owned-server stop

The controller completion subsequently reported live-watchdog start and monotonic admissions reaching **14 preparations / 14 model HTTP admissions**, followed by `PRIVATE_NATIVE_EXIT -9` / `PRIVATE_CONTROLLER_STOPPED`. Public ownership records live watchdog deadline **`1791930000.4501016`** Unix seconds and guard deadline **`1791930000724`** milliseconds. The launch gate is now **present**; owned-group metadata verification confirms **zero remaining members** of PGID `536812`. The readiness PASS is historical rather than current controller availability; cycle 4140 is no longer unspent.

Admission counts do not establish provider-response success, prompt count, worker/tool/MCP success or organic-stage completion. The last emitted `stopped: false` is not current sticky-state proof. Completion alone does not identify the shutdown trigger or runner stage outcome; the parent must reconcile actual runner telemetry and native receipts. This worker preserved the gate/ledger/deadlines and performed no retry, reset, replacement or model call. Unused capacity below 20/20 does not authorize continuation or a fresh cycle.

## Cycle 4161: coherent checkpoint/window correction and preflight 16 PASS

The user explicitly approved one new cycle **4161** after consumed 4140. The parent reports native TDD completion and correct child scope but a parent ordering/window cutoff, followed by offline coherent prewrite/final-checkpoint corrections and independent scoped PASS. **`final-window-offline-ready.json`** was read; actual runner **`d0786b991667edc5f3ba062f0b61d01b8a3ea55ff074fe613843019cb39ae90e`**, proof **`e993807ee04a7c54886b3b243215d2fe741bd4ae6a7dd112e24972177f02e276`**, guard **`a45e31988a1c407f58798e92d3e9f84796a7bc17da1a4fa32c6a4f5675665421`** and config **`7541422a031ed45c45a3417c9591a634be47700bab5274156493a4b2f2a86d62`** matched that artifact. Strict staged-checker/whole-runner checks and all **twelve pure runner suites**, including prewrite checkpoint proof, passed before the new lease. Offline proofs are not native model compliance or organic completion evidence; no fixture, checkpoint or generation was executed by this worker.

The canonical configured Engram model-free gate ran **once**, discovering runtime schemas before exactly **two** read calls: current project **`nixos-hosts`**, then unique random scoped search yielding zero results with semantic success. Private provider HOME, canonical Engram cwd/store and autosync-off settings remain unchanged. No direct database/credential read or copy, token/header/raw environment output or unrelated memory read occurred. **`preflight16-engram-read-gate-public.json`** records PASS; it is not native organic Code Mode/write/mirror/recovery proof.

Previous owned groups `536812` / `536801` were verified empty and the prior owned stop file present. Prior records were preserved. The prior gate was renamed byte-identically to **`parent-launch-authorized-preflight15-attempt4140-archived`**, SHA **`cede75668afd972cdb449c20d76afa461f36cfaa0e7accbf10cb809de12a0135`**; preserved ledger SHA **`a33da26a17d7e225b5da4e0184a918f92e3588ab36406b5a1b8811783daf2f72`**. **`preflight16-init-public.json`** records the explicit new-cycle boundary. Only existing private lifecycle/helper/staged/gate output bindings advanced to 16; no guard, account, grant, model, config or production source was edited.

One controlled startup and **one** staged metadata operation returned **`PASS_METADATA_ONLY`**, exit 0, at **`2026-10-14T00:57:17.505Z`**. All predicates passed: opaque same-owner capability use, OpenAI **1 saved / 1 OAuth**, **22 agents at eight steps**, parent **`openai/gpt-6.1-sol`**, worker **`openai/gpt-5.6-luna`**, private HTTP, **93 active plugins**, guard last external, genuine fixed control marker and all **seven MCP servers connected**. Five connected/pending-only startup snapshots transitioned through the existing bounded barrier; no failed API/provider/tool call was retried.

Native PID/PGID **`695608`**, watchdog **`695607`**, endpoint **`http://127.0.0.1:47029`**, unchanged sole private Location `login.ibv0_799/project`, finite preflight expiry **`1791940327.217574`** Unix seconds. Approximately **873 seconds** remained at final independent source/hash/ownership/counter verification. Current gate **absent**, watchdog live deadline **`null`**, ledger **0 preparations / 0 HTTP admissions**, `stopped: false`, guard deadline **`null`**. The approved 20/20, 8192-token, eight-step and once-latched 900-second live bounds remain unchanged. Exact pinned private CLI/native SDK/Gentle closure remains retained; no rebuild, binary substitution, activation or paid entitlement probe occurred.

All **31 source entries** match final `12d82f…` before/after; the current runner/proof/guard/config hashes still match the final-window artifact. Fresh sanitized receipts: **`preflight16-staged-diagnostic-public.json`** and **`preflight16-ready-public.json`**. The actual native helper binds **`controller-preflight16.json`** without `Service.ensure` or another host.

The parent's next foreground command, **not executed here**, is:

```sh
bun /home/glats/.local/opencode-v2/tmp/opencode/organic-runner-3983/run.ts \
  --execute \
  /home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-live-rog/login.ibv0_799/controller-preflight16.json \
  /home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-live-rog/login.ibv0_799/control-preflight16-public.jsonl
```

The finite owned server is left alive for prompt parent revalidation/execution. The parent alone creates metadata and its one-time gate; subsequent work shares this process/Location/ledger/original live deadline and stops at actual errors or native consent, without automatic provider retry, fallback, activation, commit or push. **Status: PASS_ENGRAM_GATE_AND_NATIVE_READY_FOR_NEW_CYCLE_4161. Exactly two authorized model-free MCP read calls occurred; no session, prompt, generation or provider HTTP admission occurred here. New cycle 4161 remains unspent.**

### Subsequent cycle-4161 admissions and preflight-16 owned-server stop

The controller completion subsequently reported live-watchdog start and monotonic admissions reaching **2 preparations / 2 model HTTP admissions**, followed by `PRIVATE_NATIVE_EXIT -9` / `PRIVATE_CONTROLLER_STOPPED`. Public ownership records live watchdog deadline **`1791940452.5433664`** Unix seconds and guard deadline **`1791940452824`** milliseconds. The launch gate is now **present**; owned-group metadata verification confirms **zero remaining members** of PGID `695608`. The readiness PASS is historical rather than current controller availability; cycle 4161 is no longer unspent.

Admission counts do not establish provider-response success, prompt count, worker/tool/MCP success or organic-stage completion. The last emitted `stopped: false` is not current sticky-state proof. Completion alone does not identify the shutdown trigger or runner stage outcome; the parent must reconcile actual runner telemetry and native receipts. This worker preserved the gate/ledger/deadlines and performed no retry, reset, replacement or model call. Unused capacity below 20/20 does not authorize continuation or a fresh cycle.

## October 14 renewed continuation: preflight 17 PASS

The user's renewed explicit continue-until-completion-or-genuine-stopper instruction authorizes the next **one** bounded isolated cycle under unchanged 20/20, 900-second, eight-step and 8192-token limits, without provider retry/fallback, activation, commit, push or routing changes. Consumed 4161 remains preserved. **`setup-continuation-offline-ready.json`** was read and matched to actual runner **`109db95b1ab8f310d68356c51713381c04af13b98cb7195410032be92ddb4d12`**, proof **`e993807ee04a7c54886b3b243215d2fe741bd4ae6a7dd112e24972177f02e276`**, guard **`a45e31988a1c407f58798e92d3e9f84796a7bc17da1a4fa32c6a4f5675665421`**, config **`7541422a031ed45c45a3417c9591a634be47700bab5274156493a4b2f2a86d62`**. Strict staged-checker/whole-runner checks and all **twelve pure suites** passed before the finite lease began; no native model/organic success is inferred from these offline checks.

Previous groups `695608` / `695607` are OS-verified empty. An initial offline harness assertion incorrectly assumed the previous stop marker must still exist; it failed before any server/API call. Public metadata diagnosis showed the marker absent but both groups empty, matching the parent's prior cleanup evidence. No marker was fabricated, no old PID was signalled and no native failure was retried. OS ownership absence, not a marker-file assumption, is the actual cleanup proof. Previous records were preserved; the prior gate was renamed byte-identically to **`parent-launch-authorized-preflight16-attempt4161-archived`**, SHA **`a07e0523c96101f2921d1b1de9f5bf6e54c25271421bb79d9c5eaffcdec35189`**; old ledger SHA **`d930003f55a0b4672eeb1ddd53f7cd98a10a800ca0f6385c3238c6e1737f50d2`**. **`preflight17-init-public.json`** records the explicit new-cycle boundary. Only existing private lifecycle/helper/staged/read-gate output bindings advanced to 17.

The canonical configured Engram model-free gate ran once: actual runtime schema discovery, current project **`nixos-hosts`**, then random unique scoped search yielding zero results with semantic success. Exactly **two** authorized read calls occurred using the configured private environment/cwd/store; no raw memory, credentials, SQL, account identity or unrelated observation was read/output. **`preflight17-engram-read-gate-public.json`** records PASS. This direct configured-stdio gate is not native organic Code Mode/write/mirror/recovery proof.

One controlled startup and **one** staged native metadata operation returned **`PASS_METADATA_ONLY`**, exit 0, at **`2026-10-14T14:18:08.280Z`**. Every predicate passed: opaque same-owner connection, OpenAI **1 saved / 1 OAuth**, **22 agents at eight steps**, parent **`openai/gpt-6.1-sol`**, worker **`openai/gpt-5.6-luna`**, private HTTP, **93 active plugins**, guard last external, genuine fixed marker and all **seven MCP servers connected**. Five connected/pending-only startup snapshots transitioned through the unchanged bounded barrier; no failed API/provider/tool operation was retried.

Native PID/PGID **`14953`**, watchdog **`14933`**, endpoint **`http://127.0.0.1:54211`**, unchanged sole private Location `login.ibv0_799/project`, finite preflight expiry **`1791988372.3539298`** Unix seconds. Approximately **862 seconds** remained at final independent verification. Gate **absent**, live watchdog deadline **`null`**, guard ledger **0 preparations / 0 HTTP admissions**, `stopped: false`, guard deadline **`null`**. The exact pinned CLI/native SDK/Gentle closure remains retained; no build, substitution, activation or entitlement probe occurred. All **31 source entries** match final `12d82f…` before/after, and current runner/proof/guard/config hashes still match the setup-continuation artifact. Fresh receipts: **`preflight17-staged-diagnostic-public.json`** and **`preflight17-ready-public.json`**; the actual helper binds **`controller-preflight17.json`** without `Service.ensure` or another host.

The parent's next foreground command, **not executed here**, is:

```sh
bun /home/glats/.local/opencode-v2/tmp/opencode/organic-runner-3983/run.ts \
  --execute \
  /home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-live-rog/login.ibv0_799/controller-preflight17.json \
  /home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-live-rog/login.ibv0_799/control-preflight17-public.jsonl
```

The finite owned server is left alive for prompt parent revalidation/execution. The parent alone creates metadata and its one-time gate; subsequent work shares this one process/Location/ledger/original live deadline and stops at actual errors or native consent under the unchanged limits. **Status: PASS_ENGRAM_GATE_AND_NATIVE_READY_FOR_NEXT_OCT14_CYCLE. Exactly two authorized model-free MCP reads occurred; no session, prompt, generation or provider HTTP admission occurred here. The next cycle remains unspent.**

### Subsequent preflight-17 admissions and owned-server stop

The controller completion subsequently reported live-watchdog start and monotonic admissions reaching **2 preparations / 2 model HTTP admissions**, followed by `PRIVATE_NATIVE_EXIT -9` / `PRIVATE_CONTROLLER_STOPPED`. Public ownership records live watchdog deadline **`1791988544.1035154`** Unix seconds and guard deadline **`1791988544343`** milliseconds. The launch gate is now **present**; owned-group metadata verification confirms **zero remaining members** of PGID `14953`. The readiness PASS is historical rather than current controller availability; this bounded cycle is no longer unspent.

Admission counts do not establish provider-response success, prompt count, worker/tool/MCP success or organic-stage completion. The last emitted `stopped: false` is not current sticky-state proof. Completion alone does not identify the shutdown trigger or runner stage outcome; the parent must reconcile actual runner telemetry and native receipts. This worker preserved the gate/ledger/deadlines and performed no retry, reset, replacement or model call. Remaining capacity below 20/20 does not authorize restarting or continuing this stopped cycle. Any next distinct preparation must be separately classified under the user's renewed continuation authority, not presented as resumed live proof.

## Explicit approval 4189: model-free preflight 18 PASS without registry seeding

The user explicitly approved one new cycle **4189** after the canonical main registry refresh. The supplied registry observation/revision/content hash is context for the actual parent's future fresh discovery, not a seeded private cache or a preflight registry certification. This worker made **no registry get**, did not write any registry/session/task/fixture data and did not hardcode observation IDs into the runner. Actual runner **`109db95b1ab8f310d68356c51713381c04af13b98cb7195410032be92ddb4d12`**, proof **`e993807ee04a7c54886b3b243215d2fe741bd4ae6a7dd112e24972177f02e276`**, guard **`a45e31988a1c407f58798e92d3e9f84796a7bc17da1a4fa32c6a4f5675665421`**, config **`7541422a031ed45c45a3417c9591a634be47700bab5274156493a4b2f2a86d62`** matched the current setup-continuation artifact. Strict staged-checker/whole-runner checks and all **twelve pure suites** passed before the finite lease.

Prior owned groups `14953` / `14933` were OS-verified empty. Prior ledger/receipts/deadlines were preserved; the old gate was renamed byte-identically to **`parent-launch-authorized-preflight17-consumed-cycle-archived`**, SHA **`00222d751be2d519f6287e064b4e2e94e49072a371ea76677be7a5684d609e9b`**; old ledger SHA **`00c30ecb09afb3c4b318160371ece0a9525d69ea15df50009c7b0d7b9a6b7207`**. **`preflight18-init-public.json`** records the explicit new-cycle boundary. Only existing private lifecycle/helper/staged/read-gate output bindings advanced to 18; no guard, account, grants, routes, config or production source changed.

The corrected configured Engram model-free gate ran once: actual tool-schema discovery followed by exactly **two** read calls, current project **`nixos-hosts`** and unique random project-scoped search yielding zero results with semantic success. Private HOME and canonical Engram cwd/store/autosync-off settings remain intact. No raw memory contents, registry/canary get, SQL/credential/DB read or copy, token/header/account identity output occurred. **`preflight18-engram-read-gate-public.json`** records PASS; this direct configured-stdio gate is not native organic Code Mode/write/mirror/registry proof.

One controlled startup and **one** staged metadata operation returned **`PASS_METADATA_ONLY`**, exit 0, at **`2026-10-14T15:13:38.828Z`**. All predicates passed: opaque same-owner capability use, OpenAI **1 saved / 1 OAuth**, **22 agents at eight steps**, parent **`openai/gpt-6.1-sol`**, worker **`openai/gpt-5.6-luna`**, private HTTP, **93 active plugins**, guard last external, genuine fixed control marker and all **seven MCP servers connected**. Five connected/pending-only startup snapshots transitioned through the unchanged bounded barrier; no failed API/provider/tool call was retried.

Native PID/PGID **`67747`**, watchdog **`67745`**, endpoint **`http://127.0.0.1:60569`**, unchanged sole private Location `login.ibv0_799/project`, finite preflight expiry **`1791991702.7290468`** Unix seconds. Approximately **862 seconds** remained at final independent verification. Gate **absent**, live watchdog deadline **`null`**, ledger **0 preparations / 0 HTTP admissions**, `stopped: false`, guard deadline **`null`**. The approved 20/20, 8192-token, eight-step and once-latched 900-second bounds remain unchanged. Exact pinned private CLI 2.0.14/native SDK/Gentle closure remains retained; no build, substitution, upgrade, activation or entitlement probe occurred. All **31 source entries** match final `12d82f…` before/after; scoped runner/proof/guard/config pins remain unchanged. Receipts: **`preflight18-staged-diagnostic-public.json`** and **`preflight18-ready-public.json`**. The actual helper binds **`controller-preflight18.json`** without `Service.ensure` or another host.

The parent's next foreground command, **not executed here**, is:

```sh
bun /home/glats/.local/opencode-v2/tmp/opencode/organic-runner-3983/run.ts \
  --execute \
  /home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-live-rog/login.ibv0_799/controller-preflight18.json \
  /home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-live-rog/login.ibv0_799/control-preflight18-public.jsonl
```

The finite owned server is left alive for prompt parent revalidation/execution. The actual parent must still perform fresh project/search/full-get and verified native skill reads, create its own metadata and one-time gate, and preserve this one process/Location/ledger/original live deadline through all subsequent work. Stop at actual error or native consent under unchanged no-retry/fallback/activation/commit/push rules. **Status: PASS_ENGRAM_GATE_AND_NATIVE_READY_FOR_NEW_CYCLE_4189. Exactly two authorized model-free MCP reads occurred; no session, prompt, generation or provider HTTP admission occurred here. New cycle 4189 remains unspent.**

### Subsequent cycle-4189 admissions and preflight-18 owned-server stop

The controller completion subsequently reported live-watchdog start and monotonic admissions reaching **2 preparations / 2 model HTTP admissions**, followed by `PRIVATE_NATIVE_EXIT -9` / `PRIVATE_CONTROLLER_STOPPED`. Public ownership records live watchdog deadline **`1791991895.886117`** Unix seconds and guard deadline **`1791991896148`** milliseconds. The launch gate is now **present**; owned-group metadata verification confirms **zero remaining members** of PGID `67747`. The readiness PASS is historical rather than current controller availability; cycle 4189 is no longer unspent.

Admission counts do not establish provider-response success, prompt count, actual registry full-get/native skill reads, worker/tool/MCP success or organic-stage completion. The last emitted `stopped: false` is not current sticky-state proof. Completion alone does not identify the shutdown trigger or runner stage outcome; the parent must reconcile actual runner telemetry and native receipts. This worker preserved the gate/ledger/deadlines and performed no retry, reset, replacement, registry seeding or model call. Unused capacity below 20/20 does not authorize continuing or restarting this stopped cycle.

## Explicit approval 4206: current bootstrap runner and preflight 19 PASS

The user explicitly approved one new cycle **4206** with structurally reviewed same-parent BOOTSTRAP → TASK → RECOVERY. **`bootstrap-implementation-offline-ready.json`** was read and current runner **`7d2b90dbc7cefe0f51a2919c1ec86396f9d043e8e4759166d6ce6e339906e62d`**, proof **`7a77d3a8f73744b4638e03ddaecc0560fd789fdbb6765b3dd9e2c07ffa822506`**, guard **`a45e31988a1c407f58798e92d3e9f84796a7bc17da1a4fa32c6a4f5675665421`**, config **`7541422a031ed45c45a3417c9591a634be47700bab5274156493a4b2f2a86d62`** verified. The old runner/proof readiness was not reused. Strict staged-checker/whole-runner checks plus all **thirteen pure suites**, including the actual bootstrap-phase caller regression, passed before the finite lease began. These are offline proofs, not organic bootstrap/TDD/recovery success.

Prior groups `67747` / `67745` were OS-verified empty. Original receipts/ledger/deadlines remain unchanged. The old gate was renamed byte-identically to **`parent-launch-authorized-preflight18-attempt4189-archived`**, SHA **`46aeaa00e1517c3416e3b1e8a5155ac8efcf61414117bb8c0b528d85a4da0643`**; old ledger SHA **`88cfc30f17e4b6aa355e81ff1fb2469c93ad6f67358dc5404f92141ca8b4ef43`**. **`preflight19-init-public.json`** records the new-cycle boundary. Only existing private lifecycle/helper/staged/read-gate output bindings advanced to 19. No registry/observation-ID cache, task, fixture or bootstrap content was seeded, and no runner, proof, guard, config, account/grant or product source was edited.

Exactly **two** authorized model-free configured Engram reads followed runtime tool-schema discovery: current project **`nixos-hosts`**, then a fresh unique scoped query returning zero results with semantic success. The canonical cwd/store/autosync-off and private provider HOME remain intact. No registry/canary get, raw memory read/output, credential/DB read/copy, account identity or token/header output occurred. **`preflight19-engram-read-gate-public.json`** records PASS; this direct configured-stdio gate is not native organic Code Mode/registry/write/mirror proof.

One controlled startup and **one** staged metadata operation returned **`PASS_METADATA_ONLY`**, exit 0, at **`2026-10-14T17:16:23.530Z`**. All predicates passed: opaque same-owner capability use, OpenAI **1 saved / 1 OAuth**, **22 agents at eight steps**, parent **`openai/gpt-6.1-sol`**, worker **`openai/gpt-5.6-luna`**, private HTTP, **93 active plugins**, guard last external, genuine fixed control marker and all **seven MCP servers connected**. Five connected/pending-only startup snapshots passed through the unchanged bounded barrier with no failed API/provider/tool retry.

Native PID/PGID **`181201`**, watchdog **`181200`**, endpoint **`http://127.0.0.1:57401`**, unchanged sole private Location `login.ibv0_799/project`, finite preflight expiry **`1791999073.4804752`** Unix seconds. Approximately **870 seconds** remained at final independent verification. Gate **absent**, live watchdog deadline **`null`**, ledger **0 preparations / 0 HTTP admissions**, `stopped: false`, guard deadline **`null`**. The approved 20/20, 8192-token, eight-step and once-latched 900-second limits remain unchanged. Exact pinned CLI/native SDK/Gentle closure remains retained; no build, substitution, upgrade, activation or entitlement probe occurred. All **31 source entries** match final `12d82f…` before/after and current scoped pins remain unchanged. Fresh receipts: **`preflight19-staged-diagnostic-public.json`** and **`preflight19-ready-public.json`**; actual helper binds **`controller-preflight19.json`** without `Service.ensure` or another host.

The parent's next foreground command, **not executed here**, is:

```sh
bun /home/glats/.local/opencode-v2/tmp/opencode/organic-runner-3983/run.ts \
  --execute \
  /home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-live-rog/login.ibv0_799/controller-preflight19.json \
  /home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-live-rog/login.ibv0_799/control-preflight19-public.jsonl
```

The finite server is left alive for prompt parent revalidation/execution. The actual parent must perform organic fresh project/search/full-get and verified native skill reads, admit TASK only after the actual bootstrap evidence gate passes, and retain the same process/parent/Location/ledger/original live deadline for TASK and read-only RECOVERY. No phase-completion or later headroom is guaranteed by metadata readiness. Stop at actual error/native consent without retry/fallback/activation/commit/push. **Status: PASS_ENGRAM_GATE_AND_NATIVE_READY_FOR_NEW_CYCLE_4206. Exactly two authorized model-free MCP reads occurred; no session, prompt, generation or provider HTTP admission occurred here. New cycle 4206 remains unspent.**

### Subsequent cycle-4206 admissions and preflight-19 owned-server stop

The controller completion subsequently reported live-watchdog start and monotonic admissions reaching **8 preparations / 8 model HTTP admissions**, followed by `PRIVATE_NATIVE_EXIT -9` / `PRIVATE_CONTROLLER_STOPPED`. Public ownership records live watchdog deadline **`1791999273.034582`** Unix seconds and guard deadline **`1791999273353`** milliseconds. The launch gate is now **present**; owned-group metadata verification confirms **zero remaining members** of PGID `181201`. The readiness PASS is historical rather than current controller availability; cycle 4206 is no longer unspent.

Admission counts do not establish provider-response success, prompt count, BOOTSTRAP/TASK/RECOVERY progression, actual registry full-get/native skill reads or organic-stage completion. The last emitted `stopped: false` is not current sticky-state proof. Completion alone does not identify the shutdown trigger or runner phase outcome; the parent must reconcile actual runner telemetry and native receipts. This worker preserved the gate/ledger/deadlines and performed no retry, reset, replacement, registry seeding or model call. Unused capacity below 20/20 does not authorize continuing or restarting this stopped cycle.
