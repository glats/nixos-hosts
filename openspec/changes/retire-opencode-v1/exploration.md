# Exploration: Retire OpenCode V1 Runtime

## Operator Direction (recorded)

User states: *"para mi opencode v1 ya puede ir en retirada porque v2 funciona estable."*

Interpreted as **operator acceptance of V1 retirement** — a declaration that V2 is the stable runtime, not a per-host test proof. This exploration treats V2 stability as accepted, does **not** re-litigate broad V2 release readiness, and does **not** condition retirement on Gentle AI v3/v4. The pins to preserve are unchanged: Gentle AI `v2.5.0` tag (`f5dd1a6c`) and OpenCode V2 CLI `2.0.14` / `@opencode/plugin@2.0.14`.

The previously deselected `sdd-research` lane is NOT applied or relaunched here. This is exploration only: no code edits, no activation, no commits, no destructive session migration.

## Current State

Two runtimes coexist with deliberate isolation:

- **V1 (default, `opencode`)** — `pkgs/opencode` binary v1.18.32, delivered system-wide on Linux via `linux/system/base/profiles/dev.nix` (all of rog/thinkcentre/t14) and home-level on macm5 via `darwin/home/packages.nix`. Config emitted to `~/.config/opencode/`, data in `~/.local/share/opencode/`, auth at `~/.local/share/opencode/auth.json`.
- **V2 (opt-in, `opencode2`)** — `pkgs/opencode-v2` binary 2.0.14, reached only through shell functions `opencode2()` / `opencode2-project()` / `opencode2-home()` (Darwin) in `shared/shell-aliases.nix`, which source the isolated environment and exec `${pkgs.opencode-v2}/bin/opencode2`. Isolation is env-scoped (`mkV2Environment`): `XDG_CONFIG_HOME=~/.config/opencode-v2`, `XDG_*_HOME=~/.local/opencode-v2/{data,cache,state,tmp}`, `OPENCODE_DB=~/.local/opencode-v2/data/opencode.db`, `OPENCODE_DISABLE_PROJECT_CONFIG=1`.

`shared/opencode.nix` owns a single `mkRuntimeConfig` (`shared/opencode/runtime-config.nix`) that emits **both** the V1 and V2 JSON configs from one `let` block, plus the V2-only `browsermcp` systemd/launchd broker service. There is **no** NixOS-declared `opencode2 serve` service: V2 uses OpenCode's native service discovery/`serve`; the uncommitted in-flight diff is *removing* the old `restartOpencodeV2` activation (`opencode2 service restart`) to stop restarting active sessions. The V1 runtime has no NixOS service either.

### External evidence (MCP-first)

- Context7 (`/websites/opencode_ai_v2` migrate-v1 + `/anomalyco/opencode`) and Exa (`https://opencode.ai/v2/docs/migrate-v1/`): upstream V1 and V2 both use the bare `opencode` command and share config/data locations; upstream's own `opencode uninstall --keep-config --keep-data` is the sanctioned removal path (stops registered services, keeps config/data on request). This repo's `opencode2` isolation is a **deliberate divergence** from upstream's shared-root model — load-bearing for the naming decision below.
- V1 plugins do not run in V2; plugin **implementation** must be ported (`Plugin.define` + `setup(ctx)` + stable `id`), which this repo already does via vendored `opencode-v2/plugins/*` (`sdd-task-result.ts`, `opencode-review-transport.ts`, `skill-registry.ts`, `engram.ts`, `rtk-v2.ts`) against `@opencode/plugin@2.0.14`.
- Known upstream hazards: `#41217` (V1 sessions never imported into `session_v2`), `#34445` (update recreated `~/.local/share/opencode`, lost legacy `storage/`). Both argue for **archival preservation, not deletion** of V1 data.

## Affected Areas (inventory: V1-only vs SHARED-still-needed)

### V1-only — safe to remove (verify no V2 reuse first)

**Packages / flake / overlays**

| Path | What |
|---|---|
| `pkgs/opencode/default.nix` (+ `pkgs/opencode/`) | V1 binary 1.18.32 + updateScript |
| `pkgs/opencode-npm-packages/` (default.nix, versions.json, package.json, updateScript) | V1 SDK npm pkgs (`@opencode-ai/sdk`, `@opencode-ai/plugin` V1, `unique-names-generator`, TUI plugins) |
| `lib/packages.nix:55,58` | `opencode-npm-packages`, `opencode` registrations |
| `overlays/linux.nix:19,22` | `opencode-npm-packages`, `opencode` overlay exports |
| `overlays/darwin.nix:59,62` | `opencode-npm-packages`, `opencode` overlay exports |
| `linux/system/base/profiles/dev.nix:37` | `opencode` in shared dev profile (all 3 Linux hosts) |
| `darwin/home/packages.nix:66` | `opencode` in macm5 home packages |

**V1 runtime branches (inside SHARED files — trim, don't delete the file)**

| Path | What |
|---|---|
| `shared/opencode/runtime-config.nix:312-569` | V1 `else` branch: V1 `opencode.json`/`package.json`/`tui.json`/`.gitignore`, `prepareOpencodeSkillTree`, V1 `makeOpencodeConfigMutable`, V1 `setupOpencodePluginRuntime` (copies `opencode-npm-packages` node_modules + V1 plugins + `opencode-stable.db` symlink workaround), `syncOpencodeSkillsToOpenfang` |
| `shared/opencode/runtime-config.nix:91-132` | V1-only `let` bindings `tuiPluginsConfig`/`tuiPluginsToInstall`, `managedPlugins`/`enabledManagedPlugins`/`disabledManagedPluginNames` |
| `shared/opencode.nix:248-257` | V1 `mkRuntimeConfig` invocation |
| `shared/opencode.nix:134-160` | `compaction` option (emitted only in V1 JSON) |
| `shared/opencode.nix:229-233` | `plugins.warden.enable` → `opencode-warden.json` |
| `shared/opencode/agents.nix` | V1 agents (V2 uses `v2-agents.nix`) |
| `shared/opencode/permissions.nix` | V1 permissions (V2 uses `v2-permissions.nix`) |
| `shared/opencode/plugins.nix` | V1-only options: `warden`, `npmPlugins` (`opencode-claude-auth@latest`, `opencode-multimodal@latest`), `tuiPlugins`, and the six `modelVariants`/`opencodeReviewTransport`/`sddTaskResultArtifacts`/`skillRegistry`/`engram`/`rtk` flags (gate only V1 `managedPlugins`) |
| `shared/opencode/rtk.ts` | V1 RTK plugin (V2 uses `rtk-v2.ts`) |
| `shared/opencode-profile.nix:11-31` | `home.opencode.enable = true` (the V1 activation switch) + V1 plugin/tuiPlugin flags |
| `shared/opencode/providers-base.nix` | `allProviders` (V1 provider map) + `disabledProviders` (V1 deny list) — `providerAllowlist` + `nvidiaProvider` are SHARED |

**V1 SDK deps used by plugins (V1-only asset paths)**

| Path | What |
|---|---|
| `gentle-ai-assets/share/gentle-ai/opencode/plugins/*` (`model-variants.ts`, `opencode-review-transport.ts`, `sdd-task-result-artifacts.ts`, `skill-registry.ts`) | V1 plugin sources |
| `engram-assets/share/engram/opencode/plugins/engram.ts` (707-line V1 adapter) | V1 engram plugin |

**Go operational binaries (V1-coupled paths)**

| Path | What |
|---|---|
| `pkgs/nixos-scripts/cmd/install-opencode-auth-seed` | default seeds V1 `~/.local/share/opencode/auth.json`; `--v2` copies V1→V2 migration input. V1 default becomes dead; `--v2`/direct-V2 path retained |
| `pkgs/nixos-scripts/cmd/sync-opencode-remote` | rsync/orchestrate V1 `.config/opencode` remote sync + backup (`.config/opencode.bak`) — obsolete or repurpose to `.config/opencode-v2` |
| `pkgs/nixos-scripts/cmd/opencode-home` (launcher default) | `exec.LookPath("opencode")` V1 default target; V2 already reached via `OPENCODE_HOME_BINARY` |

**Docs / tests (review, not code)**

| Path | What |
|---|---|
| `docs/home-link.md` | stale `bin/opencode-home` + V1 `opencode-home` instructions |
| `docs/opencode-v2-final-cutover.md` | final cutover (deferred; update status to "V1 retirement authorized, final cutover still gated") |
| `docs/opencode-provider-tier-execution-brief.md`, `docs/browser-mcp-setup.md` | provider/MCP docs referencing V1 |
| `openspec/specs/macm5-openai-tls-tunnel/spec.md:64`, `openspec/specs/macm5-openai-native-auth/spec.md:44` | specs referencing `bin/opencode-home` (stale) and `bin/install-opencode-auth-seed` (V1 seed) |

### SHARED — must survive (do NOT delete)

- `pkgs/opencode-v2/`, `pkgs/opencode-npm-packages-v2/`, `pkgs/browsermcp-v2/`
- `shared/opencode.nix` (options + `mkV2Environment` + V2 runtime emission + `browsermcp` service + shared `home.packages` `gentle-ai engram rtk poppler-utils` + `programs.zsh.initContent` `NVIDIA_API_KEY`/`OPENCODE_API_KEY` exports — these API keys are V2 provider deps too)
- `shared/opencode/runtime-config.nix:196-311` (V2 branch), `v2-agents.nix`, `v2-permissions.nix`, `v2-mcps.nix`, `rtk-v2.ts`
- `shared/opencode/mcps-base.nix`, `mcps.nix`, `providers.nix`, `providers-base.nix` (allowlist + nvidia), `home-launcher.test.py`
- `shared/shell-aliases.nix` (`opencode2`/`opencode2-project`/`opencode2-home`)
- `shared/ai-assets.nix`, `darwin/home/opencode/mcps-extra.nix`
- `shared/sops.nix` secrets `opencode/nvidia_api_key` + `opencode/opencode_go_api_key` (SHARED). The 10 orphan provider secrets (`cerebras/openrouter/mistral/cohere/gemini/cloudflare×2/huggingface/kilo/aihubmix` + `groq` re-home) are **out of scope** — no secret deletion, no decryption.

### Coupling the removal must respect (not naive)

1. `home.opencode.enable` currently gates **both** the V1 runtime emission **and** the shared packages/API-key exports. Retirement must split these: keep `enable` for shared packages + API keys, drop/`lib.mkDefault false` a new `v1` runtime gate, and remove the V1 `mkRuntimeConfig` invocation. Deleting `shared/opencode.nix` wholesale would also kill V2.
2. `runtime-config.nix` V1-only `let` bindings (`managedPlugins`, `tuiPluginsConfig`) reference `cfg.plugins.*`/`cfg.tuiPlugins.*` options; removing the V1 branch lets `plugins.nix` drop `warden`/`npmPlugins`/`tuiPlugins`/`modelVariants`/`opencodeReviewTransport`/`sddTaskResultArtifacts` cleanly.
3. `syncOpencodeSkillsToOpenfang` copies V1 `~/.config/opencode/skills` → `~/.openfang/skills`; OpenFang is a V1-family tool. After V1 retirement, re-source this sync from the V2 skills dir or drop it explicitly.
4. `opencode-home` Go launcher default `exec.LookPath("opencode")` resolves nothing once the V1 binary is gone (shell functions/aliases are invisible to `LookPath`). Its V1 default must be removed or repointed; `opencode2-home` (Darwin) is unaffected via `OPENCODE_HOME_BINARY`.

### tmux / desktop / isolation notes

- `shared/tmux.nix` + `tmux-resume` shell function: workspace-only resurrect (`@resurrect-processes 'false'`) — **no opencode process restore**, orthogonal, no change.
- No OpenCode desktop entries exist (grep for `.desktop`/`makeDesktopItem` found none tied to opencode).
- V2 executable identity is `pkgs.opencode-v2/bin/opencode2` (binary name fixed at build). MCP/proxy hygiene lives in `runtime-config.nix` `proxyScrubEnv` + `opencode-home` launcher + `v2-mcps.nix` `browsermcp` remote — all SHARED/V2.

## Approaches

### 1. Remove V1, keep `opencode2` as the only command (bare `opencode` disappears)
- Pros: zero naming ambiguity; no alias to shadow; matches the "V2 is isolated as `opencode2`" model already in flight; smallest surface.
- Cons: breaks muscle memory and any script/doc/alias invoking bare `opencode`; `opencode-home` V1 default and `install-opencode-auth-seed`/`sync-opencode-remote` V1 paths need rework anyway.
- Effort: Low-Medium.

### 2. Remove V1 binary, add a bare `opencode` compatibility shell function that routes to the isolated V2 wrapper (byte-identical to `opencode2()`)
- Pros: preserves `opencode` muscle memory; explicit, auditable shim; keeps isolation/arg/proxy behavior (source isolated env, exec packaged `opencode2`, forward args).
- Cons: `opencode` name now means V2 — can confuse "which runtime am I on"; the shim is invisible to `exec.LookPath`, so `opencode-home`'s V1 default still must be removed/repointed; must never shadow a real V2 default-root install later.
- Effort: Low.

### 3. Final cutover: move V2 into default XDG roots and make `opencode` = native V2 (`docs/opencode-v2-final-cutover.md`)
- Pros: upstream-native naming; single runtime in default roots.
- Cons: explicitly **NO-GO / deferred** today; requires renaming V2 OPENCODE/XDG identity and launching a default-namespace service — exactly what this task says **not** to do silently; separate gated change.
- Effort: High (out of scope here).

## Recommendation

Retire V1 via **Approach 1** (remove V1 packages/branches; keep `opencode2`/`opencode2-project`/`opencode2-home` as the V2 entry points), and surface the bare-`opencode` question as an **explicit product decision** rather than inferring it. Do **not** silently rename V2 OPENCODE/XDG identity or launch a default-namespace service (that is the separate, still-gated `opencode-v2-final-cutover` change).

Minimal reversible retirement shape: (a) delete V1-only package/overlay/profile entries; (b) delete the V1 `else` branch + V1 `let` bindings from `runtime-config.nix` and the V1 `mkRuntimeConfig` invocation from `shared/opencode.nix`, keeping the shared packages/API-key block; (c) trim `agents.nix`/`permissions.nix`/`plugins.nix`/`rtk.ts`/V1 plugin asset paths; (d) rework `install-opencode-auth-seed` (drop V1 default, keep `--v2`), `sync-opencode-remote` (retire or repoint), `opencode-home` (drop/repoint V1 default); (e) update docs/specs. Rollback is pure `git revert` of the touched files (all additive/narrow); no secrets deleted, no data GC.

Preserve V1 session/auth/data files (`~/.local/share/opencode/*`, `~/.config/opencode/`, `auth.json`, `opencode.db`) as **archival** — move-to-backup or leave in place, never delete, never copy conflicting IDs, never decrypt, never GC prior generations.

## Risks

- `home.opencode.enable` couples V1 emission with shared packages/API keys — a naive `enable = false` breaks V2 provider auth. Must split the gate, not flip it.
- `syncOpencodeSkillsToOpenfang` depends on the V1 skills dir; dropping V1 without re-sourcing it breaks OpenFang skills.
- `opencode-home` V1 default target dead-ends after V1 binary removal (`LookPath` can't see shell functions).
- V1 plugin options in `plugins.nix` are referenced by the V1 `let` bindings; both must be removed together or evaluation breaks.
- Docs/specs still reference `bin/opencode-home`/`bin/install-opencode-auth-seed` (stale bash paths) — leaving them causes spec/doc drift.
- V1 sessions are not imported by V2 (`upstream #41217`) — archival preservation is required, not optional.
- In-flight, must not overwrite: the uncommitted diff on `shared/opencode.nix` / `runtime-config.nix` / `home-launcher.test.py` (removing `restartOpencodeV2`) and the untracked `complete-opencode-v1-to-v2-migration` / `fix-opencode-v1-v2-credential-collision` change folders.

## Verification (focused regressions guarding V2 behavior, before/after)

- `nix flake check --no-build` (shared changes).
- Per-host evals, **including** the two `flake check` does not cover: `nix eval .#nixosConfigurations.{rog,thinkcentre,t14}.config.system.build.toplevel.drvPath`; `nix eval .#homeConfigurations.{rog,thinkcentre,t14,macm5}.activationPackage.drvPath`; `nix eval .#darwinConfigurations.macm5.config.system.build.toplevel.drvPath`.
- `go -C pkgs/nixos-scripts test ./...` (opencode-home launcher, install-opencode-auth-seed, sync-opencode-remote, default_test.go asserting no stale `cmd/opencode2`).
- Generated-config assertions: V2 `opencode.json` (agents/permissions/mcp/policies) and `home-launcher.test.py` (V2 launcher wiring, local MCP PATH + proxy scrub) unchanged.
- Runtime smoke only where the host is reachable (`rog`); mark `thinkcentre`/`t14`/`macm5` remote-unknown explicitly — user's V2-stable declaration is operator acceptance, **not** every-host proof. No new features, no parallel upgrades.

## Ready for Proposal

**Yes — with one open product decision.** The orchestrator should tell the user: (1) V1 retirement is treated as operator-accepted (V2 stable, pins unchanged); (2) the only remaining product choice is whether the bare `opencode` command should disappear entirely (recommended) or become a compatibility alias routing to the isolated V2 wrapper — this must be answered explicitly, not inferred; (3) the "final cutover" (move V2 to default XDG roots) stays separately gated and out of scope.
