# Exploration: scrub-sensitive-data

## Current State

### Sensitive Data Inventory

#### 1. Personal Identifiable Information (PII) in plaintext Nix files

| Type | Value | File | Line |
|------|-------|------|------|
| Full name | `"Redacted Name"` | `shared/git-identity.nix` | 3 |
| Personal email | `"personal@example.com"` | `shared/git-identity.nix` | 4 |
| Work email | `"work@example.com"` | `shared/git-identity.nix` | 9 |

**Root cause**: `shared/git-identity.nix` is a plaintext attrset containing PII directly as Nix string literals. It is imported by `home-linux/git.nix` and `home-darwin/git.nix` to provide git configuration values.

#### 2. PII in documentation

| File | Content |
|------|---------|
| `docs/multi-github-identity.md` | Full name, both emails, gpg key setup instructions |

#### 3. PII in OpenSpec specs (live, not archived)

| File | Content |
|------|---------|
| `openspec/specs/gh-auth/spec.md` | `"Redacted Name"`, `"personal@example.com"` in requirement table |

#### 4. PII in archived OpenSpec artifacts

Six archived changes contain references to `work@example.com`, `personal@example.com`, and `"Redacted Name"`:

- `openspec/changes/archive/2026-07-06-multi-github-identity/` (specs, design, tasks, exploration, proposal)
- `openspec/changes/archive/2026-06-30-gh-auth-sops/` (specs, design, tasks, proposal)

#### 5. Identity name convention: `glats` (personal) vs `jcuzmar` (work)

The codebase uses two identity labels across 30+ files. **Critical distinction**:

| Category | Label | Meaning | Can rename? |
|----------|-------|---------|-------------|
| Git identity attrset key | `glats` | Personal git/GPG identity | YES |
| Git identity attrset key | `jcuzmar` | Work git/GPG identity | YES |
| Sops secret paths | `github/pat` (=glats), `github/pat_jcuzmar`, `gpg_glats_*`, `gpg_jcuzmar_*` | PAT/GPG secrets | YES (with sops edit) |
| MCP wrapper binaries | `github-mcp-server-glats`, `github-mcp-server-jcuzmar` | Wrapper script names | YES |
| MCP config names | `github-glats`, `github-jcuzmar` | OpenCode MCP entries | YES |
| **System username** (Linux) | `glats` | OS login name: `/home/glats`, `users.users.glats` | **NO** - tied to OS |
| **System username** (macOS) | `jcuzmar` | OS login name: `/Users/jcuzmar`, `home.username` | **NO** - tied to OS |
| SSH remote user | `glats` on Linux hosts | Actual remote OS username | **NO** - must match remote system |
| SSH remote user | `jcuzmar` on `mact2.local` | Actual remote OS username | **NO** - must match remote system |
| Color theme slug | `"glats"` | palette.nix, omarchy theme name | YES (but cosmetic) |
| Sops age key alias | `admin_glats` | `.sops.yaml` YAML anchor | YES |

### Current Identity Architecture

```
shared/git-identity.nix   <-- PLAINTEXT PII HERE
  ├── glats attrset: { name, email, signingKey }
  └── jcuzmar attrset: { name, email, signingKey }
       │
       ├── home-linux/git.nix  (imports, uses identities.glats.*, identities.jcuzmar.*)
       ├── home-darwin/git.nix (imports, uses identities.jcuzmar.*, identities.glats.*)
       ├── home-linux/gpg.nix  (imports GPG keys from sops by identity label)
       └── home-darwin/gpg.nix (same)

sops secrets:                         Nix references:
  github/pat               ────────→  modules/base/sops.nix, shared/sops.nix,
  github/pat_jcuzmar       ────────→    github-mcp-server.nix, home-linux/shell.nix
  github/gpg_glats_*       ────────→  home-linux/gpg.nix, home-darwin/gpg.nix
  github/gpg_jcuzmar_*     ────────→  shared/sops.nix
  github/token             ────────→  home-darwin/github-mcp-server-wrapper.nix
```

## Affected Areas

### Tier 1: Files containing PII that MUST change (encryption target)

| File | Action |
|------|--------|
| `shared/git-identity.nix` | Replace plaintext name/email with sops secret references |
| `docs/multi-github-identity.md` | Redact PII, reference sops instead of hardcoded values |
| `openspec/specs/gh-auth/spec.md` | Redact PII from main spec |
| All archived OpenSpec artifacts | Redact or accept as historical (archive is audit trail) |

### Tier 2: Files referencing identity labels (rename target)

| File | Action |
|------|--------|
| `shared/git-identity.nix` | Rename `glats`→`personal`, `jcuzmar`→`business` |
| `home-linux/git.nix` | Update attrset key references |
| `home-darwin/git.nix` | Update attrset key references |
| `home-linux/gpg.nix` | Rename importKey labels, sops secret paths |
| `home-darwin/gpg.nix` | Same |
| `shared/sops.nix` | Rename secret declarations (paths and attrset keys) |
| `modules/base/sops.nix` | Rename `pat_jcuzmar`→`pat_business`, update owner/group |
| `modules/features/services/github-mcp-server.nix` | Rename wrapper names |
| `home-darwin/github-mcp-server-wrapper.nix` | Rename wrapper names |
| `shared/opencode/mcps-base.nix` | Rename MCP config keys |
| `modules/features/services/github-token-check.nix` | Rename check_token labels |
| `flake.nix` | Update username params (keep OS usernames, rename identity labels if any) |
| `secrets/shared/passwords.yaml` | Rename keys via `sops edit` |

### Tier 3: Files with system usernames (MUST NOT rename)

| File | Reason |
|------|--------|
| `modules/base/users.nix` | `users.users.glats` - Linux system user |
| `modules/base/home-manager.nix` | `username = "glats"`, `users.glats.imports` |
| `lib/mkHost.nix` | `username ? "glats"` - Linux system user default |
| `lib/mkDarwinHost.nix` | `username ? "jcuzmar"` - macOS system user default |
| `home-darwin/default.nix` | `home.username = primaryUser` (resolves to jcuzmar) |
| `home-darwin/shell.nix` | `/etc/profiles/per-user/jcuzmar/bin` - macOS user path |
| `home-darwin/opencode/mcps-extra.nix` | `/Users/jcuzmar/` - macOS home path |
| `home-linux/ssh.nix` | `User = "glats"` / `User = "jcuzmar"` - remote OS usernames |
| `home-darwin/ssh.nix` | `User = "glats"` - remote OS usernames |
| Various host services | `glats` as service user (wetty, code-server, samba) |

### Tier 4: Git history (scrub target)

All commits in repository history may contain:
- `"Redacted Name"` - full name
- `work@example.com` - work email (domain reveals employer)
- `personal@example.com` - personal email
- SSH public keys (in `users.nix` - public, not PII, but related to identity)

## Approaches

### Problem 1: Encrypting PII values (name + emails)

| Approach | Pros | Cons | Complexity |
|----------|------|------|------------|
| **A. Sops secrets per field** - Create sops secrets `identity/personal_name`, `identity/personal_email`, `identity/business_name`, `identity/business_email` in `secrets/user/opencode.yaml` or new file. Read at HM activation via `config.sops.secrets.X.path`. | Standard sops pattern already used for GPG keys. Secrets never in Nix store. | Requires file read at runtime (not available as Nix string at eval time). Needs activation script or wrapper for git config. | MEDIUM |
| **B. Single sops identity file** - Store a YAML/JSON file under sops with all identity info (`secrets/user/identities.yaml`). Parse at runtime via `builtins.fromJSON` + `builtins.readFile`. | Single source of truth. Can contain all identity fields. | `builtins.readFile` reads at eval time - file must be decrypted BEFORE Nix evaluation. Home Manager handles this since sops secrets are decrypted to `/run/secrets/` before HM activation. But the sops path is in the Nix store at eval time, not the decrypted content. | HIGH |
| **C. GPG signing keys from sops (already done), names/emails stay in git** - Only encrypt what's already encrypted (tokens, GPG keys). Accept that names/emails are in git. | Zero additional complexity. Builds work without runtime decryption. | Does NOT satisfy the requirement to encrypt names/emails. | LOW |
| **D. Identity as file read at git config time** - Store encrypted identity file, use `includeIf` + `include.path` to point git at the decrypted file location. | Git natively supports this. No HM magic needed. | Requires sops decryption to a known path. HM already does this to `/run/secrets/` on Linux and somewhere under home on macOS. | MEDIUM |

### Problem 2: Renaming `glats`/`jcuzmar` → `personal`/`business`

| Approach | Pros | Cons | Complexity |
|----------|------|------|------------|
| **A. Full rename** - Change all references in Nix files, sops secret paths, MCP config names, wrapper binaries. | Clean, consistent. No legacy labels. | Touches 30+ files. MCP config in OpenCode needs manual update. Existing sops secrets need key rename. | MEDIUM |
| **B. Alias-compatible rename** - Keep old sops paths working via backward compat aliases, rename only Nix attrset keys. | Safer rollout. Won't break existing deployments immediately. | Leaves tech debt. Two naming systems coexist. | MEDIUM |
| **C. Two-phase rename** - Phase 1: encrypt PII, keep label names. Phase 2: separate PR for rename. | Each PR is independently reviewable and revertible. | Requires 2 PRs. More total work. | MEDIUM |

### Problem 3: Git history scrubbing

| Approach | Pros | Cons | Complexity |
|----------|------|------|------------|
| **A. `git filter-repo`** - Official replacement for filter-branch. Python-based. `git filter-repo --path <file> --replace-text <replacements.txt>` | Fast, reliable, handles all refs. Can replace text patterns across history. | Rewrites ALL history (all SHAs change). Force push to GitHub required. Any clones become stale. Open PRs/branches invalidated. | MEDIUM |
| **B. BFG Repo-Cleaner** - Java-based, simpler API. `bfg --replace-text replacements.txt` | Faster for large repos. Simple text replacement. | Same SHA-rewrite implications. Less granular control than filter-repo. | LOW |
| **C. Selective file removal + rebase** - Only scrub specific files from history. | More targeted. | Leaves PII in other files (docs, openspec artifacts). Complex for multi-file replacement. | HIGH |
| **D. Squash history** - Single commit replacing entire history. | Simplest history. | Loses all commit history context. Extreme approach. | LOW |

### Problem 4: Impact of history rewrite

This is a single-user repo (`glats/.nixos`). The implications:

| Concern | Impact | Mitigation |
|---------|--------|------------|
| Force push to GitHub | Required. All refs are rewritten. | Coordinate with any other clones (none expected). |
| Open branches/PRs | Any open PRs become unmergeable. | Check for open PRs first. Rebase onto rewritten history. |
| Worktrees | Git worktrees may break. | Prune worktrees before rewriting (`code-work --done` for all). |
| Sops encrypted files | Encrypted content stays intact; history of plaintext IS scrubbed. | The encrypted blobs don't contain searchable plaintext. |
| `.sops.yaml` keys | Age public keys in `.sops.yaml` are public and unchanged. | No impact. |
| GitHub repo settings | No impact (repo settings, webhooks, etc. are server-side). | None. |

## Recommendation

### Recommended approach: Staged implementation

**Stage 1: Encrypt PII in `shared/git-identity.nix`** (Approach 1A + 1D hybrid):

1. Create a new sops file `secrets/user/identities.yaml` containing:
   ```yaml
   personal:
       name: "Redacted Name"
       email: "personal@example.com"
   business:
       name: "business-user"
       email: "business@example.com"
   ```
2. Create a small activation-time script that reads sops-decrypted identity values into a git-compatible format (separate gitconfig files).
3. Replace `shared/git-identity.nix` to reference sops secret paths for name/email (keeping signingKey fingerprints as-is since they're public).
4. Update `home-linux/git.nix` and `home-darwin/git.nix` to use the new mechanism.
5. Update `openspec/specs/gh-auth/spec.md` to use placeholder values.
6. Redact `docs/multi-github-identity.md`.

**Stage 2: Rename identity labels** (Approach 2A, full rename):

1. Rename `glats`→`personal` and `jcuzmar`→`business` in:
   - `shared/git-identity.nix` attrset keys
   - All consumer Nix files (`home-linux/git.nix`, `home-darwin/git.nix`, `home-linux/gpg.nix`, `home-darwin/gpg.nix`)
   - Sops secret paths: `github/pat_jcuzmar`→`github/pat_business`, `gpg_jcuzmar_*`→`gpg_business_*`, `gpg_glats_*`→`gpg_personal_*`
   - MCP wrapper names: `github-mcp-server-glats`→`github-mcp-server-personal`, `github-mcp-server-jcuzmar`→`github-mcp-server-business`
   - MCP config names in `shared/opencode/mcps-base.nix`
   - Token check labels in `github-token-check.nix`
2. Add backward-compat aliases in sops declarations for one release cycle.
3. Do NOT rename system usernames (`glats` on Linux, `jcuzmar` on macOS), SSH users, or home directory paths.

**Stage 3: Scrub git history** (Approach 3A, `git filter-repo`):

1. After Stages 1-2 are committed and stable, run `git filter-repo` with a replacements file.
2. Force push to GitHub.
3. Verify: `git log --all --oneline | xargs -I{} git show {} | grep -i "[redacted]"` should return nothing.

### Key design decisions

1. **sops for identity values**: Store encrypted name/email in a new `secrets/user/identities.yaml`. Use HM activation scripts to write git-compatible config fragments to a known path.

2. **System usernames are sacred**: `glats` on Linux and `jcuzmar` on macOS are OS-level usernames. They appear in `/etc/passwd`, home directory paths, and SSH configs. These MUST NOT change.

3. **GPG fingerprints stay public**: The signing key fingerprints are already in plaintext Nix and are public identifiers by design. Keep them in the Nix attrset.

4. **Archived OpenSpec artifacts**: Optionally redact, or accept that the archive directory is a historical audit trail. Redacting archive artifacts that have already been committed to git history is futile if the goal is to scrub history anyway (Stage 3 handles this).

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Git history rewrite breaks worktrees | HIGH | MEDIUM | Prune all worktrees before rewrite |
| Force push breaks any other clones | LOW | HIGH | Verify no other contributors exist |
| HM activation fails if sops secrets not available | MEDIUM | HIGH | Add fallback: if secret file missing, skip identity config with warning |
| OpenCode MCP config incompatible after rename | MEDIUM | LOW | OpenCode auto-discovers MCPs from config; will pick up new names automatically |
| Build fails during Stage 1 transition if secret paths don't exist yet | MEDIUM | HIGH | Use `sops.secrets.X.path` with conditional: `lib.mkIf (config.sops.secrets ? "identity/personal_name")` |
| `nix flake check --no-build` passes but runtime fails | MEDIUM | MEDIUM | Test with `nixos-build dry` on at least one host before Stage 3 |
| Sops edit changes `passwords.yaml` key names, old keys linger | LOW | LOW | Clean up old keys after verifying new ones work |

## Skill Resolution

none
