# Apply Progress: Retire OpenCode V1

## Status

Current scoped result: rog post-deployment validation PASS (details below). The running system is the exact built candidate, integrated HM activation succeeded, deployed generated config/environment matches that candidate, and a fresh standalone native PONG passed. Earlier timeout and missing-jq blockers are resolved historical evidence. This does not complete composite multi-host tasks: macm5 remains explicitly DEFERRED; thinkcentre/t14 runtime UNVERIFIED. No formal fleet verification/archive claim.

- Artifact store: OpenSpec, as returned by native `gentle-ai sdd-status`.
- Delivery: `exception-ok`; maintainer accepted `size:exception`; chain strategy is `size-exception`. No PRs or commits are part of this apply.
- Native readiness on relaunch: `applyState: ready`; 22 tasks total, 0 completed, 22 pending before this apply. No prior apply-progress locator was reported.
- Current implementation progress: 19/22 tasks checked. Tasks 5.3–5.5 remain partial, not fleet-complete. All Linux/HM evaluations passed; macm5 is explicitly DEFERRED by the user until rog is finished. The authorized rog-only live smoke passed on the installed V2 service through a checkout Go-built launcher; the Nix-built `nixos-scripts` candidate now passes its sandbox test suite, but candidate HM config differs from installed and no activation occurred. Archive metadata was observed with no historical byte-level baseline.
- Relaunch recovery: all six helper source/test files reported before the interruption remain modified, and their then-current diff was saved as `/home/glats/.local/opencode-v2/tmp/opencode/retire-opencode-v1/relaunch-current.diff`. The complete current dirty-diff snapshot was saved before continuation writes. The earlier first snapshot also listed staged `linux/system/services/web/droppy.nix`; it is no longer dirty because current HEAD contains the read-only music mount, and the reflog records `0e23747 feat(droppy): expose music read-only` followed by merge `62a552c`. No missing change was found; that commit was not made by this apply. The initial V1 helper diffs survive. A historical snapshot from before this session was unavailable, so losses outside observable status/reflog/content cannot be ruled out.

## Completed Tasks

- [x] 1.1 Helper-launcher threat tests.
- [x] 1.2 Legacy auth-seed refusal threat tests.
- [x] 1.3 Remote V2 preflight/path/asset-transfer threat tests.
- [x] 1.4 V2-only Home Manager launcher, OpenFang ordering, and MCP isolation regression.
- [x] 2.1–2.4 Retired V1 package derivations/exports/host consumption and V1 asset plugin emission while retaining V2 assets.
- [x] 3.1–3.6 Removed the V1 runtime branch/options/plugin module/provider exports, kept shared agent/permission modules and V2 shell functions, and refreshed the OpenCode link/cutover documentation without discarding the existing dirty status evidence.
- [x] 4.1 Isolated V2-only Go launcher with executable/self-target guards and scoped proxy environment.
- [x] 4.2 Retired auth-seed command that refuses every invocation before auth, key, network, backup, or destination access and advises native V2 login.
- [x] 4.3 Remote sync now targets an existing V2 runtime, rejects missing isolation before backup/transfer, and transfers managed assets without user credentials or databases.
- [x] 5.1 Formatted touched Nix files, passed flake check, and built the exported V2-retirement asset derivations.
- [x] 5.2 Passed the complete operational Go suite and the Home Manager launcher regression.

## Threat-Matrix RED Evidence

| Case | RED observation before production correction | GREEN evidence |
|---|---|---|
| Launcher missing/non-executable/self target | Initial focused Go run showed the former launcher accepted self and unavailable targets; test compilation exposed missing cases. | `go -C pkgs/nixos-scripts test ./internal/opencodehome` passed, including no-probe/no-exec guards, argv preservation and proxy up/down checks. |
| Auth seed default/`--v2` and unsafe forms | Initial focused run showed explicit `--v2` wrote into V2 and unsafe combinations were not refused. | `go -C pkgs/nixos-scripts test ./cmd/install-opencode-auth-seed` passed; fixtures verify nonzero refusal, native-login guidance, no mocked external command, and unchanged test auth/backup bytes. |
| Remote path and unavailable V2 | Initial focused run failed to compile the new preflight checks because the V2 path/validation boundary did not exist. | `go -C pkgs/nixos-scripts test ./cmd/sync-opencode-remote` passed; mock/unit checks cover quoted/injected path handling, missing runtime/environment, V2 assets, and transfer exclusions. No remote host was contacted. |
| Activation, skills, MCP proxy environment | First Python run exposed that the attempted asset build still inherited read-only V1 plugin files and failed while deleting them. | `python3 shared/opencode/home-launcher.test.py` passed after making only the copied plugin directory writable before V1 plugin removal; verifies V2 config, activation without service restart, OpenFang V2 skill ordering, and local MCP proxy/PATH hygiene. |

## Independent Review Remediation

An independent read-only review identified three defects within tasks 1.1/1.3 and 4.1/4.3. The launcher RED run specifically failed when each of `XDG_DATA_HOME`, `XDG_CACHE_HOME`, `XDG_STATE_HOME`, `OPENCODE_DB`, and `TMPDIR` was missing or pointed into the legacy namespace; tests also caught mismatched storage roots. GREEN now validates all required Home Manager exports together before proxy probing or execution, compares the two config-root exports, enforces shared data/cache/state/database/temp ownership, rejects overlap with the legacy data tree, and leaves a coherent custom `runtimeRoot` and explicit project-config opt-in unchanged.

Remote sync now orders credential/database exclusions before every recursive asset include. Its tests apply rsync-style first-match filtering to nested plugin credential, token, database, environment, and key filenames while confirming managed plugin/skill/command assets remain eligible. Destination preflight now parses the generated environment exports without sourcing/evaluating them, checks destination-specific config/runtime consistency and usable JSON agent selection, confirms an absolute executable `opencode2` reports a V2 version, and runs before the backup/transfer sequence. Mock-shell regressions cover missing and stale targets, comment-only and mismatched environments, paths with spaces/quotes, and the no-backup/no-transfer-on-preflight-failure ordering. No remote host was contacted.

Remediation RED→GREEN focused command: `go -C pkgs/nixos-scripts test ./internal/opencodehome ./cmd/sync-opencode-remote -count=1` exited 0 after fixes. The original launcher RED failures and the independent findings are preserved here as the before evidence; no task checkbox was cleared or inferred complete from the earlier passing suite alone.

### Follow-up: Nix-generated export grammar

The follow-up RED run `go -C pkgs/nixos-scripts test ./cmd/sync-opencode-remote -run 'Test(EnvironmentAcceptsNix|EnvironmentRejectsUnquoted|RemotePreflightRequires)' -count=1` failed because safe unquoted `lib.escapeShellArg` values such as `OPENCODE_CONFIG_DIR=/home/...` were rejected by both local and remote parsers. Nix evaluation confirmed safe absolute paths and `1` are emitted unquoted, while values containing spaces/apostrophes are single-quoted with the generator's ` '\'' ` apostrophe escape. Both parsers now accept restricted shell-safe characters when unquoted, or properly delimited single quotes with only the generator's apostrophe escape; unquoted substitutions/metacharacters and malformed quoted syntax are rejected. Parsing remains literal-only: the environment file is never sourced or evaluated.

Follow-up GREEN evidence: focused sync/launcher Go tests with `-count=1`, the full Go suite, Python launcher regression, and `git diff --check` all exited 0. A temporary same-package check read only `/home/glats/.local/share/opencode-v2/environment` and passed `validateEnvironmentFile` against `/home/glats/.config/opencode-v2`; the temporary check file was removed. The environment contents were not logged, and no credential file was accessed. Normal fixtures now represent actual Nix output (safe paths and `1` unquoted) and cover quoted custom roots with spaces/apostrophes plus injection refusal.

## Work Unit Evidence

| Evidence | Result |
|---|---|
| Focused tests | After both review remediations, `go -C pkgs/nixos-scripts test ./cmd/sync-opencode-remote ./internal/opencodehome -count=1` exited 0, then `go -C pkgs/nixos-scripts test ./...` exited 0 across all tested packages. |
| Runtime harness | `python3 shared/opencode/home-launcher.test.py` exited 0; it executes the generated `opencode2-home` function against a recorder shim and verifies argument placement without starting a model/session or reading credentials. Go launcher tests execute a temporary recording child; auth tests use temporary fixtures and mocked external binaries; remote sync tests are local-only and invoke no SSH/rsync. |
| Nix/evaluation | `nix fmt -- <13 touched Nix paths>` exited 0; `nix flake check --no-build` passed; exported `gentle-ai-assets` and `engram-assets` builds passed. Follow-up formatter passed for `pkgs/nixos-scripts/default.nix`. Verified package `jq` via nix-verify MCP (stable nixpkgs 1.8.1) and added it only to `nativeCheckInputs`. `nix build .#packages.x86_64-linux.nixos-scripts --no-link --print-out-paths` then passed, output `/nix/store/z5zh4iqffv4a5mqzkywhvshsi9zf56ss-nixos-scripts-1.0.0`; derivation `/nix/store/jg1b5cfgm01dbfmrhl3l4kwm755gfd6l-nixos-scripts-1.0.0.drv`, including sandbox `go test ./...`. Post-fix rog toplevel drvPath evaluated to `/nix/store/lzzw56qml2qk54jxfm1jkjr90k0r2mg6-nixos-system-rog-26.05.20260822.a9e6d84.drv`; standalone rog Home Manager drvPath to `/nix/store/q8imwf1ginahvkpj1zxc2jnia9q4xyin-home-manager-generation.drv`. Earlier NixOS drvPaths passed for thinkcentre (`/nix/store/llylxz4jndg67qh7qjal9mqnahvyd4ss-nixos-system-thinkcentre-26.05.20260822.a9e6d84.drv`) and t14 (`/nix/store/54kp96cp0j8c2d9wpr76w1qda5paclps-nixos-system-t14-26.05.20260822.a9e6d84.drv`). Standalone HM drvPaths passed for thinkcentre (`/nix/store/3x2i684k6gmsrb2r9rjvgfc295kip1yj-home-manager-generation.drv`) and t14 (`/nix/store/7nl0w581xk6kqk5115lpd0yvr9q7lx8g-home-manager-generation.drv`). Darwin macm5 is DEFERRED by the user until rog is complete; no Darwin evaluation was retried. |
| Rollback boundary | Revert only retirement-owned changes in `pkgs/nixos-scripts/internal/opencodehome/`, `pkgs/nixos-scripts/cmd/install-opencode-auth-seed/`, `pkgs/nixos-scripts/cmd/sync-opencode-remote/`, plus the V1-delivery/config/assets/documentation paths enumerated by tasks 2.1–3.6. Preserve pre-existing changes in overlapping `shared/opencode.nix`, `shared/opencode/runtime-config.nix`, `shared/opencode/home-launcher.test.py`, and `docs/opencode-v2-final-cutover.md`; no activation, data or archive changes are involved. |

Authored diff accounting (excluding the initial pre-apply dirty edits and unrelated dirty OpenSpec paths) is 443 additions + 2,467 deletions = 2,910 changed lines. This exceeds the task forecast; the maintainer's accepted `size:exception` applies. No code was compressed to fit a line limit.

## Remaining Verification

Tasks 5.3–5.5 remain unchecked as partial evidence, not full-fleet acceptance. The user authorized minimal rog native smoke with existing auth and explicitly deferred macm5: "dale. para macm5 por ahora lo vamos a saltar. cuando terminemos rog seguimos con macm5". thinkcentre/t14 runtime remains UNVERIFIED and was not contacted. No activation, service restart, credential import/login, manual credential/database read, secret decryption, remote management write, commit, push, or GC occurred. Native runtime may create its normal session/log and use existing provider credentials; this was specifically authorized.

## Rog-only Verification (2026-10-06)

Read repository instructions, design/tasks/progress, and `git status -sb` in the primary checkout. HEAD remained `62a552c769550dfe32314ab7025641825353b36c`, `master...origin/master`; existing dirty and untracked work was preserved. Reused current recorded Go/Python/flake/evaluation/asset-build evidence instead of rerunning broad gates. Consulted Context7 `/websites/opencode_ai_v2` for CLI/MCP syntax and fetched V2 CLI/config documentation. `opencode2-home` is a generated shell function, not a standalone PATH executable; the managed function sources the V2 environment and selects the native executable through `opencode-home`.

### Installed versus checkout candidate

- Installed native executable: `/nix/store/08ckbjx2q0viv1d7pzvjnz61l9idpr6q-opencode-v2-2.0.14/bin/opencode2`; installed helper: `/nix/store/r2s06k426f58ppvswwjm4aifjgh9101r-nixos-scripts-1.0.0/bin/opencode-home`.
- Initial `nix build .#packages.x86_64-linux.nixos-scripts --no-link --print-out-paths` FAILED because sandbox `TestRemotePreflightRequiresUsableTargetAndDestinationEnvironment` could not find `jq`. This identified a missing test dependency, not a product/runtime failure. After the narrow `nativeCheckInputs = [ jq ];` fix, the same package build passed (derivation/output recorded in the Nix/evaluation evidence above). The built package is candidate source only; it was not activated.
- `nix build '.#homeConfigurations.rog.config.home.file.".config/opencode-v2/opencode.json".source' --no-link --print-out-paths` PASSED, producing `/nix/store/a6cilf3k3jg9yc6c5yzwyv0aghly1jd4-opencode.json`. `cmp -s` against installed `/home/glats/.config/opencode-v2/opencode.json` exited 1: candidate configuration is NOT the installed configuration. The candidate JSON was not activated or passed to the existing server.
- `go -C pkgs/nixos-scripts build -o /home/glats/.local/opencode-v2/tmp/opencode/retire-opencode-v1/rog-validation/opencode-home ./cmd/opencode-home` PASSED. This temporary executable consumes checkout launcher code only; it is NOT a substitute for the failed Nix-built deployment package or candidate HM generation.

### Readiness and minimal native smoke

All CLI commands sourced the store-generated `/home/glats/.local/share/opencode-v2/environment`, preserving the existing V2 credential/session namespace. `opencode2 --help`, `opencode2 run --help`, and `opencode2 mcp --help` confirmed actual pinned CLI syntax. `opencode2 --version` returned `opencode v2.0.14`; `opencode2 service status` returned `http://127.0.0.1:49374`. `timeout 25s opencode2 api get /api/info` returned version `2.0.14`, PID `81666`, the same URL, and tmp root `/home/glats/.local/opencode-v2/tmp/opencode` (exit 0). `/proc/81666/exe` resolved to the installed `.opencode2-unwrapped`. Only whitelisted non-secret environment keys were printed from that process: HOME `/home/glats`, config exports `/home/glats/.config/opencode-v2`, runtime data/cache/state/tmp under `/home/glats/.local/opencode-v2`, DB `/home/glats/.local/opencode-v2/data/opencode.db`, and `OPENCODE_DISABLE_PROJECT_CONFIG=1`. `opencode2 debug paths` independently confirmed these isolated roots; it did not open the database. No V1 namespace was selected.

`timeout 35s opencode2 mcp list` exited 0: browsermcp, context7, engram, exa, github-personal, github-work, and nixos all reported connected. Native Engram project/context access independently succeeded for canonical `nixos-hosts`; no MCP auth or remote management mutation was attempted.

The single model request was:

```sh
source /home/glats/.local/share/opencode-v2/environment
export OPENCODE_HOME_BINARY=/nix/store/08ckbjx2q0viv1d7pzvjnz61l9idpr6q-opencode-v2-2.0.14/bin/opencode2
timeout --signal=TERM --kill-after=5s 75s /home/glats/.local/opencode-v2/tmp/opencode/retire-opencode-v1/rog-validation/opencode-home run --agent general --model openai/gpt-6.1-sol --title retire-opencode-v1-rog-minimal-smoke 'Reply with exactly PONG. Do not call tools, read files, or perform any other work.'
```

Exit 0, output `general · gpt-6.1-sol` then `PONG`. The changed launcher reported `127.0.0.1:2080 not listening — launching without adding proxy env`, proving the live proxy-down launch path. This normal shared-service invocation validates changed launcher execution/forwarding plus installed native auth/provider/service readiness. It does NOT prove candidate generated config/assets, candidate server execution, proxy-up behavior, OAuth refresh specifically, or post-activation removal of V1. Proxy-up and local MCP scrub/project opt-in behavior retain prior fixture evidence; the installed service's default project isolation was directly observed. No second prompt, benchmark, or credential inspection was performed.

### Archive metadata and activation boundary

Used Python `os.lstat`, `stat.filemode`, `os.readlink`/`os.path.realpath`, and nonrecursive directory-name globs only; no archive file contents or credential/session inventory were read. Both `/home/glats/.config/opencode` and `/home/glats/.local/share/opencode` exist as nonsymlink `drwxr-xr-x` directories, UID 1000/GID 100, size 4096. Their observed mtime_ns values were `1791225016598704773` and `1787061953418794164` respectively. These permissions describe actual metadata, not enforced read-only mounts.

System generation links 981–990 and HM generation links 85–87 were observed. `/nix/var/nix/profiles/system` still points through `system-990-link` to `/nix/store/538jcl76hlz1gqba405cnz4liffvam4s-nixos-system-rog-26.05.20260822.a9e6d84`; `/run/current-system` resolves there too. Standalone HM remains `home-manager-87-link` resolving to `/nix/store/v8mhvgmwcib1qrrn1jnaxwxl5nl7n16g-home-manager-generation`. Migration/credential-collision/retirement directory roots were observed with metadata only, and initial/final Git status retained the untracked migration folders. No earlier archive metadata snapshot was available: non-destructive source/fixture evidence plus current metadata is NOT historical byte-level preservation proof. `git diff --check` passed.

At the first pass rog was not ready: the candidate package's missing test-time jq blocked deployment. This defect is now resolved by the parent; the follow-up below supersedes that blocker. Activation remains outside this validation scope. macm5 stays DEFERRED, not waived as complete; no formal verify report or archive operation was produced.

## Rog Candidate Build Follow-up (2026-10-06)

Parent repaired `pkgs/nixos-scripts/default.nix` with `nativeCheckInputs = [ jq ];`, verified through MCP, and reported successful package build `/nix/store/z5zh4iqffv4a5mqzkywhvshsi9zf56ss-nixos-scripts-1.0.0` plus focused/full Go/Python/diff gates. The old missing-jq failure is historical and RESOLVED. This continuation edited no product files and preserved current dirty/untracked work.

Confirmed native flake attributes: `nix eval --raw .#nixosConfigurations.rog.config.system.build.toplevel.drvPath` and `nix eval --raw .#homeConfigurations.rog.activationPackage.drvPath` both PASSED. Results were `/nix/store/lzzw56qml2qk54jxfm1jkjr90k0r2mg6-nixos-system-rog-26.05.20260822.a9e6d84.drv` and `/nix/store/q8imwf1ginahvkpj1zxc2jnia9q4xyin-home-manager-generation.drv`.

`nix build .#nixosConfigurations.rog.config.system.build.toplevel --no-link --print-out-paths` ran FOREGROUND with a 120,000 ms tool limit. It announced 23 derivations and began `/nix/store/1v38px9m5ry02jwi0snwjbsk4ywxly5x-system-path.drv`, then timed out; Nix printed `error: interrupted by the user`. This is INCOMPLETE/TIMEOUT, not a code/test failure or success. No final toplevel output path returned. No background build was launched/polled and no retry was made.

`nix build .#homeConfigurations.rog.activationPackage --no-link --print-out-paths` ran separately FOREGROUND and PASSED, exit 0, returning `/nix/store/wmwr8q0chrjp474w2g2invk73m30x13s-home-manager-generation`. The activation script was NOT executed.

With `/home/glats/.local/share/opencode-v2/environment` sourced and OPENCODE_HOME_BINARY selecting the same pinned native executable, `/nix/store/z5zh4iqffv4a5mqzkywhvshsi9zf56ss-nixos-scripts-1.0.0/bin/opencode-home --version` and the same executable with `run --help` both PASSED, exit 0. Version `opencode v2.0.14`, expected actual run flags, and proxy-down notices confirm the repaired Nix-built changed helper launches the expected native executable noninteractively. No second model request or service restart occurred. Earlier PONG remains installed-service runtime evidence, not full candidate-generation runtime evidence.

Safe structural comparison read ONLY generated candidate/installed configuration and managed namespace environment files, never auth/database files. Candidate HM config resolves to `/nix/store/a6cilf3k3jg9yc6c5yzwyv0aghly1jd4-opencode.json`. Top-level keys, default agent, complete permissions, complete experimental provider policies, agent identifiers/model IDs all equal installed configuration. Provider policy remains deny-all then allow opencode/opencode-go/anthropic/openai/github-copilot/nvidia. MCP identifiers and each server's type/command/URL/enablement match: browsermcp/context7/engram/exa/github-personal/github-work/nixos.

ONLY differing config leaves are PATH in local MCP environments for engram/github-personal/github-work/nixos. Candidate standalone HM profile directory is `/home/glats/.nix-profile/bin`; installed integrated HM uses `/etc/profiles/per-user/glats/bin` in that position, repeating its following fallback entry. All other path segments match. This is expected `config.home.profileDirectory` specialization, not a retirement bug. All four candidate local MCPs preserve empty HTTP_PROXY/HTTPS_PROXY/ALL_PROXY and NO_PROXY `*`. Generated candidate namespace environment bytes equal installed environment, preserving config/runtime/DB roots and project-config disable default. No secret payload was dumped.

Python subprocess `git diff --numstat -- <paths>` confirmed flake.lock, pkgs/opencode-v2, v2-agents/v2-permissions/v2-mcps, shared agents and shared permissions unchanged. These paths were also absent from saved preapply `full-pre-continuation.diff`. Source review confirms providerAllowlist unchanged while only V1 catalog/exports were removed. An earlier tool-rewritten multi-path `git diff` inspection failed `fatal: bad revision 'flake.lock'`; the explicit subprocess supplied the successful unchanged-path evidence.

Current rog readiness: standalone HM and candidate helper BUILD/STATIC gates PASSED; full system activation readiness is BLOCKED by incomplete toplevel build within bounded tool runtime. Parent may authorize a longer foreground build window; do not present system activation as build-proven yet. No activation occurred; post-activation candidate runtime proof remains PENDING. Archive metadata limits above remain adequate for this read-only rog scope, not historical byte-level proof. macm5 remains DEFERRED; thinkcentre/t14 runtime UNVERIFIED. Tasks 5.3–5.5 stay partial, no fleet report or archiving.

## Rog System Build Completion

The orchestrator continued the same system candidate build with a 600,000 ms foreground limit:

`nix build .#nixosConfigurations.rog.config.system.build.toplevel --no-link --print-out-paths`

PASS, exit 0, output `/nix/store/zrrz7pnmsrlzcbjfs4kg960wwn2mjca6-nixos-system-rog-26.05.20260822.a9e6d84`. This supersedes the earlier timeout as the current build-readiness result; the timeout remains historical evidence. The rog system and standalone Home Manager candidates are now built. No activation occurred, so post-activation runtime proof remains PENDING. macm5 stays explicitly DEFERRED; no all-host verification or archive completion is claimed.

## Rog Post-deployment Validation (2026-10-06)

User reported `desplegado`; this pass inspected that deployment without activating, rebuilding, restarting a service, changing product code, reading credentials/databases, logging in/importing, decrypting secrets, remote management writes, commits/push, or GC. Initial Git status preserved existing dirty/untracked work.

`readlink -f /run/current-system` and `/nix/var/nix/profiles/system` both returned EXACT built system candidate `/nix/store/zrrz7pnmsrlzcbjfs4kg960wwn2mjca6-nixos-system-rog-26.05.20260822.a9e6d84`. `/etc/profiles/per-user/glats` resolves to `/nix/store/id21fnkjn3bjfr0b2bqayqglx147c5n6-user-environment`. `systemctl show home-manager-glats.service -p ActiveState -p SubState -p ExecStart -p Result` confirmed `active/exited`, `Result=success`, activation exit 0, and integrated HM generation `/nix/store/qsij6vxxz2yhvq09vbrbayn78ax3mp16-home-manager-generation` (11:58:15–11:58:39 -03). This generation belongs to the running system closure. The standalone HM profile remains the old `/nix/store/v8mhvgmwcib1qrrn1jnaxwxl5nl7n16g-home-manager-generation`; it was not falsely equated with built standalone candidate wmwr8q0chrjp474w2g2invk73m30x13s. Rog was deployed through integrated HM.

Read-only `nix-store --query --requisites` inventory of the running system, integrated HM, and active per-user environment found the canonical native V2 package `/nix/store/08ckbjx2q0viv1d7pzvjnz61l9idpr6q-opencode-v2-2.0.14`, V2 npm assets where applicable, and repaired helper package `/nix/store/z5zh4iqffv4a5mqzkywhvshsi9zf56ss-nixos-scripts-1.0.0`; no V1 OpenCode or V1 npm package appears in these managed delivery closures. `/etc/profiles/per-user/glats/bin/opencode-home` resolves to that repaired helper.

Fresh user shell was loaded with `env PATH=/etc/profiles/per-user/glats/bin:/run/current-system/sw/bin:/usr/bin:/bin zsh -lic ...`, avoiding stale session PATH. `whence -w/-p` reported no bare `opencode` alias/function/executable; `opencode2` is the expected function sourcing the managed V2 environment and executing the pinned native store binary. `opencode2-home` is absent on rog, exactly as current source and generated zshrc specify: its definition is guarded by `pkgs.stdenv.isDarwin`. It is N/A on Linux, not a missing rog delivery regression; earlier wording implying this function existed on rog was incorrect. `opencode2-project` remains in generated zshrc.

Full structural comparisons (booleans only, no secret payload dump) showed deployed `opencode.json` and `cli.json` EQUAL the integrated candidate files, and deployed namespace environment bytes EQUAL integrated candidate environment. Thus the earlier standalone/integrated MCP PATH byte difference is resolved against the correct deployed generation, not ignored. Default agent remains gentle-orchestrator; complete candidate equality preserves agents, models, permissions, MCP definitions and provider policies. Provider policy remains deny-all then allow opencode/opencode-go/anthropic/openai/github-copilot/nvidia. MCP identifiers remain browsermcp/context7/engram/exa/github-personal/github-work/nixos; local MCP proxy scrub remains correct.

Fresh-shell `opencode2 --version` returned `opencode v2.0.14`; `opencode2 debug paths` confirmed config `/home/glats/.config/opencode-v2`, runtime under `/home/glats/.local/opencode-v2`, DB `/home/glats/.local/opencode-v2/data/opencode.db`. `opencode2 service status` and bounded `opencode2 api get /api/info` returned `http://127.0.0.1:49374`, PID81666, version2.0.14, isolated tmp root. Whitelisted non-secret server environment exports confirmed the same isolated roots and OPENCODE_DISABLE_PROJECT_CONFIG=1. PID81666 is retained from before deployment, intentionally compatible with no-restart activation. No effective in-memory full-config equivalence for that retained server is claimed merely from disk equality. `timeout 35s opencode2 mcp list` reported all seven MCPs connected; native Engram project/context access succeeded.

To avoid relying on a retained server for candidate-config proof, the ONE authorized post-deployment prompt used native `run --standalone` (confirmed by current actual `run --help` and Context7 V2 docs), starting its normal private runtime with deployed config and existing isolated auth namespace, without restarting the shared service:

```sh
env PATH=/etc/profiles/per-user/glats/bin:/run/current-system/sw/bin:/usr/bin:/bin zsh -lic 'timeout --signal=TERM --kill-after=5s 75s opencode2 run --standalone --agent general --model openai/gpt-6.1-sol --title retire-opencode-v1-rog-postdeployment-smoke "Reply with exactly PONG. Do not call tools, read files, or perform any other work."'
```

PASS, exit0, `general · gpt-6.1-sol` then `PONG`. No tool calls were requested or observed, no second post-deployment prompt/benchmark. Subsequent shared-service info still showed PID81666 and the same URL: no restart. This is generation-confirmed fresh native candidate-config/provider/auth smoke, not the earlier preactivation installed-only PONG. It does not prove every plugin/tool execution or OAuth refresh specifically.

Archive checks used `os.lstat` only: legacy config/data roots remain nonsymlink0755 UID1000/GID100 size4096 with mtime_ns1791225016598704773 and1787061953418794164, exactly matching earlier metadata observation. Legacy data auth.json metadata is regular0600 UID1000/GID100, size2570, mtime_ns1790380220974927383; config-root auth.json is absent. NO auth contents were opened, hashed, copied or dumped. Root metadata consistency and non-destructive source/fixture proof do not establish historical byte-for-byte content identity. Earlier observed generations/migration-directory metadata limits remain in force.

Rog scoped post-deployment acceptance: PASS, no outstanding rog deployment/runtime blocker found within this minimal proof scope. Full fleet remains PARTIAL: macm5 explicitly DEFERRED until the next authorized phase; thinkcentre/t14 runtime UNVERIFIED. Composite tasks5.3–5.5 stay unchecked rather than pretending fleet complete. No formal verify report or archiving. Only this progress file and tasks.md were updated; `git diff --check` passed before final record.
