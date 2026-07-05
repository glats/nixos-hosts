# Exploration: multi-github-identity

## Current State

### Git Config Per Host

**rog / thinkcentre (Linux, NixOS via home-manager)**
- `home-linux/git.nix` — shared git module for all Linux hosts
  - `user.name = lib.mkForce "Juan Cuzmar"`
  - `user.email = lib.mkForce "jcuzmar@protonmail.com"`
  - `core.editor = "nvim -U NONE"`, `core.pager = "delta"`
  - `signing.format = "openpgp"` (to silence HM deprecation warning)
  - No GPG signing key set, no `signByDefault`
  - No `includeIf`, no conditional includes
- `home-linux/gh.nix` — GitHub CLI config
  - `git_protocol = "https"` (authenticates via token, not SSH)
  - No `github.user` set
- `home-linux/shell.nix` — exports `GH_TOKEN` from sops secret `github/pat`
- `home-linux/ssh.nix` — LAN hosts only (rog, t14, thinkcentre, mact2, oneplus5)
  - No GitHub SSH config at all

**t14 (Linux, NixOS via omarchy-nix + selective home-manager)**
- Imports `home-linux/git.nix` directly (same config as rog/thinkcentre)
- `lib.mkForce` on user.name/email prevents omarchy-nix's `omarchy.email_address` from overriding
- Same SSH/GH config as rog/thinkcentre

**mact2 (macOS, via nix-darwin)**
- `home-darwin/git.nix` — Darwin git module
  - `user.name = primaryUser` (= "jcuzmar")
  - `user.email = "jcuzmar@falabella.cl"`
  - `github.user = primaryUser` (="jcuzmar")
  - Already has conditional include via `settings.includeIf."gitdir:~/Work/**"` pointing to `~/.git-falabella` (generated via `home.file`)
  - Has GPG signing key + `signByDefault = true`
- `home-darwin/ssh.nix` — GitHub SSH config
  - `github.com` → `IdentityFile = ~/.ssh/id_ed25519_github`
  - `github-personal` alias → `IdentityFile = ~/.ssh/id_ed25519_personal`
  - `github-enterprise` alias → `IdentityFile = ~/.ssh/id_ed25519_github`

### GitHub Authentication Summary

| Host | Auth Method | Primary Identity | PAT/Token |
|------|------------|------------------|-----------|
| rog | HTTPS (token via GH_TOKEN) | "Juan Cuzmar" / jcuzmar@protonmail.com | `github/pat` from shared/passwords.yaml |
| thinkcentre | HTTPS (token via GH_TOKEN) | "Juan Cuzmar" / jcuzmar@protonmail.com | `github/pat` from shared/passwords.yaml |
| t14 | HTTPS (token via GH_TOKEN) | "Juan Cuzmar" / jcuzmar@protonmail.com | `github/pat` from shared/passwords.yaml |
| mact2 | SSH (id_ed25519_github) + token | jcuzmar@falabella.cl | `github/token` from atlassian.yaml |

### Secrets Layout
- `secrets/shared/passwords.yaml` — `github.pat` (encrypted for all four hosts)
- `secrets/user/atlassian.yaml` — `github.token` (encrypted for mact2 only, macOS-specific)
- `secrets/shared/git-credentials.yaml` — opaque git credential blob (not currently consumed by any nix module)
- No per-user GitHub SSH key secrets exist in sops (SSH keys are managed out-of-band)

### Notable Observations
1. All Linux hosts already use the `glats`-associated PAT (shared with admin key)
2. macOS uses a separate `jcuzmar`-associated token
3. The darwin setup already has a **partial includeIf pattern** (for ~/Work/ → Falabella identity)
4. No Linux host has any conditional include for switching to jcuzmar for work repos
5. `home-darwin/ssh.nix` already defines a `github-personal` SSH alias pointing to `id_ed25519_personal` (presumably glats' key)
6. SSH keys are not managed via sops-nix — they exist as independent files on each host

## Affected Areas

### Files That Would Need Changes
| File | Change |
|------|--------|
| `home-linux/git.nix` | Add conditional includes for jcuzmar identity when in work repo paths |
| `home-darwin/git.nix` | Add conditional includes for glats identity when in personal repo paths; refactor existing includeIf to use HM `programs.git.includes` |
| `home-linux/gh.nix` | Possibly add `github.user` if GH CLI needs per-repo identity switching |
| `home-linux/ssh.nix` | Add GitHub SSH host entries (if switching from HTTPS to SSH) |
| `home-darwin/ssh.nix` | Already has GitHub SSH entries — may need adjustments |
| `secrets/shared/passwords.yaml` | Possibly add per-user PATs if needed |
| `shared/sops.nix` | Possibly add new secret declarations for SSH keys or second PAT |

### Modules Not Needing Changes
- `hosts/*/home/modules.nix` — No changes needed (they import shared modules)
- `modules/base/home-manager.nix` — No changes needed
- `home-darwin/shared-modules.nix` — No changes needed
- `home-linux/shared-modules.nix` — No changes needed

## Approaches Comparison

### Approach 1: Git `includeIf` Conditional Includes (Recommended)
Use Home Manager's first-class `programs.git.includes` option with `condition = "gitdir:..."` patterns.

**For Linux hosts (rog, thinkcentre, t14)**:
- Default identity: `glats` (Juan Cuzmar / jcuzmar@protonmail.com)
- Conditional override for work repos (`~/Work/**`, `~/Falabella/**`, etc.): switch to `jcuzmar` work identity

**For macOS (mact2)**:
- Default identity: `jcuzmar` (jcuzmar@falabella.cl)
- Conditional override for personal repos (`~/Personal/**`, `~/github/glats/**`, etc.): switch to `glats` identity
- Already has a partial pattern for `~/Work/**` → Falabella, refactor to use HM `programs.git.includes`

| Pros | Cons | Complexity |
|------|------|------------|
| Native git feature, well-documented | SSH key switching via `includeIf` requires separate key files per identity | Low |
| Already partially implemented on mact2 | Each host needs a complementary include (inverse of the other) | |
| Home Manager has explicit `programs.git.includes` support | Doesn't handle SSH key selection — that's SSH config concern | |
| Supports inline `contents` (no external files needed) | GPG signing also needs per-identity key mapping | |
| Works with both HTTPS token auth and SSH | | |

**SSH key mapping for this approach**:
- Linux hosts: use HTTPS + `GH_TOKEN` (no SSH keys needed for GitHub)
- macOS: use SSH. Already has `github.com` → `id_ed25519_github` (work) and `github-personal` alias → `id_ed25519_personal` (personal). The `includeIf` in git config wouldn't switch SSH keys — instead, repos would need to use `git@github-personal` remote URLs for personal projects.

### Approach 2: Per-Host Default + Manual Per-Repo Override (Status Quo)
Keep current setup but manually run `git config user.name/email` in each repo that needs a different identity.

| Pros | Cons | Complexity |
|------|------|------------|
| Zero config changes | Manual, error-prone — easy to forget | None (no-op) |
| No risk of breaking existing setup | No automation for new worktrees | |
| | Every new clone of a work repo needs manual config | |
| | Ignores the fact mact2 already has partial automation (Falabella include) | |

### Approach 3: Direnv-Based Identity Switching
Use `direnv` with a `.envrc` that exports `GIT_AUTHOR_NAME`, `GIT_AUTHOR_EMAIL`, `GIT_COMMITTER_NAME`, `GIT_COMMITTER_EMAIL` per-repo or per-directory.

| Pros | Cons | Complexity |
|------|------|------------|
| Very explicit — visible in each repo | Each repo needs a `.envrc` file | Medium |
| Works for any tool that reads env vars | Git still uses user.name/email for `git config` unless env vars override | |
| Can also switch SSH keys via `SSH_AUTH_SOCK` | Direnv not universally adopted across team workflows | |
| | Need direnv installed and configured on all hosts | |
| | Overengineering for a simple git config switch | |

## Recommendation

**Approach 1 (Git `includeIf` conditional includes)** is recommended.

Rationale:
1. Already partially implemented on mact2 (`includeIf."gitdir:~/Work/**"`)
2. Home Manager has **native `programs.git.includes` support** — no hacks needed
3. It works at the git level (not shell/direnv), so it applies to all git operations including IDEs, GUI tools, and `gh`
4. The `includes` option supports inline `contents` (no external files) or `path` (external file)
5. For SSH identity switching, the darwin host already has separate SSH key aliases (`github-personal` for glats); repos on mact2 would use `git@github-personal` remote URLs

### Implementation Plan Sketch

1. **Linux (home-linux/git.nix)**: Add conditional include for work repos
   - Default identity stays as-is (glats/Juan Cuzmar)
   - Add `programs.git.includes` with `condition = "gitdir:~/Work/**"` → jcuzmar work identity
   - SSH not needed — Linux uses HTTPS + token

2. **macOS (home-darwin/git.nix)**: Refactor existing includeIf + add glats override
   - Default identity stays as-is (jcuzmar work)
   - Refactor existing `settings.includeIf."gitdir:~/Work/**"` to use `programs.git.includes` instead
   - Add new conditional include for personal repos: `condition = "gitdir:~/Personal/**"` → glats identity
   - OR: simpler approach — repos already use `git@github-personal` SSH remote, which maps to different SSH key

3. **Secrets decisions needed**:
   - Do we want SSH keys managed via sops (for cross-host portability)?
   - Do we need separate PATs for glats vs jcuzmar? Current single PAT may be enough

## Risks

1. **SSH vs HTTPS divergence**: Linux uses HTTPS auth (via `GH_TOKEN` in shell init); macOS uses SSH. Any solution should account for both auth models.
2. **GPG signing mismatch**: macOS has GPG signing configured; Linux does not. If work repos require signed commits, Linux hosts would need GPG setup too.
3. **omarchy-nix interference on t14**: `lib.mkForce` is already needed on user.name/email — new includeIf patterns must also use `mkForce` or be ordered correctly.
4. **includeIf evaluation order**: Git processes `includeIf` directives in order. The default `user` block must come first, then conditionals override.
5. **No existing SSH key secret management**: SSH keys are managed out-of-band currently. If we want sops-managed SSH keys, that adds complexity.

## Next Phase
**sdd-propose** — develop formal proposal with chosen approach, scope, and rollback plan.
