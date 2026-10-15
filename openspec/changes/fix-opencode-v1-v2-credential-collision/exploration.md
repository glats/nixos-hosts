# Exploration: OpenCode v1/v2 credential collision on rog

## Current State

The repo runs two OpenCode runtimes declaratively on `rog`:

- **v1** (`pkgs.opencode`, pinned 1.18.18, command `opencode`) uses the shared
  store `~/.local/share/opencode/` (`auth.json` + `opencode-stable.db`). Its
  generated config `~/.config/opencode/opencode.json` has **no** `provider.openai`
  block, so the built-in catalog `openai` provider resolves credentials from
  `auth.json` → env fallback.
- **v2** (`pkgs.opencode-v2`, command `opencode2`, wrapper `opencode2()`) is
  isolated via `mkV2Environment` (`shared/opencode.nix` lines 56-67): it sets
  `XDG_CONFIG_HOME`, `XDG_DATA_HOME=~/.local/opencode-v2/data`, `OPENCODE_DB`,
  etc. Its credentials live in its own SQLite DB
  `~/.local/opencode-v2/data/opencode.db`.

`shared/shell-gpt.nix` (lines 46-50) globally exports `OPENAI_API_KEY` in every
zsh session from the sops secret `opencode/nvidia_api_key` — an **NVIDIA NIM**
`nvapi-…` key intended for shell-gpt's OpenAI-compatible base URL. The OpenCode
v1 built-in `openai` provider treats `OPENAI_API_KEY` as its default credential
env var, so with no `openai` entry in `auth.json`, v1 sends the NVIDIA key to
`api.openai.com`.

## Root-cause chain (verified)

1. **CONFIRMED** — `shared/shell-gpt.nix:46-50` exports `OPENAI_API_KEY` globally
   via `programs.zsh.initContent`, sourced into every interactive zsh. Only
   shell-gpt needs this variable; a repo-wide grep shows no other consumer of
   the `OPENAI_API_KEY` name.
2. **CONFIRMED** — v1.18.18 `packages/opencode/src/auth/index.ts:10` stores
   credentials at `path.join(Global.Path.data, "auth.json")` →
   `~/.local/share/opencode/auth.json`. `Auth` supports `api` (key), `oauth`,
   and `wellknown` entry types.
3. **CONFIRMED** — v1.18.18 `packages/opencode/src/provider/provider.ts`
   (tag `v1.18.18`) resolves built-in provider credentials with this order:
   `config provider.<id>.options.apiKey` → `auth.json` `api` entry → provider
   env var. Lines 1522-1533 "load env" merge the env key, then lines 1535-1546
   "load apikeys" merge the `auth.json` `type:"api"` key via `mergeDeep`
   (last-write wins), so **auth.json api key overrides env**. Final fallback at
   line 1720: `if (options["apiKey"] === undefined && provider.key)
   options["apiKey"] = provider.key`.
4. **CONFIRMED** — Error 1 (`sk-svcac…`): the user ran v1
   `opencode auth login openai` (shell history lines 8607/8628/8828/9437/10159),
   writing an `openai` `api` entry (service-account key `sk-svcacct-…`) into the
   shared `auth.json`. v1 sessions pinned to `openai/*` then sent that key to
   `api.openai.com`, which rejected it.
5. **CONFIRMED** — Error 2 (`nvapi-…`): after `opencode auth logout` removed the
   `openai` entry (auth.json mtime 2026-09-25 19:58), v1 fell back to the env
   var `OPENAI_API_KEY` = NVIDIA NIM key, and `api.openai.com` rejected it.
6. **CONFIRMED** — the v2 OpenAI login did **not** write the shared `auth.json`.
   It is an `oauth` credential in v2's own DB
   (`~/.local/opencode-v2/data/opencode.db` `credential` table,
   `cred_0d635fb4…` `integrationID=openai`, created 2026-09-24 22:37, per
   `~/.local/opencode-v2/data/opencode/log/opencode.log` line 241).
7. **CONFIRMED** — the stuck sessions are TOP-LEVEL sessions pinned to
   `openai/gpt-5.6-terra` (providerID `openai`), not `opencode-go/*`. The
   `opencode-high` tier routing only governs SDD sub-agent phases; the user's own
   manual sessions are independent of that profile.

## Sqlite findings

DB inspected read-only with `sqlite3 "file:…?immutable=1"` (main DB only; the
116 MB `-wal` holds only the current session's tail and is not replayed — noted
as a limitation).

Tables: `session`, `message`, `part` (legacy v1) plus `session_v2`,
`session_message`, `credential`, `account`, `instruction_blob/entry/state`,
`workspace`, `worktree`, `todo`, `event`, `permission`, `kv`. v1.18.x is built on
the `@opencode-ai/core` v2 core, so its schema is transitional (both generations
of tables coexist in one file).

- `session.model` is a JSON object `{"id","providerID","variant"}` — the model is
  pinned **per session**, not per message (`message`/`part` store opaque JSON
  `data` blobs; the `part` rows for a stuck session contain
  `metadata.openai.itemId:"rs_…"` confirming OpenAI Responses API traffic).
- `credential` (in the v1 DB): only `anthropic`, `opencode-go`, `github-copilot`
  (all dated 2026-08-18, a migration stamp) — **no `openai`**.
- `account`: two `opencode.ai/console` OAuth accounts (09-22, 09-24) — these are
  from `opencode console login`, unrelated to the OpenAI provider key.
- Stuck top-level sessions (providerID `openai`):
  - `ses_f3614fd4` — 2026-09-25 19:59 — `openai/gpt-5.6-terra` — "Migración de
    configuración Opecnode v1 a v2" (906 parts; user typed "hello" at 19:59:42).
  - `ses_f29cc88c` — 2026-09-25 19:54 — `openai/gpt-5.6-terra` — same title.
  - `ses_f2532e3d` — 2026-09-25 20:01 — `model` NULL (fresh, model not yet chosen).
  - `ses_f2a1103e` / `ses_f2a20103` — 09-24 — `openai/gpt-5.6-terra` — manual
    sessions ("Continuar trabajo con Git code-work", "Corregir fallo SDD Explore").
- Model distribution last 3 days: `opencode-go` 55, `openai` 41, `anthropic` 1.

Conclusion: there is no credential/provider record that forces `openai` — the
sessions are simply pinned to `openai/*` from the user's manual model selection
(independent of `opencode-high`), and the `openai` provider resolves its key from
`auth.json`/env at request time.

## Where v2's login wrote

v2 stored the OpenAI credential in its **own isolated SQLite DB**
(`~/.local/opencode-v2/data/opencode.db`, `credential` table, `type=oauth`),
correctly honoring `OPENCODE_DB`/`XDG_DATA_HOME`. It did not touch the shared
`~/.local/share/opencode/auth.json`.

v1↔v2 auth sharing is **not** upstream design; the two runtimes use disjoint
stores (v1 = `auth.json`, v2 = its own DB). The collision was caused by the user
running v1's `opencode auth login openai` (writing the shared `auth.json`) while
also having tested v2's login — i.e. user error in which binary to use, not a
wrapper-isolation bug. Residual note: v2's own DB has the full v2 schema and an
empty `account` table, so v2 isolation is functioning as declared.

## Affected Areas

- `shared/shell-gpt.nix` — sole global exporter of `OPENAI_API_KEY`; the leak
  source for Error 2.
- `shared/opencode.nix` — exports `NVIDIA_API_KEY`/`OPENCODE_API_KEY` (correct,
  not the problem); owns the v2 `mkV2Environment` isolation.
- `~/.local/share/opencode/auth.json` — shared v1 credential store; had the
  transient `openai` entry.
- `hosts/rog/home/default.nix` — `activeProviderName = "opencode-high"`; routing
  correct for SDD sub-agents, not the user's manual sessions.

## Approaches

1. **Scope `OPENAI_API_KEY` to shell-gpt only (F1) — surgical.** Replace the
   global `export` in `shared/shell-gpt.nix` with a `sgpt` shell function/alias
   that sets `OPENAI_API_KEY` inline (or use shell-gpt's config file). Nothing
   else needs the variable, so v1's `openai` provider loses its env fallback and
   no longer sends the NVIDIA key to `api.openai.com`.
   - Pros: 1-file change, kills the persistent root cause, zero v1/v2 auth
     behavior change, no redesign.
   - Cons: shell-gpt must keep working via the wrapper; must not regress other
     hosts that share `shared/shell-gpt.nix`.
   - Effort: Low.

2. **Re-add a valid OpenAI key via `opencode auth login openai` (F2)** — only if
   the user actually wants a real OpenAI path on v1. auth.json beats env
   (verified), so this restores openai sessions.
   - Pros: restores openai models on v1.
   - Cons: leaves the env fallback footgun; requires a valid key; not needed on
     `opencode-high`.
   - Effort: Low (manual).

3. **Harden v2 auth isolation further (F3)** — v2 already isolates correctly; no
   code change required for the collision. Optional: document/verify that
   `opencode2 auth login` never touches the shared store.
   - Pros: prevents future confusion.
   - Cons: not the actual bug.
   - Effort: Low (docs/verification only).

4. **Immediate recovery, no rebuild (F4)** — see commands below.

## Recommendation

F1 (scope `OPENAI_API_KEY` to shell-gpt) is the smallest correct fix. It removes
the env-var fallback that poisons the built-in `openai` provider, so a future
`opencode auth logout` (or the current missing entry) degrades to "no credential"
instead of "send NVIDIA key to OpenAI". Combined with the user's immediate
recovery (switch stuck sessions back to `opencode-go/*`, or unset the var), v1
sessions resume. F2/F3 are optional follow-ups depending on whether a real
OpenAI path is wanted on v1.

## Risks

- shell-gpt wrapper regression (if the `sgpt` function is mis-scoped) — verify
  with `sgpt --shell "hi"`.
- Other hosts share `shared/shell-gpt.nix`; change is global, so verify on
  thinkcentre/t14 too.
- The stuck sessions remain pinned to `openai/*` until the user switches them
  back; F1 alone does not repin existing sessions.

## Ready for Proposal

Yes — proceed to `sdd-propose` for a one-module change (shell-gpt env scoping)
plus verification (`nix flake check --no-build`, host evals), with F2/F4 as
recovery instructions.

## Key Learnings

1. OpenCode v1.18.18 resolves built-in provider keys as config options > auth.json `api` entry > provider env var, with env loaded first and auth.json overwriting it via mergeDeep.
2. The v2 runtime isolates credentials in its own SQLite DB and does not write the shared auth.json; the collision came from running v1's `opencode auth login` instead of `opencode2 auth login`.
3. A globally exported `OPENAI_API_KEY` holding a non-OpenAI key silently poisons the built-in `openai` provider's env fallback whenever auth.json lacks an openai entry.
4. The `opencode-high` tier routing only affects SDD sub-agent phases; a user's manual top-level sessions keep their own pinned model (`openai/gpt-5.6-terra` here).
