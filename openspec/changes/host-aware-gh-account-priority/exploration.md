# Exploration: Host-aware GitHub CLI account priority

## Current State

`gh` v2.98.0 already holds both accounts (`glats`, `jcuzmar-Falabella_FTC`) under a **single** `github.com` host in `~/.config/gh/hosts.yml`:

```yaml
github.com:
    git_protocol: https
    users:
        glats:                  # token lives in keyring, no inline value
        jcuzmar-Falabella_FTC:  # token lives in keyring, no inline value
    user: glats                 # <-- ACTIVE account = the CLI default
```

- The **active/default account** is the top-level `github.com.user` field. This is the single source of truth for what plain `gh` (no `--user`) targets, including the `gh` git credential helper used by `git push` over HTTPS.
- `gh auth switch --hostname github.com --user <account>` is the gh-native, **non-interactive** way to rewrite that `user:` field. With `--user` supplied it never prompts; it only mutates the active marker, never the `users:` map or keyring tokens.
- MCP side is already solved and **orthogonal**: `shared/github-mcp-wrapper.nix` emits two wrappers (`github-mcp-server-personal` → `--user glats`, `github-mcp-server-work` → `--user jcuzmar-Falabella_FTC`) that resolve tokens explicitly via `gh auth token --user`, so they are unaffected by the active account. `shared/opencode/mcps-base.nix` registers both `github-personal` and `github-work`.
- Linux enables `gh` via `linux/home/gh.nix` (`programs.gh.enable` → writes `config.yml`). Darwin has **no** `programs.gh` module — `gh` is only installed through `darwin/home/packages.nix`.
- Git commit identity is **already host-aware** and encodes the same split this change wants: Linux `git.nix` defaults to personal (`identity-personal` first), Darwin `git.nix` defaults to work (`identity-work` first).

## Affected Areas

- `shared/gh-default-account.nix` — **NEW** shared Home Manager module: declares the `home.github.defaultAccount` option and an idempotent activation step that runs `gh auth switch`.
- `linux/home/shared-modules.nix` — import the new shared module (reaches rog/t14/thinkcentre via both the standalone and NixOS-integrated home paths).
- `darwin/home/shared-modules.nix` — import the new shared module (reaches mact2).
- `darwin/home/default.nix` — (if not using a platform-derived default) set `home.github.defaultAccount = "jcuzmar-Falabella_FTC"`.
- `shared/github-mcp-wrapper.nix` and `shared/opencode/mcps-base.nix` — **reference only; must NOT be modified** (task requires preserving the two explicit MCP servers).
- `linux/home/gh.nix` — no change required (gh already enabled on Linux).

## Approaches

1. **Shared option + idempotent `gh auth switch` activation** — one cross-platform module exposes `home.github.defaultAccount` (default `"glats"`, or platform-derived: `if pkgs.stdenv.hostPlatform.isDarwin then "jcuzmar-Falabella_FTC" else "glats"`), plus a `home.activation` script that switches only when the account exists.
   - Pros: gh-native mechanism; no hand-crafting of `hosts.yml`; both accounts stay available; matches the existing `github-mcp-wrapper.nix` shared-module and `home.opencode.activeProviderName` override conventions; minimal diff.
   - Cons: imperative activation step (idempotency must be guaranteed); a manual `gh auth switch` is reverted on next `home-manager switch`.
   - Effort: Low.

2. **Declarative `programs.gh.hosts`** — write `hosts.yml` from Nix.
   - Pros: fully declarative.
   - Cons: Home Manager's `programs.gh.hosts` generates the **entire** `hosts.yml` as an immutable store symlink; it would clobber the `users:`/keyring-token layout and break `gh auth login`/`logout`/`switch` (which mutate that file). Tokens are not in Nix (keyring). Not viable.
   - Effort: High (and wrong).

3. **zsh `initContent` switch** — set active account at each shell start.
   - Pros: no activation ordering concerns.
   - Cons: only covers interactive shells; the `gh` git credential helper and non-interactive `gh` calls (systemd, cron, MCP-adjacent tooling) would still see whatever was last active. Fails the "host-aware" intent.
   - Effort: Low but incomplete.

4. **`GH_CONFIG_DIR` / direnv per-directory** — separate gh config dirs per account.
   - Pros: fine-grained per-project switching.
   - Cons: solves a different problem (per-directory, not per-host); heavy; not what the policy asks for.
   - Effort: High.

## Recommendation

**Approach 1.** A single shared module `shared/gh-default-account.nix` exposing `home.github.defaultAccount`, imported by both `linux/home/shared-modules.nix` and `darwin/home/shared-modules.nix`. Default the value by platform (`isDarwin` → `jcuzmar-Falabella_FTC`, otherwise `glats`), which exactly matches the policy today and mirrors how `darwin/home/git.nix` hardcodes work-as-default. Keep the option overridable per host (same pattern as `home.opencode.activeProviderName`) so a future Linux work host is one inline attrset away.

### Recommended minimal behavior

`home.activation` step (ordered `entryAfter [ "writeBoundary" ]`, after Home Manager's own `migrateGhAccounts`), using the absolute `${pkgs.gh}/bin/gh` and a pure filesystem existence guard so the keyring is never touched:

```sh
_hosts="$HOME/.config/gh/hosts.yml"
if [ -f "$_hosts" ] && grep -qE "^[[:space:]]+${account}:" "$_hosts"; then
  ${pkgs.gh}/bin/gh auth switch --hostname github.com --user "${account}" >/dev/null 2>&1 || true
fi
```

- Guard: only run when the target account already exists as a key under `users:` in `hosts.yml` (idempotent, no keyring access, no prompt).
- Swallow errors so a first-run host with no `gh` login yet does not fail `home-manager switch`.
- Does **not** touch `github-mcp-wrapper.nix` or `mcps-base.nix`; the two MCP servers keep using explicit `--user` resolution.

## Risks

- **Auto-switching in non-interactive contexts**: `gh auth switch` must never prompt. Mitigated by always passing `--user` (deterministic) and by the filesystem existence guard (never calls `gh auth status`, which validates tokens and would touch the keyring on a headless host like thinkcentre or an SSH session).
- **First-run / account not yet logged in**: switch would error if unguarded. The existence guard makes it a silent no-op until the user runs `gh auth login`.
- **Declarative re-assertion**: every `home-manager switch` re-applies the host default, silently reverting a temporary manual `gh auth switch`. Expected for declarative config, but must be documented.
- **mact2 keychain**: Darwin uses macOS Keychain; `gh auth switch` only rewrites `hosts.yml`, so keychain tokens are preserved, but this must be verified on mact2 (not verifiable from rog).
- **Ordering vs `migrateGhAccounts`**: switch must run after Home Manager's account-format migration; `entryAfter [ "writeBoundary" ]` satisfies this.
- **Stale `GH_TOKEN`/`GITHUB_TOKEN` env** (pre-existing, discovered in `unify-github-auth`): a polluted long-lived session can still pin a token for plain `gh`; `gh auth switch` and `gh auth token --user` are unaffected, but it is out of scope for this change.
- **t14 module filtering**: t14 excludes `gpg.nix`/`theme.nix` but keeps `gh.nix`; the new shared module must not be added to t14's exclusion list (it isn't, by default).

## Acceptance Criteria

- [ ] A shared module sets the gh active account per host: `glats` on rog/t14/thinkcentre, `jcuzmar-Falabella_FTC` on mact2.
- [ ] Both accounts remain authenticated and listed (`gh auth status` shows two accounts with the correct `active` flag) on every host.
- [ ] `gh auth status --active --hostname github.com` returns the expected login per host.
- [ ] The two GitHub MCP servers (`github-personal`, `github-work`) are unchanged and still resolve their tokens via `--user`; `shared/github-mcp-wrapper.nix` and `mcps-base.nix` are untouched in the diff.
- [ ] `home-manager switch` succeeds on a host with zero `gh` logins (activation no-ops cleanly).
- [ ] `nix flake check --no-build` passes for rog, t14, thinkcentre, mact2.
- [ ] No fake hostnames (e.g. `personal.github.com`) are introduced; both accounts stay under `github.com`.

## Proposed change slug

`host-aware-gh-account-priority`
