# Design: scrub-sensitive-data

## Technical Approach

Three-stage implementation with backward-compat aliases bridging Stage 2 migrations.
Each stage is independently committable and verifiable via `nix flake check --no-build`.

### Stage 1: Encrypt PII
Replace plaintext name/email in `shared/git-identity.nix` with sops-encrypted values
decrypted at Home Manager activation time and written as git include files.

### Stage 2: Rename Identity Labels
Rename `glats` -> `personal`, `jcuzmar` -> `work` across all Nix attrset keys,
sops secret paths, MCP wrappers, and MCP config names. Add backward-compat
aliases for one transition cycle. System usernames and SSH configs are
untouched.

### Stage 3: Scrub Git History
`git filter-repo` with text + mailmap replacements to remove `Redacted Name`,
`work@example.com`, and `personal@example.com` from all reachable
history. Force push to GitHub after worktree pruning and open-PR check.

---

## Architecture Decisions

### Decision 1: sops Identity File Structure

**Structure**: Single encrypted file `secrets/user/identities.yaml` with two
top-level YAML keys (`personal`, `work`), each containing nested `name` and
`email`:

```yaml
personal:
    name: "Redacted Name"
    email: "personal@example.com"
work:
    name: "jcuzmar"
    email: "work@example.com"
```

**sops secret declarations**: Two secrets, one per top-level key:

```nix
sops.secrets."identities/personal" = {
  sopsFile = ../secrets/user/identities.yaml;
  mode = "0400";
};
sops.secrets."identities/work" = {
  sopsFile = ../secrets/user/identities.yaml;
  mode = "0400";
};
```

When sops-nix decrypts `identities/personal`, the decrypted data at
`config.sops.secrets."identities/personal".path` is:

```
name: Redacted Name
email: personal@example.com
```

**Rationale**: This follows the spec's required structure (personal/work blocks
with name/email) while keeping decrypted content simple to parse (just `name:`
and `email:` lines). Two secrets per file is a standard sops-nix pattern -- the
decrypted content of each secret is independent. GPG signing fingerprints
remain in `shared/git-identity.nix` (they are public identifiers).

**`.sops.yaml` rules**: The existing catch-all rule for `secrets/user/.+` covers
`secrets/user/identities.yaml` with `admin_glats` + Linux host keys. mact2
is NOT in this rule, but identities are needed on mact2 too. The `.sops.yaml`
must be updated to either:
- Add a specific rule for `secrets/user/identities.yaml` including `host_mact2`, or
- Expand the catch-all `secrets/user/.+` to include `host_mact2`

**Decision**: Add a specific rule. The existing catch-all is intentionally
Linux-only; expanding it would also encrypt `atlassian.yaml` on Linux hosts
unnecessarily.

```yaml
# .sops.yaml addition
- path_regex: secrets/user/identities.yaml
  key_groups:
    - age:
        - *admin_glats
        - *host_rog
        - *host_thinkcentre
        - *host_t14
        - *host_mact2
```

### Decision 2: Reading sops Values at HM Activation

**Problem**: `builtins.readFile` evaluates at Nix eval time, before sops
secrets are decrypted. sops-nix places decrypted files at `/run/secrets/` on
Linux and `~/.config/sops-nix/secrets/` on macOS only DURING HM activation.

**Pattern used**: Home Manager activation scripts (`home.activation.*`),
entered after `writeBoundary` (the same pattern used by `gpg.nix` to import
GPG keys from sops). At this point, `config.sops.secrets."X".path` points to
a decrypted file.

**Mechanism**: A `home.activation.writeGitIdentity` script reads the decrypted
identity files and writes git-compatible include files to
`~/.config/git/identity-personal` and `~/.config/git/identity-work`. These
files are then referenced by `programs.git.extraConfig` via git's
`include.path` directive (on Linux) or `programs.git.includes` (on Darwin).

**Graceful degradation**: If the sops secret file does not exist (pre-bootstrap
state), the activation script skips silently with exit 0. This prevents HM
activation from failing when sops has not yet initialized.

**No `builtins.readFile` in Nix eval**: The git config values are never
materialized as Nix strings. They flow from sops-encrypted YAML, through bash
activation script, into files that git reads at runtime. This avoids any
eval-time dependency on decrypted secrets.

### Decision 3: Label Rename Map

| Category | Old | New |
|----------|-----|-----|
| Identity attrset keys | `glats` | `personal` |
| Identity attrset keys | `jcuzmar` | `work` |
| Sops secret path (PAT) | `github/pat_jcuzmar` | `github/pat_work` |
| Sops secret path (GPG) | `github/gpg_jcuzmar_fingerprint` | `github/gpg_work_fingerprint` |
| Sops secret path (GPG) | `github/gpg_jcuzmar_key` | `github/gpg_work_key` |
| Sops secret path (GPG) | `github/gpg_glats_fingerprint` | `github/gpg_personal_fingerprint` |
| Sops secret path (GPG) | `github/gpg_glats_key` | `github/gpg_personal_key` |
| MCP wrapper binary (Linux) | `github-mcp-server-glats` | `github-mcp-server-personal` |
| MCP wrapper binary (Linux) | `github-mcp-server-jcuzmar` | `github-mcp-server-work` |
| MCP wrapper binary (Darwin) | `github-mcp-server-glats` | `github-mcp-server-personal` |
| MCP wrapper binary (Darwin) | `github-mcp-server-jcuzmar` | `github-mcp-server-work` |
| MCP config key | `github-glats` | `github-personal` |
| MCP config key | `github-jcuzmar` | `github-work` |
| Token check label | `"glats"` | `"personal"` |
| Token check label | `"jcuzmar"` | `"work"` |
| Sops secret path (identities) | (new) | `identities/personal`, `identities/work` |

**NOT renamed** (system usernames, tied to OS):
- `users.users.glats` on Linux hosts
- `home.username = "glats"` on Linux hosts
- `home.username = primaryUser` resolving to `"jcuzmar"` on macOS
- `/home/glats/` paths on Linux
- `/Users/jcuzmar/` paths and macOS per-user profile paths on Darwin
- `username ? "glats"` default in `lib/mkHost.nix`
- `username ? "jcuzmar"` default in `lib/mkDarwinHost.nix`
- SSH `User` directives (`User = "glats"`, `User = "jcuzmar"`) -- remote OS usernames
- `github/pat` (remaining unchanged -- this is the primary glats PAT and was
  already generic)
- SSH host aliases: `github-personal`, `github-enterprise` (already use
  non-leaking names)
- Omarchy theme slug `"glats"` (cosmetic, no PII)

### Decision 4: MCP Wrapper Transition

**Linux** (`modules/features/services/github-mcp-server.nix`):
- Create new wrappers `github-mcp-server-personal` and `github-mcp-server-work`
  alongside the old wrappers
- During Stage 2, the module produces ALL FOUR wrappers (old + new)
- Old wrappers are removed in the alias-cleanup commit (after all hosts rebuilt)

**Darwin** (`home-darwin/github-mcp-server-wrapper.nix`):
- Same pattern: create new wrappers alongside old ones
- The Darwin `jcuzmar` wrapper reads `github/token` from `atlassian.yaml` --
  keep this existing behavior. After Stage 2, the new `github-mcp-server-work`
  wrapper reads from `identities/work` via a different approach (see note below).

**Note on Darwin work identity**: The Darwin work wrapper currently reads
`github/token` from `atlassian.yaml`. This is a separate encrypted file with
different keys. In Stage 2, the new `work` wrapper reads `identities/work`
from the new `secrets/user/identities.yaml`. The old path should work
alongside the new one during transition.

### Decision 5: Transition Strategy

**Dual-key approach for sops**:

During Stage 2, the `secrets/shared/passwords.yaml` encrypted file keeps BOTH
old and new keys with identical values:

```yaml
# passwords.yaml (encrypted -- structure shown for documentation)
github:
    pat: ENC[...]                  # unchanged (personal PAT)
    pat_jcuzmar: ENC[...]          # OLD - keep during transition
    pat_work: ENC[...]             # NEW - same value as pat_jcuzmar
    gpg_glats_fingerprint: ENC[...]   # OLD
    gpg_personal_fingerprint: ENC[...] # NEW
    gpg_glats_key: ENC[...]            # OLD
    gpg_personal_key: ENC[...]         # NEW
    gpg_jcuzmar_fingerprint: ENC[...]  # OLD
    gpg_work_fingerprint: ENC[...]     # NEW
    gpg_jcuzmar_key: ENC[...]          # OLD
    gpg_work_key: ENC[...]             # NEW
```

Old sops secret declarations in `shared/sops.nix` keep referencing old YAML
keys. New declarations reference new YAML keys. Both old and new Nix
declarations coexist for one cycle. The old declarations are removed in a
cleanup commit after all hosts verify.

**Transition order across the codebase**:

1. **Commit A**: Add new keys to encrypted files (both old and new coexist)
2. **Commit B**: Add new sops secret declarations alongside old ones
3. **Commit C**: Rename all Nix file references, MCP wrappers, MCP configs
4. **Commit D**: Remove old sops secret declarations
5. **Commit E**: Remove old keys from encrypted files

In practice, merge A+B+C into one commit, then D+E into a cleanup commit.

### Decision 6: filter-repo Execution Plan

**Command**:

```bash
# 1. Prerequisites
git worktree list                  # Verify only main worktree
code-work --done                   # For each active worktree
tag_before=$(git rev-parse HEAD)
git tag pre-history-scrub "$tag_before"
gh pr list --state open            # Must be empty

# 2. Create replacements file
cat > /tmp/scrub-replacements.txt <<'EOF'
Redacted Name==>Redacted Name
work@example.com==>work@example.com
personal@example.com==>personal@example.com
EOF

# 3. Create mailmap for author/committer metadata
cat > /tmp/scrub-mailmap.txt <<'EOF'
Redacted Name <personal@example.com> Redacted Name <personal@example.com>
Redacted Name <work@example.com> Redacted Name <work@example.com>
EOF

# 4. Run filter-repo (requires git-filter-repo package)
git filter-repo \
  --replace-text /tmp/scrub-replacements.txt \
  --mailmap /tmp/scrub-mailmap.txt \
  --force

# 5. Post-scrub validation
nix flake check --no-build
format-nix
git diff --stat                  # Verify clean

# 6. Force push all refs
git push --force --all origin
git push --force --tags origin

# 7. Clone check
cd /tmp && rm -rf test-scrub-clone
git clone https://github.com/glats/.nixos.git test-scrub-clone
cd test-scrub-clone
git log --all --oneline | xargs -I{} git show {} 2>/dev/null | grep -i "[redacted]"  # Must be empty
nix flake check --no-build
```

**Backup strategy**: The `pre-history-scrub` tag preserves the pre-scrub HEAD
SHA. If the rewrite produces unexpected results, restore with:

```bash
git fetch origin refs/tags/pre-history-scrub:refs/tags/pre-history-scrub
git reset --hard pre-history-scrub
git push --force origin HEAD
```

**Validation checklist**:
- Zero `[redacted]` in `git log --all` content
- Zero `Redacted Name` in `git log --all` content
- Zero `personal@example.com` in `git log --all` content
- `git log --all --format="%ae" | sort -u` shows only `personal@example.com` and `work@example.com`
- `nix flake check --no-build` passes on rewritten history
- `format-nix` produces zero diff
- `sops -d secrets/shared/passwords.yaml` works (encrypted blobs unaffected)
- Fresh clone from remote is PII-free

### Decision 7: System Username Guards

**Guard 1 -- Code review checklist**: Every commit in this change MUST be
reviewed with `git diff --color-words` checking that these patterns are NOT
removed or altered:
- `users.users.glats`
- `home.username = "glats"`
- `"/home/glats/`
- `"/Users/jcuzmar/`
- `User = "glats"` in `home-linux/ssh.nix`
- `User = "jcuzmar"` in `home-darwin/ssh.nix`
- `username ? "glats"` in `lib/mkHost.nix`
- `username ? "jcuzmar"` in `lib/mkDarwinHost.nix`

**Guard 2 -- Spec requirement**: The `identity-label-rename` spec includes
explicit scenarios ("No Renames of System Usernames", "SSH Remote Users
Unchanged") with grep-based acceptance criteria.

**Guard 3 -- filter-repo exclusions**: The filter-repo replacements target
only full name and email domains. They do NOT match `glats` or `jcuzmar`
as standalone tokens (only `Redacted Name` as a two-word phrase and the full
email addresses). This prevents accidental scrubbing of system usernames
from history.

---

## Component Architecture

```
secrets/user/identities.yaml (sops-encrypted)
  |
  |-- [yaml key: personal] --> sops.secrets."identities/personal".path
  |                              |
  |                              v
  |     home.activation.writeGitIdentity
  |     (reads decrypted file with awk, writes git include file)
  |                              |
  |                              v
  |     ~/.config/git/identity-personal  <-- git [include] path
  |
  |-- [yaml key: work] --> sops.secrets."identities/work".path
                                |
                                v
       home.activation.writeGitIdentity
                                |
                                v
       ~/.config/git/identity-work  <-- git [includeIf "gitdir:~/Work/**"] path


shared/git-identity.nix (post-Stage-1)
  |
  |-- personal = { signingKey = "CFD6..."; }    (no name/email -- from sops)
  |-- work     = { signingKey = "B658..."; }    (no name/email -- from sops)
  |
  v
home-linux/git.nix  (uses identities.personal.signingKey, identities.work.signingKey)
home-darwin/git.nix (same)
home-linux/gpg.nix  (uses config.sops.secrets."github/gpg_personal_*" etc.)
home-darwin/gpg.nix (same)
```

**Flow for Linux default identity resolution**:
1. HM activation: sops-nix decrypts `secrets/user/identities.yaml` -> `/run/secrets/identities/personal`
2. `home.activation.writeGitIdentity` (runs after `writeBoundary`):
   - Reads `/run/secrets/identities/personal` with awk
   - Extracts `name` and `email` lines
   - Writes `[user]` section to `~/.config/git/identity-personal`
3. git reads `~/.config/git/identity-personal` via `include.path` in `~/.config/git/config`
4. `git config user.name` returns the name from sops (NOT from Nix store)

**Flow for Linux Work/** identity resolution**:
1. Same activation writes `~/.config/git/identity-work` from decrypted work identity
2. git reads it via `includeIf "gitdir:~/Work/**"` directive
3. Combined with signing config from HM's `programs.git.includes`

---

## File-by-File Changes

### Stage 1 -- Encrypt PII

#### 1a. `secrets/user/identities.yaml` (NEW -- sops-encrypted)

Create via `sops secrets/user/identities.yaml` with content:

```yaml
personal:
    name: "Redacted Name"
    email: "personal@example.com"
work:
    name: "jcuzmar"
    email: "work@example.com"
```

**Action**: `sops edit` to create with real values, then git-add the encrypted result.

#### 1b. `.sops.yaml`

Add a specific creation rule before the catch-all `secrets/user/.+` rule:

```yaml
  # Identities file -- needed on all hosts including macOS
  - path_regex: secrets/user/identities.yaml
    key_groups:
      - age:
          - *admin_glats
          - *host_rog
          - *host_thinkcentre
          - *host_t14
          - *host_mact2
```

**Rationale**: The existing `secrets/user/.+` catch-all excludes mact2
(intentionally -- `atlassian.yaml` is macOS-only). The identities file is
needed on ALL hosts (GitHub MCP on Linux, work identity on Darwin).

#### 1c. `shared/git-identity.nix`

Strip name/email from attrset values. Keep only GPG signing key fingerprints:

```nix
{
  personal = {
    signingKey = "CFD6C7FED46F6870BE13CE87D39580F75062BEFC";
  };
  work = {
    signingKey = "B658D64F6FDBCFD1EBA53509A1D4ECB0118566C8";
  };
}
```

**Key change**: Attrset keys are renamed here (glats -> personal, jcuzmar -> work)
as part of Stage 1 to minimize churn. Backward-compat aliases are not needed
for Nix attrset keys since they're compile-time references. The rename happens
atomically with consumers in the same commit.

#### 1d. `shared/sops.nix`

Add identity secret declarations to the shared (cross-platform) HM sops module:

```nix
  # Identity values from sops (name + email for git/GPG)
  sops.secrets."identities/personal" = {
    sopsFile = ../secrets/user/identities.yaml;
    mode = "0400";
  };
  sops.secrets."identities/work" = {
    sopsFile = ../secrets/user/identities.yaml;
    mode = "0400";
  };
```

#### 1e. `home-linux/git.nix` (major rewrite)

Replace the plaintext identity approach with activation-written include files:

```nix
{ config, lib, pkgs, ... }:

let
  identities = import ../shared/git-identity.nix;
in
{
  programs.git = {
    enable = true;
    settings = {
      core.editor = "nvim -u NONE";
      core.pager = "delta";
      delta.enable = true;
      gpg.program = "${pkgs.gnupg}/bin/gpg";
      # Placeholder -- overridden by identity-personal include file
      user.name = lib.mkForce "placeholder";
      user.email = lib.mkForce "placeholder";
    };

    signing = { format = "openpgp"; }
      // lib.optionalAttrs (identities.personal.signingKey != "") {
        key = identities.personal.signingKey;
        signByDefault = true;
      };

    # Default identity from activation-written file
    extraConfig = ''
      [include]
          path = ~/.config/git/identity-personal
      [includeIf "gitdir:~/Work/**"]
          path = ~/.config/git/identity-work
    '';

    # Work signing config (GPG keys are public, stay in Nix)
    includes = [
      {
        condition = "gitdir:~/Work/**";
        contents = {
          user.signingKey = identities.work.signingKey;
          commit.gpgsign = true;
        };
      }
    ];
  };

  # Write git identity include files from sops-decrypted secrets at activation time.
  # Runs after writeBoundary (same timing as gpg.nix key import).
  # Gracefully skips if sops secrets are not yet available.
  home.activation.writeGitIdentity = lib.hm.dag.entryAfter ["writeBoundary"] ''
    _write_identity() {
      _mode="$1"
      _secrets_file="${config.sops.secrets."identities/$_mode".path}"
      _out_file="$HOME/.config/git/identity-$_mode"

      if [ ! -f "$_secrets_file" ]; then
        return 0  # skip silently if sops secrets not available
      fi

      mkdir -p "$(dirname "$_out_file")"
      _name="$(${pkgs.gawk}/bin/awk -F': ' '/^name:/ {gsub(/"/, ""); print $2; exit}' "$_secrets_file")"
      _email="$(${pkgs.gawk}/bin/awk -F': ' '/^email:/ {gsub(/"/, ""); print $2; exit}' "$_secrets_file")"
      printf "[user]\n    name = %s\n    email = %s\n" "$_name" "$_email" > "$_out_file"
    }
    _write_identity "personal"
    _write_identity "work"
  '';
}
```

**Design note**: `user.name` and `user.email` in `programs.git.settings` are set
to placeholder values via `lib.mkForce` (needed on t14 where omarchy-nix
writes `glats@local`). The real values come from the include files written
at activation. git's `include.path` overrides inline values for the same keys
(last-write-wins in git config).

#### 1f. `home-darwin/git.nix` (major rewrite)

Same pattern as Linux but with Darwin-specific identity layout:

```nix
{ pkgs, config, primaryUser, lib, ... }:

let
  identities = import ../shared/git-identity.nix;
in
{
  programs.git = {
    enable = true;
    lfs.enable = true;
    ignores = [ "**/.DS_STORE" ];

    settings = {
      user = {
        name = "placeholder";
        email = "placeholder";
      };
      github.user = primaryUser;
      init.defaultBranch = "main";
      core.editor = "nvim -u NONE";
      gpg.program = "${pkgs.gnupg}/bin/gpg";
    };

    signing = {
      key = identities.work.signingKey;
      signByDefault = true;
    };

    # Default: work identity via activation-written file
    extraConfig = ''
      [include]
          path = ~/.config/git/identity-work
      [includeIf "gitdir:~/Personal/**"]
          path = ~/.config/git/identity-personal
    '';

    includes = [
      {
        condition = "gitdir:~/Work/**";
        contents = {
          user.signingKey = identities.work.signingKey;
          commit.gpgsign = true;
        };
      }
    ] ++ lib.optional (identities.personal.signingKey != "") {
      condition = "gitdir:~/Personal/**";
      contents = {
        user.signingKey = identities.personal.signingKey;
        commit.gpgsign = true;
      };
    };
  };

  home.activation.writeGitIdentity = lib.hm.dag.entryAfter ["writeBoundary"] ''
    _write_identity() {
      _mode="$1"
      _secrets_file="${config.sops.secrets."identities/$_mode".path}"
      _out_file="$HOME/.config/git/identity-$_mode"
      if [ ! -f "$_secrets_file" ]; then return 0; fi
      mkdir -p "$(dirname "$_out_file")"
      _name="$(${pkgs.gawk}/bin/awk -F': ' '/^name:/ {gsub(/"/, ""); print $2; exit}' "$_secrets_file")"
      _email="$(${pkgs.gawk}/bin/awk -F': ' '/^email:/ {gsub(/"/, ""); print $2; exit}' "$_secrets_file")"
      printf "[user]\n    name = %s\n    email = %s\n" "$_name" "$_email" > "$_out_file"
    }
    _write_identity "work"
    _write_identity "personal"
  '';
}
```

#### 1g. `docs/multi-github-identity.md`

Replace all PII references with placeholder instructions:

- Replace `Redacted Name` -> `your personal name`
- Replace `personal@example.com` -> `your personal email`
- Replace `work@example.com` -> `your work email`
- Replace `glats` -> `personal` (identity label)
- Replace `jcuzmar` -> `work` (identity label, when used as identity not OS user)

The doc should reference that real values are stored in
`secrets/user/identities.yaml` (via sops).

#### 1h. `openspec/specs/gh-auth/spec.md`

Replace PII in the git identity requirement table:

```
| `user.name` | Value from `secrets/user/identities.yaml` |
| `user.email` | Value from `secrets/user/identities.yaml` |
```

And update scenario expectations from literal PII strings to "matches the
value from the sops identities file".

### Stage 2 -- Rename Identity Labels

**Note**: By this point, `shared/git-identity.nix` attrset keys are already
`personal`/`work` (renamed in Stage 1, commit 1c). All plaintext PII is
already gone from Nix files. Stage 2 renames the REMAINING old-label
references in sops paths, MCP names, MCP configs, and token check labels.

#### 2a. `secrets/shared/passwords.yaml` (sops edit)

Add NEW keys alongside OLD keys with identical values:

- `github/pat_work` (copies `github/pat_jcuzmar`)
- `github/gpg_personal_fingerprint` (copies `github/gpg_glats_fingerprint`)
- `github/gpg_personal_key` (copies `github/gpg_glats_key`)
- `github/gpg_work_fingerprint` (copies `github/gpg_jcuzmar_fingerprint`)
- `github/gpg_work_key` (copies `github/gpg_jcuzmar_key`)

**Action**: `sops edit secrets/shared/passwords.yaml` and copy-paste each value
to the new key. Both old and new keys coexist.

#### 2b. `shared/sops.nix` -- Add new declarations

Add new sops secret declarations alongside the old ones:

```nix
  # NEW: work PAT (renamed from pat_jcuzmar)
  sops.secrets."github/pat_work" = {
    sopsFile = ../secrets/shared/passwords.yaml;
    mode = "0400";
  };
  # NEW: GPG keys with personal/work naming
  sops.secrets."github/gpg_work_fingerprint" = {
    sopsFile = ../secrets/shared/passwords.yaml;
    mode = "0400";
  };
  # ... etc for all 4 new keys
```

Keep OLD declarations operational (they still point to old keys in
passwords.yaml). Both old and new declarations coexist.

#### 2c. `modules/base/sops.nix` -- System-level sops (Linux)

Rename the NixOS-level sops secret declarations:

```nix
sops.secrets."github/pat_work" = {
  owner = "glats";
  group = "users";
  mode = "0400";
};
```

Add the new declaration ALONGSIDE the old one. Remove old in cleanup commit.

Note: `github/pat` (personal) stays as-is -- it was already generic.

#### 2d. `home-linux/gpg.nix` -- Update sops path references

Change the importKey calls to use new sops paths:

```nix
home.activation.importGpgKeys = lib.hm.dag.entryAfter [ "writeBoundary" ]
  (importKey "work"
    config.sops.secrets."github/gpg_work_fingerprint".path
    config.sops.secrets."github/gpg_work_key".path
  + importKey "personal"
    config.sops.secrets."github/gpg_personal_fingerprint".path
    config.sops.secrets."github/gpg_personal_key".path
  );
```

**Rationale for importKey label change**: The first arg to importKey is a
log-only label used in the shell script's output (`gpg --list-secret-keys "$FINGERPRINT"`). Renaming from `jcuzmar`/`glats` to `work`/`personal` is a
cosmetic change in the bash script name variable -- no functional impact.

#### 2e. `home-darwin/gpg.nix` -- Same path renames

Mirror the Linux gpg.nix changes.

#### 2f. `modules/features/services/github-mcp-server.nix` -- MCP wrappers (Linux)

Add new wrapper variants alongside old ones. Old wrappers still work but
are superseded:

```nix
# NEW wrappers
githubMcpServerPersonal = mkGithubMcpWrapper {
  name = "github-mcp-server-personal";
  secretPath = config.sops.secrets."github/pat".path;
};

githubMcpServerWork = mkGithubMcpWrapper {
  name = "github-mcp-server-work";
  secretPath = config.sops.secrets."github/pat_work".path;
};

# OLD wrappers (keep for backward compat)
githubMcpServerGlats = mkGithubMcpWrapper {
  name = "github-mcp-server-glats";
  secretPath = config.sops.secrets."github/pat".path;
};

githubMcpServerJcuzmar = mkGithubMcpWrapper {
  name = "github-mcp-server-jcuzmar";
  secretPath = config.sops.secrets."github/pat_jcuzmar".path;
};
```

In `environment.systemPackages`, include all four. Remove old wrappers in the
cleanup commit after all hosts rebuilt.

#### 2g. `home-darwin/github-mcp-server-wrapper.nix` -- MCP wrappers (Darwin)

Same dual-wrapper approach:

```nix
# NEW
githubMcpServerPersonal = mkGithubMcpWrapper {
  name = "github-mcp-server-personal";
  secretPath = config.sops.secrets."github/pat".path;
};

githubMcpServerWork = mkGithubMcpWrapper {
  name = "github-mcp-server-work";
  secretPath = config.sops.secrets."github/pat_work".path;
};

# OLD (keep during transition)
githubMcpServerGlats = mkGithubMcpWrapper {
  name = "github-mcp-server-glats";
  secretPath = config.sops.secrets."github/pat".path;
};

githubMcpServerJcuzmar = mkGithubMcpWrapper {
  name = "github-mcp-server-jcuzmar";
  secretPath = config.sops.secrets."github/pat_work".path;  # points to new key
};
```

**Note on Darwin jcuzmar PAT path**: Previously read `github/token` from
`atlassian.yaml`. During Stage 2, the old wrapper is repointed to read the
new `pat_work` from `passwords.yaml` (it's the same token value). The new
`work` wrapper does the same.

#### 2h. `shared/opencode/mcps-base.nix` -- MCP config names

Add new MCP config entries alongside old ones:

```nix
defaultMcps = {
  "github-personal" = {
    type = "local";
    command = [ "github-mcp-server-personal" "stdio" ];
    enabled = true;
  };
  "github-work" = {
    type = "local";
    command = [ "github-mcp-server-work" "stdio" ];
    enabled = true;
  };

  # OLD (keep during transition)
  "github-glats" = {
    type = "local";
    command = [ "github-mcp-server-glats" "stdio" ];
    enabled = true;
  };
  "github-jcuzmar" = {
    type = "local";
    command = [ "github-mcp-server-jcuzmar" "stdio" ];
    enabled = true;
  };

  # ... rest unchanged
};
```

OpenCode auto-discovers all MCP entries. The old names still work during
transition. Users can manually remove old entries from their OpenCode
config as they adopt the new names.

#### 2i. `modules/features/services/github-token-check.nix` -- Token check labels

Update the `check_token` calls:

```nix
check_token "personal" "${config.sops.secrets."github/pat".path}"
check_token "work"    "${config.sops.secrets."github/pat_work".path}"
```

#### 2j. `home-linux/shell.nix` -- GH_TOKEN export

Update the GH_TOKEN setup in zsh init:

```nix
# The sops secret path for github/pat is unchanged, but update the
# warning message label and the sops edit instruction
if [ -f "${config.sops.secrets."github/pat".path}" ]; then
  export GH_TOKEN="$(cat ${config.sops.secrets."github/pat".path})"
  ( ${pkgs.gh}/bin/gh auth status --active --hostname github.com >/dev/null 2>&1 || \
    echo "WARNING: GitHub token (personal) expired! Create new PAT and: sops edit secrets/shared/passwords.yaml && nixos-build switch" >&2
  ) &
fi
```

Only the label text changes from `glats` to `personal`. The sops path stays
`github/pat`.

#### 2k. Cleanup commit -- Remove old labels

After all hosts rebuild successfully with new names:

- Remove OLD sops secret declarations from `shared/sops.nix` and
  `modules/base/sops.nix`
- Remove OLD keys from `secrets/shared/passwords.yaml` via `sops edit`
- Remove OLD MCP wrappers from `modules/features/services/github-mcp-server.nix`
  and `home-darwin/github-mcp-server-wrapper.nix`
- Remove OLD MCP config entries from `shared/opencode/mcps-base.nix`

### Stage 3 -- History Scrub

No code changes. Execute `git filter-repo` per the plan in Decision 6 above.

Files that MUST NOT be affected by the filter-repo:
- `secrets/**/*` -- encrypted blobs, filter-repo replacements won't match
  encrypted ciphertext
- `.sops.yaml` -- age public keys are public
- Binary files in the repository

---

## Stage Ordering (Exact Commit Sequence)

### Stage 1 commits (one atomic commit)

```
1. feat(identity): encrypt PII via sops, rename identity labels to personal/work

   Creates:
   - secrets/user/identities.yaml (sops-encrypted, real values)
   - .sops.yaml (add identities.yaml rule)

   Modifies:
   - shared/git-identity.nix (remove name/email, rename keys personal/work)
   - shared/sops.nix (add identity secret declarations)
   - home-linux/git.nix (activation-written git identity, include files)
   - home-darwin/git.nix (same for Darwin)
   - docs/multi-github-identity.md (redact PII, reference sops)
   - openspec/specs/gh-auth/spec.md (redact PII from live spec)
```

**Verification after Stage 1**:
- `grep -E "(Redacted Name|work@example\.com|personal@example\.com)" shared/git-identity.nix` returns zero
- `nix flake check --no-build` passes
- `format-nix` clean
- `git diff --stat` shows only the files listed above
- Secrets file decrypts with `sops -d secrets/user/identities.yaml`

### Stage 2 commits (two commits)

```
2. feat(identity): add work/personal sops keys and MCP wrappers alongside old ones

   Modifies:
   - secrets/shared/passwords.yaml (sops edit: add new keys with duplicate values)
   - shared/sops.nix (add new sops declarations alongside old)
   - modules/base/sops.nix (add pat_work declaration)
   - modules/features/services/github-mcp-server.nix (add personal/work wrappers)
   - home-darwin/github-mcp-server-wrapper.nix (add personal/work wrappers)
   - shared/opencode/mcps-base.nix (add github-personal/github-work entries)

   This commit is ADDITIVE only -- nothing removed, nothing broken.

3. feat(identity): switch all Nix references to personal/work names

   Modifies:
   - home-linux/gpg.nix (sops path renames + importKey labels)
   - home-darwin/gpg.nix (same)
   - modules/features/services/github-mcp-server.nix (update sops paths in wrappers)
   - home-darwin/github-mcp-server-wrapper.nix (update sops paths)
   - modules/features/services/github-token-check.nix (label renames)
   - home-linux/shell.nix (label text update)

   AND/OR the cleanup:

4. feat(identity): remove old glats/jcuzmar labels and sops aliases

   Modifies:
   - secrets/shared/passwords.yaml (sops edit: remove old keys)
   - shared/sops.nix (remove old sops declarations)
   - modules/base/sops.nix (remove pat_jcuzmar declaration)
   - modules/features/services/github-mcp-server.nix (remove old wrappers)
   - home-darwin/github-mcp-server-wrapper.nix (remove old wrappers)
   - shared/opencode/mcps-base.nix (remove old MCP entries)
```

**Verification after Stage 2**:
- `grep -rn "identities\.glats\|identities\.jcuzmar" home-linux/ home-darwin/ shared/` returns zero
- `grep -rn "pat_jcuzmar\|gpg_glats_\|gpg_jcuzmar_" modules/ home-linux/ home-darwin/ shared/` returns zero (after cleanup)
- `grep -rn "github-mcp-server-glats\|github-mcp-server-jcuzmar\|github-glats\|github-jcuzmar"` returns zero or only in cleanup-annotated comments
- `grep "User = \"glats\"" home-linux/ssh.nix` still shows matches (SSH configs unchanged)
- `grep "User = \"jcuzmar\"" home-darwin/ssh.nix` still shows matches
- `grep "username ? \"glats\"" lib/mkHost.nix` still shows match
- `nix flake check --no-build` passes

### Stage 3 (no code commit -- history rewrite)

```
# Execute the filter-repo plan (Decision 6)
# After filter-repo, the HEAD is rewritten but no new commit is created
# Force push overwrites remote history
```

**Verification after Stage 3**:
- Fresh clone from remote is PII-free
- `git log --all` contains zero `[redacted]`, `Redacted Name`, `personal@example.com`
- `nix flake check --no-build` passes on cloned repo
- `pre-history-scrub` tag exists for rollback

---

## Edge Cases and Risks

| Edge Case | Handling |
|-----------|----------|
| sops secrets unavailable during HM activation | Activation script exits 0 silently; `user.name`/`user.email` are set to placeholder; git operations fall back to environment-level config |
| Host rebuilt partially through Stage 2 (has some old, some new references) | Both old and new sops keys exist in `passwords.yaml` during transition; both old and new sops declarations exist; MCP wrappers produce all 4 binaries; activation succeeds regardless of which path is referenced |
| Old MCP wrapper (`github-mcp-server-glats`) still referenced by other tooling | Old wrapper binary still exists in PATH during transition (removed in cleanup); no runtime breakage |
| `filter-repo` modifies encrypted sops content | Encrypted ciphertext does not contain plaintext PII; the `Redacted Name`/`work@example.com` replacements will NOT match inside encrypted blobs; sops files decrypt correctly after rewrite |
| User has `github-glats` MCP configured in OpenCode but not `github-personal` | Both MCP config entries exist during transition; OpenCode shows both; user can disable old, enable new at their pace |
| `nix flake check --no-build` fails after history rewrite | Restore from `pre-history-scrub` tag; investigate which file the rewrite corrupted; adjust replacements list if needed; re-run filter-repo |
| Commit containing ONLY `work@example.com` in file content (not a name match) | filter-repo `--replace-text` handles all file content; `--mailmap` handles author/committer metadata; zero occurrences remain |

---

## Testing Strategy

### Per-stage verification commands

**Stage 1**:
```bash
grep -E "(Redacted Name|work@example\.com|personal@example\.com)" shared/git-identity.nix
# Expected: zero output

nix flake check --no-build
# Expected: exit 0

sops -d secrets/user/identities.yaml | grep -c "name:"
# Expected: 2 (personal and work)

format-nix && git diff --stat
# Expected: clean (already formatted)
```

**Stage 2**:
```bash
# Verify no old identity labels in Nix code
grep -rn "identities\.glats\|identities\.jcuzmar" home-linux/ home-darwin/ shared/
# Expected: zero output

# Verify system usernames preserved
grep -rn "users\.users\.glats\|users\.users\.personal" modules/base/ hosts/
# Expected: "users.users.glats" found, "users.users.personal" NOT found

grep "User = " home-linux/ssh.nix home-darwin/ssh.nix
# Expected: User = "glats" and User = "jcuzmar" still present

# Build check
nix flake check --no-build
```

**Stage 3**:
```bash
git log --all --oneline | xargs -I{} git show {} 2>/dev/null | grep -i "[redacted]"
# Expected: zero output

git log --all --format="%ae" | sort -u
# Expected: personal@example.com, work@example.com only

# Fresh clone test
cd /tmp && rm -rf scrub-test
git clone https://github.com/glats/.nixos.git scrub-test
cd scrub-test && nix flake check --no-build
```

---

## Open Questions

1. **Should `secrets/user/identities.yaml` have age keys for mact2+Linux or mact2 only?** -- Design recommends ALL hosts (`admin_glats` + all host keys). The identities are needed everywhere (git config on Linux, MCP on both). Specific `.sops.yaml` rule needed.

2. **Should the `github/pat` (personal) sops path be renamed to `github/pat_personal` for symmetry?** -- Design keeps `github/pat` as-is for simplicity. It was already generic and does not leak the `glats` label directly. Only `pat_jcuzmar` -> `pat_work` is renamed.

3. **Darwin `github/token` from `atlassian.yaml` -- should this be consolidated into `passwords.yaml` under `github/pat_work`?** -- Design recommends pointing the new `work` wrapper at `identities/work` first, and leaving the `atlassian.yaml` token as-is (it's a separate Atlassian ecosystem secret). Consolidation is a separate change.

4. **Should old OpenCode MCP config names (`github-glats`, `github-jcuzmar`) be auto-migrated or manually removed?** -- Manual. Users will see both old and new MCP entries in OpenCode and can disable old ones. The cleanup commit removes old entries from the shared config. Users who have overridden these in their local config must update manually.
