# Exploration: migrate-opencode-v1-to-v2

> ## ⚠️ Correction (2026-09-22 — server-topology re-exploration)
> The prior version of this file resolved the server-lifecycle question to
> **`--standalone` (private per-invocation server) + one isolated SQLite DB**, and
> its Engram explore topic recorded that as the decision. That conclusion is
> **wrong and is reversed below**. `--standalone` is an *escape hatch*, not
> OpenCode V2's intended default: V2's native model is **one shared background
> server per user account** that owns sessions, configuration, integrations,
> permissions, and tool execution, and the maintainer states the intended
> architecture is "one shared OpenCode process for all workspaces and clients"
> (issue #43898). The correct design keeps that shared server, isolates V2 from
> V1 by *directory* (version-scoped XDG / `OPENCODE_CONFIG_DIR` / `OPENCODE_DB`),
> and adds a lightweight cross-platform declarative restart-on-regen hook — see
> the corrected "Server topology decision" section. Do **not** adopt
> `--standalone` as the daily V2 wrapper default.

## Summary

Revised scope: instead of migrating the repo's declarative OpenCode config from
V1 to native V2 in place, **keep V1 and V2 installed and usable in parallel,
each with isolated config, plugins, state/data dirs, wrappers, and explicit
selection**. The repo's OpenCode "configuration" is not a hand-edited JSON file —
it is *generated* by `shared/opencode/*.nix` into `~/.config/opencode/opencode.json`
(79.4 KB) plus `commands/`, `skills/`, `plugins/`, `package.json`, `node_modules/`,
and `tui.json`. Parallel running therefore means adding a *second* generated
runtime (V2) alongside the existing V1 runtime, not replacing one generator.

The single most important correction to the prior exploration is the **release
status**: OpenCode V2 is no longer beta. It is a stable (GA) release published on
npm as `@opencode/cli@2.0.14`, and — critically for this change — the official
docs now state that V1 and V2 *use the same `opencode` command and the same config
and data locations, and are no longer installed side by side by default*. The
parallel approach is therefore not a convenience: it is the only way to keep V1
working once V2 is installed, and every isolation axis listed below must be made
explicit.

This revision adds what the prior one did not answer: **which delivery/isolation
model** actually carries the two runtimes. The user's earlier suggestion of
`nix shell`/`nix develop`/`nix run` is treated as an idea to be adjudicated, not
assumed correct. The evidence below selects the delivery model on its own merits.

## Release status evidence (verified 2026-09-22, live sources)

**OpenCode V2 is stable/GA, not beta, RC, or pre-release.**

| Source | Evidence |
|---|---|
| npm `@opencode/cli` dist-tags | `latest` = `2.0.14` (stable semver); `beta` = `0.0.0-beta-19507`; `dev` = `0.0.0-dev-19995`; `reserved` = `0.0.0-reserved` |
| npm `@opencode/client` / `@opencode/plugin` | same — `latest` = `2.0.14` |
| npm `@opencode-ai/cli` (legacy namespace) | `latest` = `0.0.0-beta-17823`, `beta` = `0.0.0-beta-19271`, `next` = `0.0.0-beta-17823` — the V1-era namespace now carries beta-only versions |
| `https://opencode.ai/v2/docs/migrate-v1/` (live) | No beta banner. Opens: "OpenCode 1 and OpenCode 2 both use the `opencode` command and are no longer installed side by side by default." |
| `https://opencode.ai/v2/docs` (live) | Installers: curl, Homebrew `anomalyco/tap/opencode-v2`, npm `@opencode/cli`, bun/pnpm/yarn/vite+, AUR `opencode-beta`; standalone binaries pinned at `2.0.6`; Docker `ghcr.io/anomalyco/opencode:2.0.0` |
| GitHub `anomalyco/opencode` releases | Latest release is `v1.18.32` (2026-09-21, `prerelease: false`). No `v2.x` GitHub release tag — V2 ships via npm/curl/Homebrew/AUR, not the GitHub tarball `pkgs/opencode/default.nix` fetches |
| `https://opencode.ai/changelog` (live) | Lists only V1 releases (latest `v1.18.32`); GitHub link points at the `v2` branch |

Three prior-exploration premises are now **stale** and must be corrected before
proposal revision:

1. "V2 is beta, published as `@opencode-ai/cli@next`" → V2 is **stable `2.0.14`**
   on the new `@opencode/*` namespace; `@opencode-ai/*` is the legacy V1 namespace.
2. "V2 installs as `opencode2` side-by-side" → V2 installs as **`opencode`**, the
   same command as V1; the V2 curl installer *replaces* the V1 binary by default.
3. "`@opencode-ai/client` is the V2 client" → the V2 client is **`@opencode/client`**
   (namespace rename), and the V2 plugin SDK is **`@opencode/plugin`**.

The field-level V1→V2 mapping from the prior exploration remains valid and was
re-confirmed against the live migrate-v1 page (`agent`→`agents`, `prompt`→`system`,
`permission`→`permissions` ordered array, `model`+`variant`→`model#variant`,
`provider`→`providers` with `npm`→`package`/`aisdk:`, `options`→`settings`/`headers`/
`body`, `mcp`→`mcp.servers`, `plugin`→`plugins`, `disabled_providers`→policies,
`compaction.reserved`→`buffer`/`keep.tokens`, `tui.json`→`cli.json`). Additional
renames confirmed: `autoshare`→`share`, `snapshot`→`snapshots`, `attachment`→`media`,
`reference`→`references`, `command`→`commands`, `subtask`→`subagent`,
`small_model`→`agents.title.model`, `autoupdate`→`update`, MCP remote OAuth camelCase→
snake_case.

# Design decisions (1) and (2) resolved — mini-exploration (2026-09-22)

> This section resolves the two design decisions the proposal carried in
> "Dependencies" (`distribution channel` and `credential share-vs-isolate`) and
> that the prior file flagged as "carried into design (flag, not resolve here)".
> Evidence is from Exa (live docs + npm registry + nixpkgs source), GitHub
> (`anomalyco/opencode` issues, label `2.0`), and the published
> `@opencode/cli@2.0.14` package metadata. It also corrects two stale premises
> from the release-status section above (marked **CORRECTION**).

## Corrections to earlier premises (verified live)

1. **V2's binary is named `opencode2`, not `opencode`.** The live V2 docs
   (`opencode.ai/v2/docs`, Intro) state: "OpenCode 2 installs and runs as
   `opencode2`. It does not replace OpenCode 1's `opencode` binary, so you can
   keep both versions installed and run them side by side." The published
   `@opencode/cli@2.0.14` `bin` field exposes both names
   (`{"opencode":"bin/opencode.exe","opencode2":"bin/opencode.exe"}`), and V2
   version/crash reports in issues confirm `opencode2 --version` →
   `opencode2 2.0.14`. The earlier claim "the binary is named `opencode`, not
   `opencode2`" (release-status item 2 and gap #2) is **stale**. This removes the
   binary-name-collision concern: V2 naturally installs as `opencode2`, so the
   wrapper naming is trivial and V1's `opencode` cannot be clobbered by the V2
   binary itself.
2. **Homebrew, Docker, and standalone binaries are NOT supported in V2.** The
   live V2 docs state exactly: "Homebrew, Windows package managers, Docker, and
   standalone binaries are not supported in V2." The earlier release-status table
   (which listed Homebrew `anomalyco/tap/opencode-v2`, Docker
   `ghcr.io/anomalyco/opencode:2.0.0`, and `opencode.ai/files/bin/2.0.x`
   standalone binaries as V2 installers) is **stale**. The only supported V2
   distribution channels are the **curl installer, npm/bun/pnpm/yarn, and the
   AUR** — and the curl installer itself merely downloads a platform-specific
   **npm tarball**. There is no GitHub `v2.x` release tarball.

## Decision 1 — package source: npm `@opencode/cli` vs pinned platform binary

### Evidence (distribution mechanics)

`@opencode/cli@2.0.14` is a 7 KB meta-package (4 files) containing only
`postinstall.mjs` and a stub `bin/opencode.exe`. Its `optionalDependencies`
declare every platform package:

```
@opencode/cli-linux-x64, -linux-arm64, -linux-x64-musl, -linux-arm64-musl,
-linux-x64-baseline, -linux-x64-baseline-musl, -darwin-x64, -darwin-x64-baseline,
-darwin-arm64, -windows-x64, -windows-arm64, -windows-x64-baseline   (all 2.0.14)
```

The `postinstall` script selects the platform package for the running host and
copies its native binary into `bin/`. The platform packages carry the actual
Bun-compiled standalone binary: `@opencode/cli-linux-x64` = **200 MB** (2 files),
`@opencode/cli-darwin-arm64` = **176 MB** (2 files). The V2 binary is a
self-contained Bun standalone (crash reports show `bun:sqlite`, `bun:ffi`
builtins), the same runtime family as V1, which this repo already wraps with
`autoPatchelfHook` + glibc libs on Linux.

The npm platform packages carry sigstore provenance (`dist.signatures`) and are
published by the `anomalyco/opencode` GitHub Actions trusted publisher (OIDC
`oidcConfigId` present in registry metadata) — the same publisher that cuts the
V1 GitHub release tarballs this repo already fetches.

### The two options collapse

Because there is **no non-npm official binary for V2**, "pinned official
platform binary" can only mean the npm platform package
(`@opencode/cli-<os>-<arch>@2.0.14`). The genuine choice is therefore:

| | Option 1a — npm meta-package `@opencode/cli` (postinstall) | Option 1b — pinned platform binary tarball (**recommended**) |
|---|---|---|
| Source | `registry.npmjs.org/@opencode/cli/-/cli-2.0.14.tgz` | `registry.npmjs.org/@opencode/cli-<os>-<arch>/-/cli-<os>-<arch>-2.0.14.tgz` |
| Contents | postinstall.mjs + stub (7 KB) | native `opencode2` binary (~176–200 MB) |
| Reproducibility | **Poor under Nix** — postinstall runs `npm install` at install time and mutates `bin/`; must be reimplemented or patched | **Excellent** — fixed URL + sha256, pure binary, no scripts |
| Supply-chain trust | Extra hop: postinstall executes arbitrary code at install; larger attack surface | Same publisher/provenance as V1 releases; single pinned artifact |
| Linux/darwin arm64 coverage | All variants present | `linux-x64` + `darwin-arm64` (and `linux-arm64`, `darwin-x64`) present |
| Update maintenance | Must parse the meta-package + resolve optionalDependencies | Direct per-platform fetch; mirrors existing `pkgs/opencode` + `pkgs/opencode-npm-packages` update scripts |
| Runtime compatibility | Binary identical once postinstall completes | Binary identical; no runtime difference (V2 is Bun-native, not a Node script) |
| Effort | Medium (postinstall workaround) | Low (mirror V1 derivation) |

**Recommendation: Option 1b.** Fetch the platform binary tarball
(`@opencode/cli-<os>-<arch>@2.0.14`) directly from registry.npmjs.org with a
pinned sha256, wrap it exactly like `pkgs/opencode/default.nix`
(`autoPatchelfHook` + `makeBinaryWrapper` on Linux; `makeBinaryWrapper` on
Darwin), and install it as `opencode2`. Skip the `@opencode/cli` meta-package
entirely: its postinstall is a non-reproducible, code-executing supply-chain hop
that Nix does not need. This reuses two existing repo precedents — the binary
derivation pattern (`pkgs/opencode`) and the npm-tarball-with-hash pattern
(`pkgs/opencode-npm-packages`) — so no new fetch/update machinery is invented.

## Decision 2 — credential policy: seed V2 SQLite from V1 auth.json vs clean V2 auth

### Evidence (V2 auth behavior)

- V2 stores credentials in its **SQLite** `credential` table, not `auth.json`
  ("Saved API keys and OAuth tokens live in the server's SQLite database"; path
  `~/.local/share/opencode/opencode.db`, overridable by `XDG_DATA_HOME` / release
  channel / `OPENCODE_DB`).
- V2's migration "imports supported credentials from the legacy `auth.json` in
  the OpenCode data directory during its database migration. New and updated
  credentials are stored in SQLite rather than written back to that file." The
  import is **read-only** on `auth.json` and reads **V2's own data dir**.
- Because the isolation design points V2 at a version-scoped data dir, V2's
  automatic migration finds **no** `auth.json` there → V2 starts **clean** by
  default. This is already the proposal's "no-auto-migration invariant".
- Security parity: V1 `auth.json` is plaintext 0600; V2 SQLite is likewise
  plaintext-at-rest (the encrypted vault is still an open proposal — #5748 /
  #4318 — not shipped). Seeding therefore does **not** weaken at-rest security.
- V1's `auth.json` has a known defect (#46128): non-atomic whole-file writes,
  concurrent writers silently lose credentials, `OPENCODE_AUTH_CONTENT` snapshot
  can overwrite the file. V2's SQLite (WAL, single-owner, `busy_timeout`) is the
  safer store — another reason to let V2 own credentials natively.
- Env vars are V2's `environment` connections: the repo's sops-exported keys
  (`OPENCODE_API_KEY`, `NVIDIA_API_KEY`, `GROQ_API_KEY`, …) flow to V2 unchanged,
  so **API-key providers need no seeding**. Only the `opencode-go`
  (openai-proxy) OAuth credential lives exclusively in V1's `auth.json`.

### Policy comparison

| | Option 2a — clean V2 auth (**default**) | Option 2b — seed V2 SQLite from V1 auth.json (**opt-in**) |
|---|---|---|
| Native V2 semantics | Fully native: empty SQLite, `/connect` or `auth` populates it | Native: V2's own migration imports a copied `auth.json` |
| Mutates V1? | No | No (copy is read-only on V1; V2 never writes back) |
| User friction | Re-auth `opencode-go` once in V2 | Zero — proxy credential carried over |
| Secret lifecycle | Two stores fully decoupled; rotation/revocation clean | One explicit one-time copy; later rotation diverges the copies |
| Coupling / rollback | None | One-way copy; rollback = delete V2 DB + re-seed |
| Effort | Low (nothing to build) | Medium (extend `install-opencode-auth-seed`) |

**Recommendation: Option 2a as default + Option 2b as an explicit one-time
opt-in.** The default `opencode2` wrapper starts with a clean, isolated SQLite
store (native V2 semantics, zero coupling, zero mutation of V1). API-key
providers work immediately via the shared sops env vars. For the `opencode-go`
proxy/OAuth credential, provide a one-way seed command (extend
`install-opencode-auth-seed` with a `--v2`/`--auth-file <v2-data-dir>/auth.json`
target, or a thin `install-opencode-auth-seed-v2`) that **copies** V1's
`auth.json` (read-only, 0600 preserved) into the V2 isolated data dir before
first launch, so V2's native migration imports it. This keeps V1 untouched,
preserves V2's SQLite ownership, and is reversible (delete the V2 DB to force a
clean re-auth). It is deliberately **not** the automatic cross-version migration,
which stays disabled by isolation.

## Acceptance checks (for design/verify)

Package method:
- `nix build .#opencode-v2` succeeds on `x86_64-linux` and (via
  `#darwinConfigurations.macm5` / standalone HM eval) `aarch64-darwin`; the
  store path contains a single `opencode2` binary.
- `opencode2 --version` (with the isolation env) prints `opencode2 2.0.14`.
- `file`/`ldd` confirm the Linux binary is patchelf'd against the store glibc
  (no host `libstdc++`/`libc` leaks), and the wrapper `PATH` includes `ripgrep`
  (+ `sysctl` on Darwin).
- The derivation has **no** postinstall step and no `npm`/`node`/`bun` at build
  time — only `fetchurl` + `autoPatchelfHook` + `makeBinaryWrapper`.

Credential policy:
- Fresh V2 launch into an empty V2 data dir creates `opencode.db` with an empty
  `credential` table and writes **nothing** under `~/.config/opencode` or
  `~/.local/share/opencode` (V1's tree) — asserts the no-auto-migration invariant.
- The sops env keys are visible to V2 as `environment` connections (verify one
  API-key provider resolves without any seed).
- After the opt-in seed: V1's `auth.json` mtime/checksum is unchanged; V2's
  `credential` table contains the `opencode-go` entry; no `auth.json` remains in
  the V2 data dir after migration (V2 read-and-imported, did not copy back).
- Rollback: delete V2's DB → `opencode2` re-presents a clean store; V1 continues
  to resolve `opencode` with its original `auth.json` untouched.

## Fallback / rollback rules

- If a V2 host lacks AVX2 (unexpected on rog/thinkcentre/t14, but possible), fall
  back to `@opencode/cli-linux-x64-baseline@2.0.14` (detected by `--version`
  failing to start); the derivation stays hash-pinned either way.
- If `@opencode/cli-<os>-<arch>` disappears or the schema changes, the update
  script mirrors `pkgs/opencode-npm-packages` (re-prefetch + re-hash) — the
  binary is a frozen artifact, so a bad update is caught by `sha256` mismatch
  before anything ships.
- Package rollback: repoint the `opencode2` wrapper/derivation to the previous
  version hash (HM/NixOS generations); V1 is unaffected.
- Credential rollback: the seed is one-way and idempotent — re-running it
  overwrites only the V2 copy; deleting V2's DB returns to clean state. Never
  delete or rewrite V1's `auth.json`; treat it as read-only source.

## Current State

- `pkgs/opencode/default.nix` pins V1 `1.18.22`, downloading the
  `anomalyco/opencode` GitHub release tarball (x64/arm64 × linux/darwin) and wrapping
  it with `makeBinaryWrapper`. Exposed via `lib/packages.nix:55` and the
  `linux.nix`/`darwin.nix` overlays.
- `pkgs/opencode-npm-packages/default.nix` builds npm tarballs including
  `@opencode-ai/sdk` and `@opencode-ai/plugin` (both `1.18.22`), the two TUI plugins,
  `opencode-multimodal`, `opencode-warden`, `unique-names-generator`, `zod`.
- `shared/opencode.nix` is the main Home Manager module; `runtimeConfig = { dir =
  "opencode"; label = "default"; }` encodes the *single-runtime* assumption.
  `runtime-config.nix` generates `opencode.json` (V1 keys), `tui.json`,
  `package.json`, `.gitignore`, and the `commands/`/`skills/`/`plugins/`/
  `node_modules/` trees; two activation scripts (`makeOpencodeConfigMutable`,
  `setupOpencodePluginRuntime`) convert Nix-store symlinks to writable real files.
- **Delivery today is already "persistent packages + wrappers"** — there is no
  flake `app` or `devShell` for OpenCode:
  - Linux (rog/thinkcentre/t14): `pkgs.opencode` is installed via the NixOS
    `linux/system/base/profiles/dev.nix` system profile; the Go launchers
    (`opencode-home`, `opencode2`, `sync-opencode-remote`, `install-opencode-auth-seed`,
    `ai-backup`) ship in `pkgs.nixos-scripts`, installed as `home.packages` in
    `linux/home/shell.nix`.
  - macm5 (nix-darwin): `pkgs.opencode` is in `darwin/home/packages.nix`
    (`home.packages`); `opencode-home` is the sing-box proxy launcher that
    `exec`s the bare `opencode`.
  - `shared/shell-aliases.nix` defines **no** `opencode` alias today; the bare
    `opencode` binary resolves from PATH.
- The flake (`flake.nix`) exposes exactly one `app` (`nixos-build`, x86_64-linux
  only) and one `devShell` (Go toolchain). Neither has anything to do with OpenCode.
- Data/state/cache touchpoints are hardcoded to the V1 XDG layout:
  `~/.local/share/opencode` (auth.json, log/, project/ storage, `opencode.db`/
  `opencode-stable.db` — with a symlink workaround for issue #16885 at
  runtime-config.nix L322–325), `~/.config/opencode` (config + node_modules +
  plugins + skills + commands), `~/.local/state/opencode/warden/audit.log`
  (opencode.nix L143), `~/.cache/opencode`.
- Provider credentials: sops secrets exported as env vars at zsh init
  (NVIDIA_API_KEY, OPENCODE_API_KEY, GROQ_API_KEY, etc.) in `shared/opencode.nix`; a
  separate `auth.json` seed merge flow in `pkgs/nixos-scripts/cmd/install-opencode-auth-seed`.
- Operational launchers/commands (Go, `pkgs/nixos-scripts/cmd/`): `opencode-home`
  (macm5 sing-box proxy launcher that execs `opencode`), `opencode2` (V2-beta Docker
  sandbox — already stale: builds `@opencode-ai/cli@next` and mounts V1 config
  read-only), `sync-opencode-remote`, `install-opencode-auth-seed`, `ai-backup`.
  `shared/shell-aliases.nix` currently defines no `opencode` alias.
- Local plugins (V1 API, do not run in V2): `rtk.ts`, `engram.ts`, `skill-registry.ts`,
  `sdd-task-result-artifacts.ts`, `opencode-review-transport.ts`, `model-variants.ts`.
  npm plugins: `opencode-claude-auth@latest`, `opencode-multimodal@latest`,
  `opencode-warden@1.2.0`.

## Affected Areas

- `pkgs/opencode/default.nix` — V1 binary (unchanged in parallel model, but now must
  coexist with a new derivation).
- `pkgs/opencode-v2/default.nix` (new) — V2 derivation (npm `@opencode/cli@2.0.14`
  or `opencode.ai/files/bin/2.0.x`), binary named `opencode` internally.
- `pkgs/opencode-npm-packages/{default.nix,versions.json,node-modules.json}` — V1
  SDK/plugin/TUI npm deps; a parallel V2 set (`@opencode/plugin`, V2-compatible
  plugins) must be added, not substituted.
- `shared/opencode.nix` + `runtime-config.nix` — the generator is single-runtime;
  must become a parameterized runtime factory (or a second V2 module) emitting an
  isolated V2 tree.
- `shared/opencode/{agents,permissions,plugins,mcps-base,mcps,providers,providers-base}.nix`
  and `local-agent-overlays.json`, `opencode-profile.nix` — V1-shaped data that the
  V2 runtime must either re-read (V1 normalization) or re-emit (native V2).
- `shared/shell-aliases.nix` — where the `opencode`/`opencode2` selection
  wrappers/aliases belong (the delivery model's load-bearing file).
- `linux/system/base/profiles/dev.nix` + `darwin/home/packages.nix` — the two
  per-host places the V1 binary is installed today; the V2 binary + wrappers must
  be delivered through the same two paths.
- `pkgs/nixos-scripts/cmd/{opencode-home,opencode2,sync-opencode-remote,install-opencode-auth-seed,ai-backup}`
  — launchers that assume the single V1 binary name and V1 data paths.
- `lib/packages.nix` + `overlays/{linux,darwin}.nix` — register the V2 derivation.
- `openspec/specs/repo-agent-context/spec.md` — V2 discovers the global
  `~/.config/opencode/AGENTS.md`; a second config dir changes that discovery surface.

## Missing considerations for the parallel approach (gaps to resolve in proposal)

1. **Config discovery env vars/flags** — isolation is only achievable through the
   documented overrides, all verified from `opencode.ai/docs/cli` + issue #43700:
   `OPENCODE_CONFIG` (config file), `OPENCODE_CONFIG_DIR` (config dir),
   `OPENCODE_CONFIG_CONTENT`, `OPENCODE_TUI_CONFIG` (V1), `OPENCODE_DB` (SQLite path),
   plus the XDG base dirs `XDG_CONFIG_HOME`/`XDG_DATA_HOME`/`XDG_CACHE_HOME`/
    `XDG_STATE_HOME` (OpenCode appends `/opencode` to each) and `TMPDIR`. V2 also
    honors the `release channel`. The wrapper contract is full and mandatory: each
    version wrapper must set a distinct `OPENCODE_CONFIG_DIR`,
    `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_CACHE_HOME`, `XDG_STATE_HOME`,
    `OPENCODE_DB`, and `TMPDIR`, with all paths rooted in that version's runtime
    directory; it must not inherit or fall back to the other version's paths. The
    default wrapper must also set `OPENCODE_DISABLE_PROJECT_CONFIG=1` so project
    `opencode.json`/`.opencode` content cannot cross the isolation boundary or
    trigger an unintended `cli.json` migration. A separate explicit opt-in wrapper
    may unset that variable to permit project configuration, but that mode is
    intentionally shared/project-owned and the project must contain only
    V2-compatible configuration and plugins.

2. **Package source and executable collision** — V2 ships as npm `@opencode/cli`
   (postinstall selects a native `opencode` binary) / curl / Homebrew `opencode-v2`
   / AUR `opencode-beta`, and the binary is named **`opencode`, not `opencode2`**.
   The new `pkgs/opencode-v2` derivation cannot reuse the GitHub-release-tarball
   fetch pattern of `pkgs/opencode/default.nix`; it must build from the npm tarball
   or the `opencode.ai/files/bin/2.0.x` binaries. The identical binary name forces
   wrapper-level naming (`opencode-v1`/`opencode-v2` symlinks or env-var-scoped
   wrappers) to avoid collision.

3. **XDG/cache/data/session/database isolation** — V1 keeps sessions/messages in
   `~/.local/share/opencode/project/…/storage/` (or `global/storage/`) plus
   `auth.json`; V2 uses a SQLite DB at `~/.local/share/opencode/opencode.db` and
   imports `auth.json` only during migration. Parallel isolation needs separate data
   dirs so the two SQLite/session stores never collide (`opencode.db` vs
   `opencode-stable.db`), and separate cache (`~/.cache/opencode/bin`) and state
   (`~/.local/state/opencode`) trees. The existing issue-#16885 stable-db symlink
   workaround is V1-specific and must not leak into the V2 dir.

4. **Provider auth/credential sharing vs isolation** — V1 reads `~/.local/share/opencode/auth.json`
   and the sops-exported env vars; V2 migrates `auth.json` into its SQLite DB on
   first run and stores new creds in SQLite, treating env vars as `environment`
   connections. Decision needed: **share** credentials (V2 seed = V1 auth.json via
   `install-opencode-auth-seed`, one source of truth) or **isolate** (separate data
   dir, re-login or copy the seed). Sharing is simpler and matches the current
   seed-merge flow, but couples the two data dirs.

5. **MCP servers** — V1 `mcp` map vs V2 `mcp.servers`; `enabled`→`disabled` inversion,
   `timeout`→`timeout.{catalog,execution}`; the proxy-scrub (`mcp.environment`
   override in runtime-config.nix) must be reproduced in the V2 generator so MCP
   children never inherit `HTTPS_PROXY`/`HTTP_PROXY` on macm5.

6. **Plugin/npm dependency locations** — V1 resolves npm plugins from
   `~/.config/opencode/node_modules` (Nix-built) and local plugins from
   `~/.config/opencode/plugins/`; V2 uses `.opencode/plugins/` + a `plugins` array
   and the `@opencode/plugin` SDK. The three V1 npm plugins and six local plugins
   need V2 ports or V2-compatible replacements; their tarballs/hashes live in a
   parallel `versions.json`/`node-modules.json` set.

7. **Local command aliases** — no `opencode` alias exists today; the launchers
   `opencode-home`, `opencode2`, `sync-opencode-remote` each assume a single binary
   and V1 paths. They must become version-aware (e.g. `opencode-home` execs V1 while
   a new `opencode2` execs V2 with isolated env), and `shell-aliases.nix` should
   expose the explicit selection (`opencode` = V1, `opencode2` = V2).

8. **File permissions** — `auth.json` is 0600 (install-opencode-auth-seed); sops
   secrets are read-only; plugins/skills/commands are chmod 644; node_modules chmod
   u+w; the config dir must be writable (Nix-store sources are read-only, hence
   `makeOpencodeConfigMutable`). A second runtime duplicates all of this and must
   preserve 0600 on credentials and writable-but-owned dirs.

9. **Upgrade/rollback semantics** — V2 replaces V1 `autoupdate` with the `update`
   policy (`disable`/`notify`/`auto`); V1 stays pinned 1.18.22, V2 pinned 2.0.14.
   Parallel rollback = re-pointing the selection wrapper, independent per version,
   with no cross-version state to unwind once dirs are isolated. Auto-update must be
   disabled in the Nix build (`update: "disable"`) to keep the store-managed binary.

10. **Host coverage** — rog, thinkcentre (both NixOS + XRDP), t14 (Hyprland/Omarchy),
    macm5 (nix-darwin). The macm5 `opencode-home` proxy launcher and the sing-box
    loopback are V1-specific and must be extended to V2. V2 must build on both
    linux (glibc) and darwin arm64 — the 2.0.6 binaries exist for both, and the npm
    package supports both.

11. **CI/evaluation tests** — `nix flake check --no-build` does not evaluate Darwin or
    standalone Home Manager configs; the V2 derivation and generators must be
    evaluated separately (`#darwinConfigurations.macm5`,
    `#homeConfigurations.<host>.activationPackage.drvPath`, and a `nix build` of
    `pkgs/opencode-v2`). No V2 runtime smoke test exists (the `opencode2` Docker
    runner is manual); a per-host smoke test is required for the parallel model.

12. **User UX / default selection / state migration policy** — decide the default
    (`opencode` should keep pointing at V1 to avoid surprising a working setup, with
    `opencode2` opt-in for V2), and decide the state policy: **no migration** (each
    version keeps its own isolated sessions — the user's intent) vs V2 auto-migration
    of `tui.json`→`cli.json` and `auth.json`→SQLite, which only happens on first V2
    launch into *its* isolated dir. The `cli.json` global-client-config auto-migration
    is a one-way side effect that must be scoped to the V2 config dir.

## Delivery / isolation model comparison (the adjudication target)

The user proposed `nix shell`/`nix develop`/`nix run` as an idea. It is not assumed
correct. Five delivery models are compared against the actual requirement: **an
interactive desktop TUI (not a dev workflow) usable daily on NixOS and nix-darwin,
with two pinned versions selectable by command name and fully isolated state.**

### A. Persistent Home Manager/NixOS packages + version wrappers (recommended)

Install both `pkgs.opencode` (V1) and `pkgs.opencode-v2` (V2) as persistent
packages through the two existing delivery paths (`linux/system/base/profiles/dev.nix`
system profile on NixOS, `darwin/home/packages.nix` on macm5), then add two
selection wrappers in `shared/shell-aliases.nix` (`opencode`→V1 unchanged,
`opencode2`→V2) that export the isolation contract for their version before
`exec`ing the binary. This is a continuation of what the repo already does; the
only new surface is a second derivation and a second wrapper.

- Pros: persistent daily-driver CLI on PATH with zero invocation friction; TUI is
  first-class; identical mechanism on NixOS and nix-darwin via the existing
  system-profile + home-profile split; isolation env lives in exactly one place per
  version (the wrapper), so it cannot be forgotten or mistyped; rollback is HM/NixOS
  generations (remove V2 = repoint); version pins are store-managed and reproducible;
  sops env-var credentials flow through unchanged and the auth path is set by the
  wrapper.
- Cons: two packages + two wrappers to maintain during the transition window; the
  wrapper roots must be home-relative (defined in HM, not the derivation, because
  `$HOME` differs per host/user: `glats` on Linux, `juan` on macm5).
- Effort: Medium.

### B. Flake `apps` invoked via `nix run` (rejected as primary; optional support)

Define `apps.<system>.opencode-v2` (and optionally `opencode-v1`) whose `program`
points at a store wrapper that sets the isolation env, then launch via
`nix run .#opencode-v2` or `nix run github:glats/nixos-hosts#opencode-v2`.

- Pros: single canonical installable; no switch needed to exercise a version; usable
  from CI/smoke tests; `program` must be a store path (enforced), so the isolation
  env is reproducible if baked into the wrapper derivation.
- Cons: **not a daily-driver interface.** `nix run` requires flake access — either
  the repo dir as CWD or a remote ref (network fetch + eval on every invocation, and
  store GC can force a rebuild). Per-invocation isolation env is only reliable if the
  user always remembers the exact `nix run .#…` form; `nix run <pkg>` does not set
  the XDG/`OPENCODE_*` vars by itself. TUI works, but the eval/fetch indirection adds
  latency and failure modes to a tool the user opens dozens of times a day. The flake
  currently has no aarch64-darwin `apps`, so macm5 needs new per-system definitions.
- Effort: Medium (to add) but high ongoing friction.

### C. `devShells` via `nix develop` (rejected for this requirement)

Define `devShells.<system>.opencode-v2` that puts V2 on PATH and sets the isolation
env, entered with `nix develop .#opencode-v2`.

- Pros: reproducible, pinned environment; XDG env can be set via `shellHook`.
- Cons: **the wrong abstraction for a daily interactive TUI.** `nix develop` spawns a
  subshell — a developer-environment primitive (per the Nix manual/Nix Pills) for
  hacking on a project, not for running a persistent application. Every use requires
  entering and later exiting a shell, the shell inherits cwd/config, and the
  "isolation" is a session, not a selectable command. It offers no advantage over a
  persistent wrapper for "two versions selectable by name," and materially worsens
  daily UX.
- Effort: Low to add, but high daily overhead; wrong tool.

### D. NixOS/Home Manager-managed service / orchestrator (YAGNI)

Run a managed background daemon (`opencode serve` via `systemd.user.services`) or an
orchestrator that routes a client to a selected version.

- Pros: only if the goal were a headless, multi-client, remote or agent-hosted
  server. V2 is client/server, so a daemon is a real, supported mode.
- Cons: **YAGNI for this requirement.** The requirement is two *interactive* CLIs,
  not a hosted server. OpenCode's client/server split is internal — the CLI spawns
  its own server as a child; no external service is needed for the TUI. A managed
  service adds supervision, socket/lifecycle management, and version-routing surface,
  plus a persistent process, for zero benefit over a wrapper. It also conflicts with
  the "explicit selection by command name" UX. Revisit only if a remote/headless
  (multi-client) capability is ever requested — that is a different change.
- Effort: High (unjustified).

### E. Hybrid

The only hybrid the evidence supports is **A as primary + B as a narrowly-scoped
support interface**: persistent wrappers for daily use, plus one flake `app`
(`opencode-v2`) used only by CI and per-host smoke tests to exercise the isolated
wrapper without switching a host. Any broader mix (e.g., `nix develop` shells, a
managed service) adds surface without covering a gap.

## Server topology decision (CORRECTED — supersedes the earlier "resolved" verdict)

> The earlier verdict (**`--standalone` + one isolated SQLite DB** = "minimum
> sufficient, no service") is **reversed**. It misread `--standalone` as a
> neutral alternative when it is an escape hatch, and it misattributed the
> config-capture concern to a "defect" that the product already manages through a
> documented lifecycle. The subsections below establish the native model, then
> re-adjudicate the two designs.

### What the evidence actually establishes

1. **V2's intended default is one shared background server per user account, not
   a per-invocation server.** "By default, OpenCode discovers or starts one
   shared background server for your user account. Every local OpenCode client
   connects to that server, which owns sessions, configuration, integrations,
   permissions, and tool execution." `--standalone` is listed only as the
   alternative: "Use `--standalone` to run with a private server, or `--server`
   to connect to a specific server URL" (`opencode.ai/v2/docs/cli/`, "Background
   service"). The maintainer is explicit: "The intended architecture is one
   shared OpenCode process for all workspaces and clients" (issue #43898), which
   further describes `--standalone` as starting "a private child server for the
   entire client invocation" — a process boundary, not the supported default.

2. **The shared server has a first-class, documented lifecycle — the earlier
   "undocumented and fragile" claim is false.** The docs document
   `opencode service status|start|stop|restart`, `service set <option>`,
   `service set env KEY VALUE`, `service unset env`, `service get env`, and state
   that "Changing a setting stops the background server" and "Changing a managed
   environment variable stops the running service. `service start` starts it again
   with the new environment" (`opencode.ai/v2/docs/network/`, "Service";
   `opencode.ai/v2/docs/cli/web/`, "Configure"; `opencode.ai/v2/docs/troubleshooting/`,
   "Check the background service").

3. **The config-capture concern is real but is solved natively, not by
   `--standalone`.** "Shell exports affect a background service only when that
   service starts from the shell. Persist the variables in the managed service
   configuration so later service starts use the same settings"
   (`opencode.ai/v2/docs/network/`, "Service"). The shared server reads config at
   start; after a Nix rebuild changes the generated config, the correct action is
   `opencode2 service restart` (or `service set env` + `start`) run with the
   wrapper's isolation env so it targets the V2-registered service. `--standalone`
   is *not* the answer — it abandons the server model to dodge a lifecycle the
   product already provides.

4. **Version isolation is a directory problem, not a server-model problem.** The
   shared server registers at `~/.local/state/opencode/service.json`, stores its
   DB at `~/.local/share/opencode/opencode.db` (overridable by `OPENCODE_DB`),
   and reads config from `~/.config/opencode` (overridable by `OPENCODE_CONFIG_DIR`;
   the XDG base dirs `XDG_CONFIG_HOME`/`XDG_DATA_HOME`/`XDG_STATE_HOME`/
   `XDG_CACHE_HOME` are honored too). (`opencode.ai/v2/docs/troubleshooting/`,
   "Service files"; `opencode.ai/v2/docs/cli/`, "Paths";
   `packages/core/src/flag/flag.ts`, `packages/core/src/global.ts`.) Setting these
   to a V2-scoped root gives V2 its own shared server, DB, and config — a fully
   native server that simply lives in a different directory than V1's. No
   `--standalone` flag is required to separate the two versions.

5. **State does not have to be user-global.** Within one server, sessions are
   partitioned per project (`session.directory`; issue #34737), and the whole data
   root is relocatable via the env overrides above; a version-scoped (or even
   project-scoped) state root is supported. What is *not* supported is multiple
   server processes against one DB: V2's DB is SQLite in WAL mode
   (`PRAGMA journal_mode = WAL`, `synchronous = NORMAL`, `busy_timeout = 5000`;
   `packages/core/src/database/database.ts`), designed for a single server owner.
   `--standalone` therefore *creates* the "two servers, one DB" hazard the earlier
   file flagged, whereas the shared server is the single-owner safe pattern.

6. **Multiple concurrent folder sessions are normal and intended.** The shared
   server serves "all workspaces and clients" (issue #43898); sessions run as keyed
   Effect fibers in the one process. This multi-client/multi-session capability is
   exactly what `--standalone` gives up (its private server dies with the client
   and shares no sessions across clients). The earlier file dismissed this as "a
   capability nobody asked for"; it is in fact V2's default operating posture.

7. **The V1-era "portable mode" env family does not exist in V2.** `OPENCODE_DATA_DIR`,
   `OPENCODE_CACHE_DIR`, `OPENCODE_LOG_DIR`, `OPENCODE_STATE_DIR`, and
   `OPENCODE_APPNAME` (PR #8963, Jan 2026) are V1 features and do not appear in the
   V2 `packages/core` source (searches return zero hits). V2's relocation surface
   is: the XDG base dirs, `OPENCODE_CONFIG_DIR`, `OPENCODE_CONFIG`,
   `OPENCODE_CONFIG_CONTENT`, `OPENCODE_DB`, and `OPENCODE_CLI_CONFIG_CONTENT`.
   Do not recommend the `OPENCODE_*_DIR`/`OPENCODE_APPNAME` family for V2.

### Two designs compared (server topology)

| | **Design 1** — default V2 shared server, version-isolated by directory, declarative restart-on-regen | **Design 2** — `--standalone` + one isolated SQLite DB (the earlier verdict) |
|---|---|---|
| Server model | Native: one shared background server per V2 state root | Non-native: private per-invocation server, dies with client |
| Config capture | Handled by declarative restart (`opencode2 service restart` on config regen) | Avoided by fresh env each launch |
| Multi-client / concurrent folder sessions | Preserved (native) | Lost |
| SQLite ownership | Single server = single DB owner (safe WAL) | N servers on one DB → `database is locked` contention |
| Version isolation | Directory-scoped (XDG / `OPENCODE_CONFIG_DIR` / `OPENCODE_DB`) | Directory-scoped DB, but wrong process model |
| Lifecycle surface | `opencode service` subcommands (documented) | None (nothing to manage) |
| Cross-platform | `home.activation` hook (Linux + Darwin) | CLI flag (Linux + Darwin) |
| Effort | Medium | Low |

### Corrected resolution

**Adopt Design 1.** The V2 `opencode2` wrapper must NOT append `--standalone`.
Instead it sets a version-scoped isolation env (XDG base dirs +
`OPENCODE_CONFIG_DIR` + `OPENCODE_DB` + `TMPDIR`, all rooted in the V2 runtime
dir) so V2's *shared* background server registers, stores its DB, and reads config
under the V2 root — native V2 behavior, fully isolated from V1. V1 (`opencode`) is
unchanged (default `opencode` dirs; its own V1 server model).

**A lightweight, cross-platform lifecycle integration IS warranted — but it is a
restart-on-regen hook, not a managed daemon.** After the Nix generator regenerates
the config tree (rebuild), a `home.activation` hook runs `opencode2 service restart`
(with the wrapper env) so the shared server re-reads config; cmp-guard it so it
only fires when `opencode.json` actually changed. This preserves the declarative-Nix
contract (generated config is authoritative) without a permanent process. It **must
be cross-platform** because the repo spans NixOS and nix-darwin: use HM
`home.activation` (works on both), not systemd (Linux-only) or launchd (Darwin-only).
A systemd/launchd daemon (`opencode serve`) is YAGNI for a single-user desktop and
is rejected here.

Design 2 (`--standalone`) is rejected as the default because it forces V2 off its
native shared-server model, loses multi-client/concurrent-session behavior, and —
by running multiple private servers against one DB — *introduces* the exact SQLite
contention the earlier file attributed to shared-server designs. `--standalone`
remains a legitimate escape hatch (isolated testing, CI smoke runs, no shared
service desired), which is where the optional flake `app` support interface should
use it — never the daily wrapper.

## Recommendation

**Primary: A — persistent packages + version wrappers.** It is the only model that
meets "interactive daily desktop CLI" with two pinned, name-selectable, fully
isolated versions, delivered identically on NixOS (`dev.nix` system profile) and
nix-darwin (`packages.nix`), and it is a minimal delta over the repo's existing
delivery (the repo already delivers OpenCode this way; nothing new is invented).
`nix run` (B) and `nix develop` (C) are developer-workflow primitives that add
per-invocation friction, flake-access requirements, and error modes to a daily tool,
so they are rejected as the primary interface. A service/orchestrator (D) is YAGNI —
the client/server split is internal and no external daemon is needed for a TUI.

**Optional, narrowly scoped support interface: one flake `app` (`opencode-v2`)** —
not for daily use, but so a verify agent or CI can run `nix run .#opencode-v2 -- run
-m <model> "…"` against the isolated wrapper without switching a host. This is the
single place `nix run` earns its keep. It is not required for the capability and can
be dropped if judges rule it redundant.

**Preserved safety constraints (non-negotiable, carried from the approved plan):**
separate V2 XDG roots (`XDG_CONFIG_HOME`/`DATA`/`CACHE`/`STATE` + `OPENCODE_CONFIG_DIR`
+ `OPENCODE_DB` + `TMPDIR`), and project config **disabled by default**
(`OPENCODE_DISABLE_PROJECT_CONFIG=1`) with a separate explicit opt-in wrapper for
V2-compatible project config only.

**Server topology (corrected, see section above):** the V2 `opencode2` wrapper
must NOT append `--standalone`. It sets a version-scoped isolation env (XDG base
dirs + `OPENCODE_CONFIG_DIR` + `OPENCODE_DB` + `TMPDIR`, rooted in the V2 runtime
dir) so V2's *native* shared background server registers, stores its DB, and reads
config under the V2 root — fully isolated from V1. A lightweight cross-platform
`home.activation` hook runs `opencode2 service restart` (cmp-guarded, wrapper env)
after config regeneration so the shared server re-reads the generated config. No
permanent daemon; `opencode serve` under systemd/launchd is YAGNI for a
single-user desktop. `--standalone` remains an escape hatch for the optional flake
`app` (CI/smoke runs) only, not the daily wrapper.

### Decision criteria (concise)

| Criterion | Weight | Winner |
|---|---|---|
| Interactive daily-driver UX (TUI, any cwd, no ceremony) | highest | A |
| Actual config/state isolation (guaranteed on *every* invocation) | high | A (B/C rely on the user remembering a command form) |
| Reproducibility (pinned, store-managed) | high | A (tie with B/C on pinning, but A is always-on) |
| Per-host delivery (NixOS system profile + darwin home profile) | high | A (B/C need new aarch64-darwin `apps`/`devShells` + flake access) |
| Secrets/auth lifecycle (sops env + auth.json path) | med | A (single wrapper sets the path; orthogonal to B/C) |
| Operational overhead | med | A (B/C add eval/fetch latency + GC fragility; D highest) |
| Rollback | med | A (HM/NixOS generations; remove V2 = repoint) |
| Suited to interactive CLI *not* dev workflow | highest | A only |

## Risks

- **V2 replaces V1 by default**: same `opencode` command and same default dirs means
  any non-isolated install silently clobbers the V1 config/data; isolation env vars
  must be correct in every wrapper or V1 breaks.
- **Plugin breakage is total**: the six local V1 plugins and three npm plugins do not
  run in V2; `rtk` (shell-command rewriting) is load-bearing for this repo.
- **Namespace/package drift**: `@opencode-ai/*`→`@opencode/*` and the V2 release
  channel change break the existing `pkgs/opencode` update scripts and
  `versions.json` tooling.
- **Credential store divergence**: V2 SQLite vs V1 auth.json; a shared-dir mistake
  can corrupt or duplicate credentials (auth.json is 0600 and seed-managed).
- **One-way client-config migration**: V2 `tui.json`→`cli.json` auto-migration is a
  global side effect that must be scoped to the V2 config dir.
- **Provider/model ID remap** (`azure-cognitive-services`→`azure`,
  `google-vertex-anthropic`→`google-vertex`) still applies when V2 native config is
  emitted.
- **Wrapper root portability**: the isolation roots must be expressed via
  `config.home.homeDirectory` (HM), not hardcoded in the derivation, because the
  Linux user is `glats` and the Darwin user is `juan`.
- **V2 shared-server config capture**: a running same-version shared server
  ignores regenerated config until restarted. Mitigated by a declarative
  `opencode2 service restart` hook (cmp-guarded, wrapper env) — the native
  lifecycle surface, not `--standalone` (corrected).
- **Version isolation correctness**: the isolation env (XDG + `OPENCODE_CONFIG_DIR`
  + `OPENCODE_DB`) must be a single source of truth shared by the wrapper and the
  restart hook, or V2 could register two servers / two DBs. Keep one HM function
  defining it.
- **`--standalone` escape-hatch misuse**: if the optional flake `app` uses
  `--standalone`, it must still point `OPENCODE_DB`/config at the V2 root or it
  will read V1's dirs. The daily wrapper must never use it.

## Ready for Proposal

Yes — **with a scope change**. The orchestrator should tell the user that the change
is no longer "migrate V1 config to V2" but "add a parallel, isolated V2 runtime
alongside V1 with explicit selection," and that the delivery model is settled as
**persistent packages + version wrappers (A)** with an optional single flake `app`
support interface — **not** `nix shell`/`nix develop`/`nix run` as the daily path,
and **no** permanent service/orchestrator daemon. The **server-topology** decision
is now **corrected**: the V2 `opencode2` wrapper uses the **default shared
background server with version-scoped directory isolation** (not `--standalone`),
plus a lightweight cross-platform `home.activation` restart-on-regen hook; a
permanent systemd/launchd daemon is rejected as YAGNI.

## Submit to dual judges

The judges should adjudicate the delivery model and the **corrected server-topology**
decision in isolation (not re-litigate the release-status or field-mapping facts
already approved):

1. **Delivery model**: is "persistent packages + wrappers (A)" correct over
   `nix run` (B) and `nix develop` (C) for an interactive daily TUI? Is the flake
   `app` support interface warranted, or is it YAGNI too?
2. **Server topology (corrected decision)**: confirm that the V2 `opencode2`
   wrapper **must NOT append `--standalone`** and instead uses the **default
   shared background server** with version-scoped directory isolation (XDG +
   `OPENCODE_CONFIG_DIR` + `OPENCODE_DB`), plus a lightweight cross-platform
   `home.activation` restart-on-regen hook (`opencode2 service restart`,
   cmp-guarded). Confirm that a permanent systemd/launchd daemon is NOT required
   (YAGNI) and that `--standalone` is relegated to the optional flake `app`
   (CI/smoke runs) only. Concurrent multi-client / multi-session V2 is native and
   now **in scope** — it is preserved by the shared server, which is exactly why
   `--standalone` was rejected.
3. **Safety constraints preserved**: verify the two approved constraints are intact —
   (a) separate V2 XDG roots (config/data/cache/state + `OPENCODE_CONFIG_DIR` +
   `OPENCODE_DB` + `TMPDIR`), (b) `OPENCODE_DISABLE_PROJECT_CONFIG=1` default with an
   explicit opt-in wrapper only.
4. **Two open decisions carried into design (flag, not resolve here)**: (a) V2
   package source — npm `@opencode/cli@2.0.14` vs `opencode.ai/files/bin/2.0.x`
   release binary; (b) credential share-vs-isolate (`install-opencode-auth-seed`
   targeting a V2-scoped `auth.json` vs V1-only).

---

# Coexistence in the same folder (highest-priority open question — resolved 2026-09-22)

> This section answers the question the prior exploration left open: **what
> actually happens when `opencode` (V1) and the isolated native `opencode2` (V2)
> run simultaneously in the same repository/folder, and which guards are required
> for safe coexistence during gradual migration.** Evidence below is from live
> OpenCode V2 source (`anomalyco/opencode` `packages/core`, `packages/opencode`),
> the live `opencode.ai/v2/docs` pages, and this repository's generated config.
> Verdict: the planned **directory isolation is the load-bearing guard and is
> sufficient**; everything else is either inherent to dual-agent use or rejected
> as over-engineering.

## Plain-language answer

**With the planned isolated wrapper, running both in the same folder is safe.**
`opencode` keeps the default `~/.config/opencode` / `~/.local/share/opencode` /
`~/.local/state/opencode` tree; `opencode2` is pointed at a version-scoped root
(its own `XDG_*` base dirs + `OPENCODE_CONFIG_DIR` + `OPENCODE_DB` + `TMPDIR`).
Because V2 derives **data, cache, state, and tmp** from the XDG base dirs
(`packages/core/src/global.ts`: `xdgData!`/`xdgCache!`/`xdgState!`/`os.tmpdir()`),
its config from `OPENCODE_CONFIG_DIR`, and its DB from `OPENCODE_DB`, the two
runtimes never touch each other's config file, SQLite DB, sessions, server
registry, or lock directory. The **only** surfaces they still share are (a) the
project's files on disk and (b) git — and that is exactly the risk of two humans
or two terminals editing at once: last-write-wins on a file, and git's own
`index.lock` if both commit at the same instant. There is **no hidden corruption
path**.

**Without isolation (what "just install V2" does by default), running both in the
same folder is unsafe in four concrete ways**, because V1 and V2 use the *same
command name and the same default directories* (`opencode.ai/v2/docs/migrate-v1/`):

1. **SQLite DB collision.** V2 opens `~/.local/share/opencode/opencode.db`. This
   repo's activation script already symlinks V1's `opencode-stable.db` →
   `opencode.db` (issue #16885 workaround, `runtime-config.nix` L318–325). Two
   schemas, one file → corruption or `database is locked` (V2 is WAL,
   `busy_timeout=5000`, single-owner — `packages/core/src/database/database.ts`).
2. **Config mutation.** V2's `tui.json`→`cli.json` migration and
   `migrateTuiConfig` (`packages/opencode/src/config/tui-migrate.ts`) strip
   `theme`/`keybinds`/`tui` keys from the *shared* `opencode.json` and write
   `cli.json` + `.tui-migration.bak` into `~/.config/opencode/` — mutating V1's
   live, Nix-generated config (and the repo's activation then fights it with a
   `cmp` re-copy on every rebuild).
3. **auth.json → SQLite import.** V2's first-run migration imports V1's
   `~/.local/share/opencode/auth.json` into its own DB, coupling the two
   credential stores and risking a duplicated/diverged secret.
4. **Server identity / port.** Both default to port 4096 (`packages/opencode/src/server/server.ts`:
   explicit `0` prefers 4096, then any free port). V2 falls back to a random port,
   but its discovery registry lives in the shared state dir, so a V2 client can
   resolve V1's server (protocol mismatch).

Directory isolation eliminates all four by construction. That is the whole answer;
the guard analysis below justifies *why* isolation alone is the minimum, and what
does **not** need to be built.

## Established facts (evidence, per mandated axis)

**Global user state vs repo-local state.**
- Global (V1 today): `~/.config/opencode/` (config, `plugins/`, `skills/`,
  `commands/`, `node_modules/`), `~/.local/share/opencode/` (`auth.json`, `log/`,
  `project/<slug>/storage/`, `opencode.db`/`opencode-stable.db`),
  `~/.local/state/opencode/` (locks + service registry + warden audit),
  `~/.cache/opencode/` (bin, provider packages). V2 defaults to the same XDG
  roots plus a SQLite `opencode.db` and `cli.json`.
- Repo-local (this repo): root `AGENTS.md` + `CLAUDE.md`; `.opencode/` containing
  `package.json` (`"@opencode-ai/plugin": "1.18.22"` — the **V1 plugin SDK**),
  `node_modules/`, `package-lock.json`, `.gitignore`, `warden/audit.log`;
  `.claude/settings.local.json`. **No project-level `opencode.json` exists.**
  The only OpenCode config is the Nix-generated global `~/.config/opencode/opencode.json`.

**`opencode.json` / `.opencode` discovery & precedence (V2).**
- Precedence (`opencode.ai/v2/docs/config`): global `~/.config/opencode/opencode.json`
  → project `opencode.json(c)` (farthest→closest) → `.opencode/opencode.json(c)`
  (every discovered `.opencode` overrides every direct config). `OPENCODE_CONFIG`
  (custom file) and `OPENCODE_CONFIG_DIR` (custom dir) are honored.
- V2 **reads V1 config in memory and normalizes it without rewriting the source**
  (`migrate-v1`), so V1-shaped config is *not* the hazard — V1 *plugins* are.
- `OPENCODE_DISABLE_PROJECT_CONFIG=1` gates, in one flag, the project walk in
  `config.ts`, `paths.ts` (`ConfigPaths.directories` / `files`), `instruction-context.ts`,
  and `tui.ts` (`projectFiles`). Global config/`AGENTS.md` remain eligible.

**AGENTS.md / skill / command / plugin behavior.**
- V2 loads global `~/.config/opencode/AGENTS.md` then project `AGENTS.md` upward
  (cwd→home, or stop at project root if outside home) (`opencode.ai/v2/docs/instructions`).
  The flag skips **project** AGENTS.md only. V2 does **not** use the V1 `CLAUDE.md`
  fallback. V1 uses AGENTS.md with CLAUDE.md fallback.
- Skills/commands/plugins discover from `.opencode/{skills,commands,plugins}` +
  global. **V1 plugins are API-incompatible with V2** (`@opencode-ai/plugin` vs
  `@opencode/plugin`); this repo's six local plugins + three npm plugins do not run
  in V2, and `.opencode/package.json` pins the V1 SDK.

**Project session persistence.**
- V1: `~/.local/share/opencode/project/<slug>/storage/` (git repo) or `global/storage/`
  (non-git) — JSON files (`troubleshooting.mdx`). V2: one SQLite `opencode.db`
  (WAL), sessions keyed per project (`session.directory`; issue #34737). Different
  files → no direct collision **if** data dirs differ; same file name `opencode.db`
  → hard collision **if** shared (see above).

**Workspace file-edit races.** Both agents write the same project files. This is
inherent to dual-agent use and is **not version-specific**: no cross-version guard
exists or is warranted beyond the normal watcher/snapshot behavior (V2 `snapshots`
for undo). The one *repo-specific* shared mutable file is `.opencode/warden/audit.log`
— today V1-only (V2 has no warden port), so no concurrent writer until that port exists.

**Git state effects.** Both run `git` (status/diff/add/commit) via the shell tool.
Git serializes concurrent index mutations with its own `.git/index.lock`; both use
the same git binary, so there is no corruption, only possible clean failure /
lock-wait on simultaneous commit. Not a version-specific hazard.

**Config auto-migration writes.** `migrateTuiConfig` (run on every TUI config load)
writes `tui.json` and `.tui-migration.bak`, and strips tui keys from each
`opencode.json` it finds in `Global.Path.config` + upward project files. The
documented `tui.json`→`cli.json` auto-migration is a **one-way global write**. Both
are scoped to V2's config dir **only if** isolated; otherwise they mutate V1's config.

**MCP subprocess / process-port collisions.** This repo's MCPs are: local stdio
(`github-personal`, `github-work`, `engram mcp`, `browsermcp` via npx, `nixos` via
`docker run --rm`) and remote HTTP (`context7`, `exa`). **No configured MCP binds a
fixed localhost port**, so there is no port-collision risk from config. Running both
versions spawns *two* copies of each local stdio MCP (double subprocess/engram/docker
footprint), and both agents write to the **same engram store** (external tool, own
dedup) — a resource/contention note, not an OpenCode defect.

**Server identity.** V2's shared background server registers its identity in the
state dir (service registry) and binds 4096 with random-port fallback
(`server.ts`). Identity is directory-scoped, so isolation separates the two servers
cleanly; shared state dir ⇒ cross-resolution risk.

**Locks.** V2 uses a `Flock` file-lock primitive rooted at
`~/.local/state/opencode/locks/` (dir-lock via `mkdir` EEXIST, 60 s stale heartbeat,
5 min timeout, token ownership — `packages/core/src/util/flock.ts`). V1 does not use
Flock. Isolation gives V2 a distinct lock root; shared state dir would share the lock
namespace across any two V2 processes (and is why two V2 servers on one DB is
"database is locked" after 5 s).

## Guard comparison

| # | Guard | Verdict | Evidence / reasoning |
|---|---|---|---|
| **A** | Safe-by-default V2 ignores V1 project config + explicit opt-in (`OPENCODE_DISABLE_PROJECT_CONFIG=1` default, opt-in wrapper) — **plus** directory isolation | **REQUIRED (core)** | This is the only guard that *prevents* (not just warns about) the four corruption vectors. It is native: one env flag + scoped XDG/`OPENCODE_CONFIG_DIR`/`OPENCODE_DB`. |
| **B** | Project-level version marker/lock | **REJECTED (no product support)** | V2 has no marker concept; it would need wrapper-level enforcement with no upstream backing, adding a per-repo convention that fails silently if forgotten. A "V2-ready" note is *documentation*, not protection. |
| **C** | Separate worktrees | **REJECTED (insufficient + heavy)** | Only separates the file/git axis (which is inherent anyway); does **not** prevent global config/DB/state collision, which is home-dir-scoped. Unworkable for daily single-repo work. |
| **D** | Mutual-exclusion process guard (refuse to run both) | **REJECTED as hard lock; native scoped lock already exists** | A cross-version mutex defeats the "run both to compare" migration goal. V2 already flocks its own DB/migration critical section per state root; isolation extends that correctly. |
| **E** | Warnings only | **REJECTED alone (additive only)** | Cannot prevent DB corruption or config mutation. Only acceptable as UX layered on top of A. |

## Evidence-based minimum set

**Required technical protection (non-negotiable — the wrapper contract):**
1. **Per-version directory isolation** — `XDG_CONFIG_HOME`, `XDG_DATA_HOME`,
   `XDG_CACHE_HOME`, `XDG_STATE_HOME`, `OPENCODE_CONFIG_DIR`, `OPENCODE_DB`,
   `TMPDIR`, all rooted in the V2 runtime dir, no V1 fallback. This single guard
   defeats DB collision, config mutation reaching V1, auth.json import reaching V1,
   server-identity/lock/port cross-talk. Keep it a single HM function (one source
   of truth) shared by the wrapper *and* the restart hook.
2. **`OPENCODE_DISABLE_PROJECT_CONFIG=1` on the default `opencode2` wrapper** — so
   V2 neither reads the repo's V1-SDK `.opencode/package.json` + `AGENTS.md`, nor
   runs `migrateTuiConfig` against project config. The opt-in wrapper is the only
   V2 project-config path, and it must refuse/warn on a repo whose
   `.opencode/package.json` still pins the V1 SDK (this repo, until V2 ports land).
3. **No-auto-migration invariant** — V2 migration writes (cli.json/auth→SQLite) are
   automatically scoped to the V2 dir once #1 holds; assert this in the smoke test
   (verify no `cli.json`/`tui.json`/`.bak` appears under `~/.config/opencode` after
   a V2 launch).

**Workflow guidance (tell the user; do not enforce):**
- Do not edit the same file in both agents at once (last-write-wins).
- Do not commit/add in both agents at the same instant (git `index.lock`).
- Do **not** use the V2 opt-in wrapper in this repo until plugins are ported.
- Note the doubled local-MCP subprocess/engram/docker footprint when both run.

**Explicitly preserved:** native V2 shared-background-server (it simply lives in the
V2-scoped state dir) and untouched V1 fallback (default dirs). Nothing above changes
the corrected server-topology decision.

## Test matrix (simultaneous same-folder coexistence)

| # | Scenario | Setup | Expected (isolated wrapper) | Failure mode if naive (shared dirs) |
|---|---|---|---|---|
| 1 | Both launch idle in `/home/glats/.nixos` | `opencode` + `opencode2` | Both start; V1 default dirs, V2 V2-dirs; no cross-write | V2 opens V1's `opencode.db` → schema error / `database is locked` |
| 2 | V2 first-run migration | fresh V2 dir | V2 migrates auth→*its* DB; `cli.json` written to V2 config dir | `cli.json` + `.tui-migration.bak` written into `~/.config/opencode/`, tui keys stripped from V1 config |
| 3 | V2 project-config discovery | `opencode2` default wrapper | V2 does **not** read repo `AGENTS.md`/`.opencode/` (flag set) | V2 loads `.opencode/package.json` (V1 SDK) → plugin load failure |
| 4 | V2 opt-in wrapper in this repo | `opencode2 --project-config` | Refuse or warn: repo not V2-compatible | V2 attempts V1 plugins → crash/degrade |
| 5 | Concurrent edit of one file | both agents edit `runtime-config.nix` | last-write-wins; no corruption beyond lost edit | identical (inherent) |
| 6 | Concurrent `git commit` | both agents commit | one waits/fails cleanly on `index.lock` | identical (inherent) |
| 7 | Port 4096 | V1 server up, start V2 | V2 binds its own isolated server (no 4096 conflict) | V2 random-port fallback + shared registry → client resolves wrong server |
| 8 | Local MCP spawn | both spawn `github-*-stdio` | each its own subprocess; no port collision | double spawn only (resource), no collision |
| 9 | Credentials | both read sops env vars | shared read-only env; fine | V2 auth migration steals/duplicates V1 `auth.json` |
| 10 | Warden audit log | V1 writes `.opencode/warden/audit.log` | V1-only writer (V2 no warden port) | N/A until V2 warden port exists |

## Ready for Proposal

Yes — no scope change to the proposal is required. The coexistence question is
answered by the already-approved isolation contract (A) plus the three required
protections above; the only new artifacts are (1) the smoke-test assertions for
items 1–4 and 7 of the matrix, and (2) the user-facing "do not commit/edit
concurrently" and "do not use the opt-in wrapper in this repo yet" guidance. Guards
B, C, D, and E are rejected as primary mechanisms.

---

# V1 version/hash desync — blocker for task 2.5 (investigated 2026-09-24)

## Symptom

`pkgs/opencode/default.nix` declares `version = "1.18.32"`, but the realized V1
binary (`/run/current-system/sw/bin/opencode` and
`/nix/store/...-opencode-1.18.32/bin/opencode`) reports `1.18.22`. Task 2.5's
acceptance check (`opencode --version` = `1.18.32`) therefore cannot pass. The
user's intent — preserve the latest V1 — is correct: `releases/latest` on
`anomalyco/opencode` is `v1.18.32` (2026-09-21, `prerelease: false`).

## Root cause (confirmed, not hypothesis)

Commit `dde153d "updated version"` changed exactly one line — `version =
"1.18.22"` → `"1.18.32"` — and left all four `sha256` hashes unchanged. The
hashes still pin the **v1.18.22** release assets:

| platform | pinned (stale = v1.18.22) | correct v1.18.32 |
|---|---|---|
| x86_64-linux | `I+ymqJLGtTwPm6IzO2kGvcMZAmNGMdVM8XUA5+jL+iA=` | `MEbgQE/cYPuAMH56R4JLoHR3NkF4pNCbqoVISW3W1Ds=` |
| aarch64-linux | `ckPnpBfRkO+ht7CYHb8NbIqni6L7AYHqIzNv27UcUXg=` | `VoRht9TYwZhlyX6aEQLmEwScYDnQH+dyFU3oc8GGWEA=` |
| x86_64-darwin | `0a+F4eY6BCH2fT5wxhx7Vjk8fDL/XvTknwLzsfKcN3A=` | `okvxBJk4L4hV4Z0qCBuGg+SrmcfCr/sy3ImxfIoAzNY=` |
| aarch64-darwin | `ec44ETagmBlTzMMpQXZ4SYsluNMsKhp7Ve5e0lWQ+Uw=` | `+mQ/k0AcE1CNjVE3gOVM6cwBID1QERS+m4jWJAi4EB8=` |

Verified: the upstream v1.18.32 assets are correct — the binary inside the fresh
v1.18.32 linux-x64 tarball reports `1.18.32` (no upstream bug). `git show
dde153d` shows a single `version`-only change; `nix-prefetch-url` of the v1.18.32
assets returns hashes that differ from every pinned value.

## Mechanism (why the "1.18.32" build reports 1.18.22)

`src` is a fixed-output `fetchurl` keyed by hash. On this host the v1.18.22
tarball is already in the store under the pinned hash, so Nix reuses it without
re-downloading; the derivation is named `opencode-1.18.32` only because `version`
drives the output name, so the store path holds the 1.18.22 binary. On a clean
host/CI the same desync surfaces as a hash-mismatch build failure. Either way V1
cannot satisfy "`opencode --version` = 1.18.32".

Contributing defect: `passthru.updateScript`'s awk hash-replacement pattern
(`sub(/sha256 = "sha256-fWaL8mSW/...="]*"/, ...)`) is a stale literal that never
matches the file's `sha256 = "..."` lines, so the update script silently bumps
`version` while leaving hashes stale.

## Smallest compatible repair

Regenerate the four hashes to the v1.18.32 values above (or fix and re-run the
update script); keep `version = "1.18.32"`. Verify with `nix build .#opencode`,
then `...-opencode-1.18.32/bin/opencode --version` = `1.18.32`.

## Placement

This is a **prerequisite repair inside the current slice** (Phase 2, before/with
task 2.5), not a new out-of-scope work unit: slice 1's design/tasks already
declare V1 = 1.18.32 as the baseline, and 2.5 is the gate that asserts it. The
fix is a one-file, hash-only change (plus, optionally, the broken update script),
small enough to fold into slice 1's package/delivery work unit. It must land
before task 2.5's verification can go green.
