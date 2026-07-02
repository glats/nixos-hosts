# Exploration: GitHub auth via sops-nix for rog, thinkcentre, t14

> **Status**: complete
> **Date**: 2026-06-30
> **Project**: nixos-hosts
> **Scope**: Configure `gh`, `git`, and GitHub MCP server to always be authenticated on rog, thinkcentre, t14 using sops-nix. Darwin (mact2) explicitly excluded.

---

## Current State

### 1. sops-nix is wired and partially populated

- `lib/mkHost.nix:21` imports `inputs.sops-nix.nixosModules.sops` for every NixOS host.
- `modules/base/sops.nix` declares **two** secrets under the shared sops file (`secrets/shared/passwords.yaml`):
  - `sops.secrets."glats_hashed_password"` (used)
  - `sops.secrets."github/pat"` (declared, **but never consumed** — see Gaps)
- `.sops.yaml` has 4 host keys (`admin_glats`, `host_rog`, `host_thinkcentre`, `host_t14`) + mact2, and creation rules per path. **All three linux hosts can decrypt `secrets/shared/*.yaml`.**
- `secrets/shared/passwords.yaml` already contains the encrypted `github.pat` value (a `gho_...` PAT).
- `secrets/shared/git-credentials.yaml` already contains the encrypted `git-credentials` value (a single `https://USER:TOKEN@github.com` line).
- `secrets/user/opencode.yaml` is the file for cross-platform OpenCode API keys (referenced by `shared/sops.nix`).
- `secrets/user/atlassian.yaml` has darwin-only secrets (atlassian + a separate `github/token` for mact2 — **must not be touched**).

### 2. GitHub MCP server wrapper already exists

- `modules/features/services/github-mcp-server.nix` is a NixOS module that creates a wrapper script `github-mcp-server` which reads `GITHUB_PERSONAL_ACCESS_TOKEN` from `sops.secrets."github/pat"` at exec time and execs the real `pkgs.github-mcp-server`.
- Imported via `modules/profiles/server.nix:7` → so **rog and thinkcentre already have it**.
- Imported directly by `hosts/t14/default.nix:57` → so **t14 already has it**.
- The OpenCode MCP config (`shared/opencode/mcps-base.nix:12-19`) calls `github-mcp-server stdio` (the wrapper is in PATH and shadows the real binary).
- **No change needed for the MCP server path** — it already works on all 3 hosts, provided the sops secret decrypts.

### 3. `gh` and `git` are enabled but unauthenticated

- `home-linux/gh.nix` enables `programs.gh` with `git_protocol = "https"` and other settings, **but does not set any auth** (no `GH_TOKEN`, no `auth login`, no `hosts.yml` content).
- `home-linux/git.nix` enables `programs.git` with `core.editor = "nvim"` and `core.pager = "delta"`, **but does not set `user.name`, `user.email`, or any `credential.helper`**.
- The `home.file` set has **no `~/.git-credentials` entry** anywhere. The `~/.git-credentials` file present on rog today is a leftover placed by hand, not by HM.
- No `GH_TOKEN` / `GITHUB_TOKEN` env var is set anywhere (`grep -rn GH_TOKEN|GITHUB_TOKEN` returns nothing on the linux side).
- The `home.opencode.activeProviderName` option is mentioned in comments on `hosts/*/default.nix` but the actual `home.opencode.activeProviderName = "github-copilot"` is never set; the default `"opencode-go"` wins. (Out of scope for this change but worth noting.)

### 4. Token source — confirmed format

- `~/.git-credentials` on the current host (placed by hand, not by HM) is the standard git credential store format: a single line `https://USER:TOKEN@github.com` (token has the `gho_` prefix, indicating a GitHub-OAuth-derived PAT).
- `secrets/shared/passwords.yaml > github.pat` is the bare `gho_...` token (no URL prefix).
- `secrets/shared/git-credentials.yaml > git-credentials` is the full `https://...@github.com` line ready for `git credential-store`.

### 5. Host structure

- rog imports `modules/profiles/server.nix` → base → sops, plus its own `hosts/rog/secrets.nix` (which currently declares `sops.secrets."git-credentials"`).
- thinkcentre imports `modules/profiles/server.nix` → base → sops, plus its own `hosts/thinkcentre/secrets.nix` (essentially empty — no `git-credentials`).
- t14 imports `modules/base/sops.nix` directly (not via the profile chain) and `hosts/t14/secrets.nix` (empty). It uses its own `home-manager.users.glats.imports = [ ./home/omarchy.nix ]`.
- t14's `home/omarchy.nix` already imports `home-linux/git.nix` and `home-linux/gh.nix` explicitly (lines 66-67) — so any auth changes in those files will reach all three hosts.

### 6. Existing patterns to follow

- **Shell env-var export from sops**: `shared/opencode.nix:327-365` exports `NVIDIA_API_KEY`, `OPENCODE_API_KEY`, etc. via `programs.zsh.initContent = lib.mkAfter '' ... if [ -f "${config.sops.secrets."X".path}" ]; then export X="$(cat ${config.sops.secrets."X".path})"; fi ...''`. This is the canonical pattern in the repo.
- **Wrapper script that reads sops at exec time**: `modules/features/services/github-mcp-server.nix:9-24` is the exact pattern for the MCP. Reuse it for git credential helper.
- **Home file from sops**: no current example in `home-linux/`, but the `home-darwin/opencode` setup uses the same NixOS-level secret path (no separate HM secret) and references `config.sops.secrets."X".path` from inside HM. This works because HM and NixOS share the same `config` tree for sops (sops-nix uses `warnings = []` to avoid the dual-mount warning).

### 7. Existing sops secret + HM sops wiring

- `home-linux/shared-modules.nix:36-37` imports both `../shared/sops.nix` (which uses NixOS sops) and `inputs.sops-nix.homeManagerModules.sops` (which gives HM its own sops config). Both modules are active.
- t14 `home/omarchy.nix:87-88` imports both too. Good.
- Pattern: declare secrets at the NixOS level (in `modules/base/sops.nix` for shared secrets, or `hosts/<host>/secrets.nix` for host-specific), then reference `config.sops.secrets."X".path` from HM as needed. No need to redeclare in HM unless the secret has different per-user ownership.

---

## Gaps

| # | Gap | Impact | Where |
|---|-----|--------|-------|
| 1 | `sops.secrets."git-credentials"` is only declared in `hosts/rog/secrets.nix` | thinkcentre and t14 have no `git-credentials` file at all | `hosts/rog/secrets.nix:50-55` |
| 2 | No `~/.git-credentials` is materialized by HM anywhere | git push/pull over HTTPS will fail or prompt on every host | (no file) |
| 3 | `programs.git` has no `credential.helper` set | even if the file existed, git wouldn't read it | `home-linux/git.nix` |
| 4 | `programs.git` has no `user.name` or `user.email` | commits will fail with "Please tell me who you are" | `home-linux/git.nix` |
| 5 | `programs.gh` has no auth wiring | `gh` commands return "not authenticated" | `home-linux/gh.nix` |
| 6 | No `GH_TOKEN` / `GITHUB_TOKEN` env var | no system-wide auth fallback; OpenCode provider and any non-shell tool that needs GitHub auth fails | (no file) |
| 7 | `sops.secrets."github/pat"` is declared but only consumed by the github-mcp-server wrapper (already works) | gap is "gh CLI and git" — not the MCP | `modules/base/sops.nix:12-16` |

**Non-gaps** (already working, do not change):
- GitHub MCP server auth: handled by `modules/features/services/github-mcp-server.nix`. Wrapper reads `sops.secrets."github/pat"` at exec time, exports `GITHUB_PERSONAL_ACCESS_TOKEN`, and execs the real binary. Works on all 3 hosts today.
- `gh` package install: handled by `programs.gh.enable = true` (which adds `pkgs.gh` to `home.packages`).
- `git` install: pre-installed in the system closure.

---

## Token Flow

### Source of truth (encrypted at rest)

```
~/.git-credentials                  (current host, plaintext, hand-placed)
   ↓ reference (format-preserving)
secrets/shared/git-credentials.yaml (encrypted; key = "git-credentials")
   ↓ sops-nix mounts at
/run/secrets/git-credentials        (mode 0600, owner glats)
   ↓ referenced from HM as
config.sops.secrets."git-credentials".path
   ↓ materialized at
~/.git-credentials                  (mode 0600, owned by glats)
   ↓ consumed by
git credential.helper=store --file ~/.git-credentials
```

### For gh CLI

```
secrets/shared/passwords.yaml       (encrypted; key = "github.pat")
   ↓ sops-nix mounts at
/run/secrets/github/pat             (mode 0400, owner glats, group users)
   ↓ exported in zsh init as
$GH_TOKEN
   ↓ consumed by
gh <any command>  (reads $GH_TOKEN automatically)
```

### For GitHub MCP server (already in place)

```
secrets/shared/passwords.yaml       (encrypted; key = "github.pat")
   ↓ sops-nix mounts at
/run/secrets/github/pat
   ↓ read by wrapper at exec time, exported as
$GITHUB_PERSONAL_ACCESS_TOKEN
   ↓ consumed by
github-mcp-server stdio  (the nixpkgs binary)
```

### Why two files (`passwords.yaml > github.pat` AND `git-credentials.yaml > git-credentials`)?

- `github.pat` is the bare token — needed by `gh` and the MCP server, where the URL prefix is implicit.
- `git-credentials` is the full `https://...@github.com` line — needed by `git credential-store`, which expects the URL in the file.
- Splitting them avoids parsing the URL out of the file at use time and keeps the two consumers decoupled.

---

## Approaches

### Option A — Shell-export + materialize git-credentials (RECOMMENDED)

**Plan**:
1. Move `sops.secrets."git-credentials"` from `hosts/rog/secrets.nix` to `modules/base/sops.nix` (declare once for all hosts). Keep `owner = "glats"`, `group = "users"`, `mode = "0600"`.
2. Remove the now-redundant declaration in `hosts/rog/secrets.nix`.
3. In `home-linux/git.nix`: add `home.file.".git-credentials".source = config.sops.secrets."git-credentials".path;`, set `programs.git.settings.credential.helper = "store --file ~/.git-credentials"`, and add `user.name = "glats"`, `user.email = "glats@local"` (matching the omarchy defaults).
4. In `home-linux/shell.nix`: add to `programs.zsh.initContent` (lib.mkAfter) the same pattern used in `shared/opencode.nix`:
   ```nix
   if [ -f "${config.sops.secrets."github/pat".path}" ]; then
     export GH_TOKEN="$(cat ${config.sops.secrets."github/pat".path})"
   fi
   ```
5. No change to `home-linux/gh.nix`, `modules/features/services/github-mcp-server.nix`, or any host default.nix.

**Pros**:
- Follows the existing `shared/opencode.nix` pattern exactly (proven, low risk).
- Centralizes the secret declaration (single move from rog-only to shared).
- No new sops files; no new modules; no new packages.
- `git` works for any operation that hits GitHub (push, pull, clone, fetch).
- `gh` works for every gh subcommand automatically (PR list, issue create, repo create, run watch, etc.).
- GitHub MCP server continues to work unchanged.

**Cons**:
- `GH_TOKEN` only lives in interactive zsh shells. Daemons/services (cron, systemd user services) won't see it. Mitigated by: (a) the github-mcp-server already reads sops at exec time, so it's covered; (b) the git credential store is file-based, so any process that calls `git` reads the file directly.
- `~/.git-credentials` is on disk (mode 0600). Acceptable — the file content is already in sops, and the file is needed for `git credential-store` to work without spawning a shell per operation.

**Effort**: Low (4 file edits, ~20 lines total).

### Option B — Env-var-via-home.sessionVariables + git credential helper

Same as A, but export `GH_TOKEN` via `home.sessionVariables` instead of `programs.zsh.initContent`.

**Pros**: Visible to non-shell processes (systemd user services, some daemons).
**Cons**: `home.sessionVariables` references strings, not file paths. The value would be the literal sops mount path, not the file content — which doesn't work for `GH_TOKEN` (we need the token value, not the path). Would need an activation script to read the file and set the value. More fragile, no real benefit for the target use case.
**Effort**: Medium (custom activation script).

### Option C — Custom credential helper script (no `GH_TOKEN`)

Skip `GH_TOKEN` export entirely. Use a small `git-credential-github-sops` shell script as the credential helper. For `gh`, run `gh auth login --with-token` once at activation time using the sops file.

**Pros**: Token never appears in `env` output. `gh` auth persists in `~/.config/gh/hosts.yml`.
**Cons**: (a) `gh auth login` requires interactive confirmation or `--with-token`; activation scripts calling this are tricky and fragile across versions. (b) The custom credential helper adds a process spawn per git operation, slowing down batched git commands. (c) Doesn't help other tools that read `GH_TOKEN` directly. (d) Ignores the existing `shared/opencode.nix` pattern, increasing cognitive load.
**Effort**: High (new module, new wrapper script, new HM activation step).

---

## Recommendation

**Option A — Shell-export + materialize git-credentials.**

Rationale:
1. It is the smallest possible change that closes all 7 gaps.
2. It follows the existing pattern in `shared/opencode.nix` (which has been battle-tested for OpenCode API keys across all 3 hosts).
3. It does not duplicate any work — the github-mcp-server wrapper is already correct, the `gh` package is already installed, the `git` package is already installed.
4. The two-file split (`github.pat` for gh, `git-credentials` for git) matches the existing sops structure and avoids any parsing of the URL at use time.
5. Estimated diff: ~25 lines across 4 files. Well under the 400-line review budget.

---

## Files That Would Change

| File | Change | Lines |
|------|--------|-------|
| `modules/base/sops.nix` | Add `sops.secrets."git-credentials"` declaration (with `owner = "glats"`, `group = "users"`, `mode = "0600"`) | +5 |
| `hosts/rog/secrets.nix` | Remove the now-redundant `sops.secrets."git-credentials"` block | -6 |
| `home-linux/git.nix` | Add `home.file.".git-credentials"`, `credential.helper`, `user.name`, `user.email` | +6 |
| `home-linux/shell.nix` | Add `export GH_TOKEN` to `programs.zsh.initContent` (lib.mkAfter) | +4 |

### Files explicitly NOT changed

- `home-linux/gh.nix` — already correct (just settings, no auth needed since `GH_TOKEN` env var covers it).
- `modules/features/services/github-mcp-server.nix` — already correct.
- `home-darwin/*`, `darwin/*`, `hosts/mact2/*` — out of scope (darwin excluded).
- `secrets/*.yaml` — already contain the right encrypted values; no rotation needed.
- `secrets/user/opencode.yaml` — unrelated.
- `secrets/user/atlassian.yaml` — out of scope (darwin-only, has its own `github/token`).

### Files that will transitively pick up the change (no edit needed)

- `home-linux/shared-modules.nix` — already imports `git.nix`, `shell.nix`, `gh.nix` for rog and thinkcentre.
- `hosts/t14/home/omarchy.nix` — already imports `home-linux/git.nix` (line 66) and `home-linux/gh.nix` (line 67).
- `hosts/rog/home/modules.nix` and `hosts/thinkcentre/home/modules.nix` — already use `home-linux/shared-modules.nix`.

---

## Risks and Unknowns

1. **Token scope**: The token in `secrets/shared/passwords.yaml > github.pat` is prefixed `gho_`, which is the GitHub-OAuth/fine-grained-PAT format. `gh` and the github-mcp-server accept this prefix; git credential-store will pass it through. If the token was issued for a specific OAuth app, the `repo` and `read:org` scopes must be included for git push and `gh pr list` to work. **Action**: verify scopes at proposal/apply time by reading the GitHub UI for the token (not by reading the value). The encrypted value is not visible to the apply agent.

2. **HM sops + NixOS sops dual mount**: When `sops.secrets."git-credentials"` is declared in `modules/base/sops.nix` (NixOS module), both `services."sops-nix".secrets` (NixOS) and `home-manager.users.glats.sops.secrets` (HM) can resolve it. The HM module will not re-mount the file if it sees the NixOS declaration (sops-nix shares the same config tree). The `config.sops.secrets."X".path` reference from HM will resolve to the NixOS mount path (`/run/secrets/X`). This is the same pattern `home-darwin/opencode` already relies on. **Risk**: a future sops-nix refactor could split the namespaces. **Mitigation**: pin sops-nix via flake input (already pinned via `flake.lock`).

3. **`home.file."/.git-credentials"` vs `home.file.".git-credentials"`**: HM accepts the latter (resolves to `/home/glats/.git-credentials`). Need to ensure the activation sequence writes the file **after** sops-nix has decrypted the secret. The sops-nix module runs its activation in `writeBoundary` (early); HM `home.file` symlinks resolve in `linkGeneration` (later). The order is correct; the file will be in place before HM's link step.

4. **Token rotation**: If the PAT expires or is rotated, the encrypted sops files must be re-encrypted. This requires running `sops secrets/shared/passwords.yaml` and `sops secrets/shared/git-credentials.yaml` on a machine with the admin key, editing the plaintext, and committing. **This is a normal sops flow but needs to be documented in the proposal** (a short "rotation" subsection under "Approach A").

5. **Shell env-var scope**: `GH_TOKEN` in zsh init only applies to interactive zsh. Bash, fish, scripts that `exec` zsh -c, and systemd user services won't see it. **Mitigation**: for the MCP server (covered), for git (file-based, covered), for `gh` (only invoked from interactive shell on this setup — confirmed by checking omarchy's zsh-only setup on t14 and MATE-only rog/thinkcentre). If a non-shell `gh` invocation is ever needed, the activation script in Option B would be the answer.

6. **t14 path**: t14 does NOT import `modules/profiles/server.nix`. It imports `modules/base/sops.nix` directly, plus `../../modules/features/services/github-mcp-server.nix` directly. The github-mcp-server import is currently duplicated (once via server.nix, once directly in t14) — but `mkIf cfg.services.github-mcp-server-custom.enable` makes the systemPackages entry idempotent. **No risk**, just noting the redundancy.

7. **mact2/macOS exclusion**: The user explicitly said darwin is excluded. The atlassian.yaml has a separate `github/token` for mact2; we do not touch that file or any darwin/home-darwin/host.

8. **First-activation breakage**: If a user has an unmanaged `~/.git-credentials` (like rog currently), HM's `home.file.".git-credentials"` will refuse to clobber it. Two options: (a) `force = true` to overwrite unconditionally (loses any local edits); (b) let HM back it up (we already set `backupFileExtension = "backup"` in `modules/base/home-manager.nix:12`). **Recommendation**: rely on the existing backup mechanism; do not set `force = true`. Rog's hand-placed file will be renamed to `~/.git-credentials.backup` on first activation, which is correct behavior.

9. **reviewer cognitive load**: Estimated diff is ~25 lines across 4 files. Well under the 400-line budget. No chained PRs needed. `Decision needed before apply: No`, `Chained PRs recommended: No`, `400-line budget risk: Low`.

---

## Ready for Proposal

**Yes.** The exploration is complete and the recommendation is concrete. The orchestrator should pass to `sdd-propose` with:
- Approach A as the canonical direction
- The 4-file change list above
- The risks section as the "open questions" for the proposal
- The token-rotation procedure as a follow-up documentation task
