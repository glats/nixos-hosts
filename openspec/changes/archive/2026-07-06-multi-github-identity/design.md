# SDD Design: multi-github-identity

## 1. Component Architecture

```
+-------------------------------------------------------------+
|                    Layer 1: Identity Definitions             |
|  shared/git-identity.nix (NEW)                               |
|  { glats = { name, email }; jcuzmar = { name, email } }     |
+-------------------------------------------------------------+
         |                              |
         v                              v
+------------------------+  +---------------------------+
| Layer 2a: Linux Git    |  | Layer 2b: macOS Git       |
| home-linux/git.nix     |  | home-darwin/git.nix       |
| (MODIFIED)             |  | (MODIFIED)                |
|                        |  |                           |
| Default: glats         |  | Default: jcuzmar          |
| includeIf ~/Work/** -> |  | includeIf ~/Personal/**   |
|   jcuzmar identity     |  |   -> glats identity       |
|                        |  | home.file removed         |
+------------------------+  +---------------------------+
         |                              |
         v                              v
+------------------------+  +---------------------------+
| Layer 3a: Linux Secrets |  | Layer 3b: macOS Secrets   |
| shared/sops.nix         |  | home-darwin/sops.nix      |
| (MODIFIED)              |  | (MODIFIED)                |
|                         |  |                           |
| github/pat (exists)     |  | github/pat (exists)       |
| github/pat_jcuzmar(NEW) |  | github/pat_jcuzmar(NEW)   |
|                         |  | github/token (exists)     |
|                         |  | github/gpg_key_fingerprint|
|                         |  |   (NEW, SEC-REQ-2)        |
+------------------------+  +---------------------------+
         |                              |
         v                              v
+------------------------+  +---------------------------+
| Layer 4a: Linux MCP    |  | Layer 4b: macOS MCP       |
| modules/features/...   |  | home-darwin/...           |
| github-mcp-server.nix  |  | github-mcp-server-wrapper  |
| (MODIFIED)             |  | .nix (MODIFIED)            |
|                        |  |                           |
| glats wrapper reads    |  | glats reads github/pat    |
|   github/pat           |  | jcuzmar reads github/token|
| jcuzmar reads          |  |                           |
|   github/pat_jcuzmar   |  |                           |
+------------------------+  +---------------------------+
         |                              |
         +------------+  +--------------+
                      |  |
                      v  v
+-------------------------------------------------------------+
| Layer 5: MCP Config (CROSS-PLATFORM)                        |
| shared/opencode/mcps-base.nix (MODIFIED)                    |
|   "github-glats" -> wrapper binary                          |
|   "github-jcuzmar" -> wrapper binary                        |
+-------------------------------------------------------------+

+-------------------------------------------------------------+
| Layer 6: Cleanup                                            |
| - home-darwin/git.nix: remove home.file.".git-falabella"    |
| - secrets/shared/git-credentials.yaml: delete file          |
+-------------------------------------------------------------+
```

## 2. Data Flow — Identity Resolution

### Linux (rog, thinkcentre, t14)

```
git operation in ~/dev/personal-repo/
  └── Git reads ~/.gitconfig
      ├── [user] name="Redacted Name", email="personal@example.com"   ← DEFAULT
      ├── [includeIf "gitdir:~/Work/**"] → condition NOT matched
      └── RESULT: glats identity

git operation in ~/Work/falabella-repo/
  └── Git reads ~/.gitconfig
      ├── [user] name="Redacted Name", email="personal@example.com"   ← OVERRIDDEN
      ├── [includeIf "gitdir:~/Work/**"] → condition MATCHED
      │   └── [user] name="jcuzmar", email="work@example.com"     ← WINS
      └── RESULT: jcuzmar identity
```

### macOS (mact2)

```
git operation in ~/dev/work-repo/
  └── Git reads ~/.gitconfig
      ├── [user] name="jcuzmar", email="work@example.com"         ← DEFAULT
      ├── [includeIf "gitdir:~/Work/**"] → same identity (no-op)
      ├── [includeIf "gitdir:~/Personal/**"] → condition NOT matched
      └── RESULT: jcuzmar identity

git operation in ~/Personal/glats-repo/
  └── Git reads ~/.gitconfig
      ├── [user] name="jcuzmar", email="work@example.com"         ← OVERRIDDEN
      ├── [includeIf "gitdir:~/Work/**"] → condition NOT matched
      ├── [includeIf "gitdir:~/Personal/**"] → condition MATCHED
      │   └── [user] name="Redacted Name", email="personal@example.com" ← WINS
      └── RESULT: glats identity
```

### Evaluation Order Guarantee

Git evaluates `includeIf` directives in declaration order. Home Manager writes `settings.user` (the defaults) BEFORE `includes` in the rendered `~/.gitconfig`. This means:

1. Default identity is set first
2. `includeIf` conditionals are evaluated after, overriding matched repos

**This is correct and requires no special ordering work.**

### t14 / omarchy-nix Compatibility

`lib.mkForce` on `user.name` and `user.email` in `home-linux/git.nix` is PRESERVED. `mkForce` controls HM option merging priority — it prevents omarchy-nix's `omarchy.email_address` module from overwriting the default. The `includeIf` blocks are separate HM options (`programs.git.includes`) that generate separate git include files, so `mkForce` does NOT propagate into them. Git's includeIf evaluation is independent of HM's option priority system.

## 3. Module Structure

### New Files

| File | Purpose |
|------|---------|
| `shared/git-identity.nix` | Identity definitions for both users (glats, jcuzmar) |

### Modified Files

| File | Change Type | Summary |
|------|-------------|---------|
| `home-linux/git.nix` | MODIFY | Add `programs.git.includes` for jcuzmar identity under `~/Work/**` |
| `home-darwin/git.nix` | MODIFY | Replace `home.file.".git-falabella"` with `programs.git.includes`; add glats includeIf for ~/Personal/**; move GPG key to sops ref |
| `shared/sops.nix` | MODIFY | Add `github/pat_jcuzmar` secret declaration |
| `home-darwin/sops.nix` | MODIFY | Add `github/gpg_key_fingerprint` secret declaration |
| `modules/features/services/github-mcp-server.nix` | MODIFY | Parametrize to produce two wrapper scripts (glats, jcuzmar) |
| `home-darwin/github-mcp-server-wrapper.nix` | MODIFY | Same — two wrapper scripts (glats reads github/pat, jcuzmar reads github/token) |
| `shared/opencode/mcps-base.nix` | MODIFY | Replace single `github` entry with `github-glats` and `github-jcuzmar` |
| `home-darwin/opencode/mcps-extra.nix` | MODIFY | Remove `github` override (no longer exists in base) |

### Removed Files

| File | Reason |
|------|--------|
| `secrets/shared/git-credentials.yaml` | Unused — zero Nix references |
| `home-darwin/git.nix` — `home.file.".git-falabella"` block | Replaced by `programs.git.includes` |

### No Changes Needed (verified)

| File | Reason |
|------|--------|
| `home-linux/shared-modules.nix` | No structural changes |
| `home-darwin/shared-modules.nix` | No structural changes |
| `home-linux/gh.nix` | Linux stays on HTTPS; no SSH changes |
| `home-linux/ssh.nix` | No GitHub SSH changes needed — Linux uses HTTPS |
| `home-darwin/ssh.nix` | Already has both SSH identities (github.com + github-personal) — correct as-is |
| `home-linux/shell.nix` | Exports `GH_TOKEN` from `github/pat` — stays glats' PAT. No change needed for work identity auth |
| `hosts/*/home/modules.nix` | No structural changes |
| `modules/base/home-manager.nix` | No changes |
| `home-darwin/gpg.nix` | Only sets `signByDefault = true` — correct as-is |

## 4. File-by-File Changes

### 4.1 `shared/git-identity.nix` (NEW)

```nix
{
  glats = {
    name = "Redacted Name";
    email = "personal@example.com";
  };
  jcuzmar = {
    name = "jcuzmar";
    email = "work@example.com";
  };
}
```

Single source of truth for both identities. Imported by both `home-linux/git.nix` and `home-darwin/git.nix`. Simple attribute set — no lib, no config dependency.

### 4.2 `home-linux/git.nix` (MODIFIED)

**Before**: Single identity (Redacted Name / personal@example.com), no includes.

**After**: Default stays glats (with mkForce preserved). Adds includeIf for jcuzmar work identity.

Changes:
1. Add `identities = import ../shared/git-identity.nix;` let binding
2. Reference `identities.glats.name/email` instead of hardcoded strings
3. Add `programs.git.includes` block with condition `gitdir:~/Work/**` → jcuzmar identity
4. Keep `lib.mkForce` on default user.name and user.email

### 4.3 `home-darwin/git.nix` (MODIFIED)

**Before**: Default jcuzmar identity + `home.file.".git-falabella"` for Work repos.

**After**: Default jcuzmar identity, two `programs.git.includes` entries:
- `gitdir:~/Work/**` → jcuzmar identity (same as default, preserves existing structure)
- `gitdir:~/Personal/**` → glats identity

Changes:
1. Remove entire `home.file.".git-falabella"` block (5-14)
2. Add `identities = import ../shared/git-identity.nix;` let binding
3. Reference `identities.jcuzmar.name/email` for default
4. Remove `includeIf."gitdir:~/Work/**".path = "~/.git-falabella"` from settings
5. Add `includes` block with two entries:
   - Work repos → jcuzmar identity
   - Personal repos → glats identity (no signing key)
6. Change `signing.key` from hardcoded string to `builtins.readFile config.sops.secrets."github/gpg_key_fingerprint".path`

### 4.4 `shared/sops.nix` (MODIFIED)

Add after existing `github/pat` declaration:

```nix
sops.secrets."github/pat_jcuzmar" = {
  sopsFile = ../secrets/shared/passwords.yaml;
  mode = "0400";
};
```

The secret key inside passwords.yaml is `github.pat_jcuzmar`.

### 4.5 `home-darwin/sops.nix` (MODIFIED)

Add after existing `github/token` declaration:

```nix
sops.secrets."github/gpg_key_fingerprint" = {
  sopsFile = ../secrets/shared/passwords.yaml;
  mode = "0400";
};
```

The secret key inside passwords.yaml is `github.gpg_key_fingerprint`.

### 4.6 `modules/features/services/github-mcp-server.nix` (MODIFIED)

**Before**: Single `github-mcp-server-wrapped` wrapper reading `github/pat`.

**After**: Two named wrappers using a mkWrapper helper:

```nix
let
  mkGithubMcpWrapper = { name, secretPath }: pkgs.writeShellScriptBin name ''
    #!${pkgs.runtimeShell}
    set -euo pipefail
    GITHUB_PAT_FILE="${secretPath}"
    if [ ! -f "$GITHUB_PAT_FILE" ]; then
      echo "Error: GitHub PAT secret not found at $GITHUB_PAT_FILE" >&2
      exit 1
    fi
    GITHUB_PERSONAL_ACCESS_TOKEN=$(cat "$GITHUB_PAT_FILE")
    export GITHUB_PERSONAL_ACCESS_TOKEN
    exec ${pkgs.github-mcp-server}/bin/github-mcp-server "''${@:-stdio}"
  '';

  githubMcpServerGlats = mkGithubMcpWrapper {
    name = "github-mcp-server-glats";
    secretPath = config.sops.secrets."github/pat".path;
  };

  githubMcpServerJcuzmar = mkGithubMcpWrapper {
    name = "github-mcp-server-jcuzmar";
    secretPath = config.sops.secrets."github/pat_jcuzmar".path;
  };
in {
  config = lib.mkIf config.services.github-mcp-server-custom.enable {
    environment.systemPackages = [
      githubMcpServerGlats
      githubMcpServerJcuzmar
      pkgs.github-mcp-server  # original for reference
    ];
  };
}
```

### 4.7 `home-darwin/github-mcp-server-wrapper.nix` (MODIFIED)

Same pattern but macOS-specific secret paths:

```nix
let
  mkGithubMcpWrapper = { name, secretPath }: pkgs.writeShellScriptBin name ''
    # Same script body as Linux
  '';

  githubMcpServerGlats = mkGithubMcpWrapper {
    name = "github-mcp-server-glats";
    secretPath = config.sops.secrets."github/pat".path;
  };

  githubMcpServerJcuzmar = mkGithubMcpWrapper {
    name = "github-mcp-server-jcuzmar";
    secretPath = config.sops.secrets."github/token".path;  # macOS-specific: existing atlassian.yaml token
  };
in {
  home.packages = [ githubMcpServerGlats githubMcpServerJcuzmar ];
}
```

**Key design decision**: macOS jcuzmar wrapper reads `github/token` (from `atlassian.yaml`), NOT `github/pat_jcuzmar` (from `passwords.yaml`). Reason: Backward compatibility — `github/token` is the existing, tested token for jcuzmar on macOS. The new `github/pat_jcuzmar` is for Linux MCP wrappers where `atlassian.yaml` is not available.

### 4.8 `shared/opencode/mcps-base.nix` (MODIFIED)

In the `defaultMcps` let block, replace:

```nix
github = {
  type = "local";
  command = [ "github-mcp-server" "stdio" ];
  enabled = true;
};
```

With:

```nix
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
```

### 4.9 `home-darwin/opencode/mcps-extra.nix` (MODIFIED)

Remove the `github` entry from `extraMcps`:

**Before**: `github` entry overriding base with `github-mcp-server-wrapped`.

**After**: No `github` entry in extraMcps. The base config now provides `github-glats` and `github-jcuzmar` which resolve to platform-specific wrappers via PATH resolution.

### 4.10 `secrets/shared/git-credentials.yaml` (REMOVED)

Deleted from repository. Confirmed unused (zero Nix module references).

### 4.11 `home-darwin/git.nix` — home.file block (REMOVED)

Lines 3-14 removed:
- `/home/nixos` module references: zero
- `/home/file/` no longer needed

## 5. Key Nix Expressions

### 5.1 Identity definitions (shared/git-identity.nix)

```nix
{
  glats = {
    name = "Redacted Name";
    email = "personal@example.com";
  };
  jcuzmar = {
    name = "jcuzmar";
    email = "work@example.com";
  };
}
```

### 5.2 Linux git includes (home-linux/git.nix)

```nix
{ config, lib, ... }:

let
  identities = import ../shared/git-identity.nix;
in
{
  programs.git = {
    enable = true;
    signing.format = "openpgp";
    settings = {
      core.editor = "nvim -u NONE";
      core.pager = "delta";
      delta.enable = true;
      user.name = lib.mkForce identities.glats.name;
      user.email = lib.mkForce identities.glats.email;
    };
    includes = [
      {
        condition = "gitdir:~/Work/**";
        contents = {
          user.name = identities.jcuzmar.name;
          user.email = identities.jcuzmar.email;
        };
      }
    ];
  };
}
```

### 5.3 macOS git includes + sops GPG ref (home-darwin/git.nix)

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
        name = identities.jcuzmar.name;
        email = identities.jcuzmar.email;
      };
      github.user = primaryUser;
      init.defaultBranch = "main";
      core.editor = "nvim -u NONE";
      gpg.program = "${pkgs.gnupg}/bin/gpg";
    };
    signing = {
      key = builtins.readFile config.sops.secrets."github/gpg_key_fingerprint".path;
      signByDefault = true;
    };
    includes = [
      {
        condition = "gitdir:~/Work/**";
        contents = {
          user.name = identities.jcuzmar.name;
          user.email = identities.jcuzmar.email;
        };
      }
      {
        condition = "gitdir:~/Personal/**";
        contents = {
          user.name = identities.glats.name;
          user.email = identities.glats.email;
        };
      }
    ];
  };
}
```

### 5.4 Parametrized MCP wrapper helper (both platforms)

```nix
let
  mkGithubMcpWrapper = { name, secretPath }: pkgs.writeShellScriptBin name ''
    #!${pkgs.runtimeShell}
    set -euo pipefail
    GITHUB_PAT_FILE="${secretPath}"
    if [ ! -f "$GITHUB_PAT_FILE" ]; then
      echo "Error: GitHub PAT secret not found at $GITHUB_PAT_FILE" >&2
      exit 1
    fi
    GITHUB_PERSONAL_ACCESS_TOKEN=$(cat "$GITHUB_PAT_FILE")
    export GITHUB_PERSONAL_ACCESS_TOKEN
    exec ${pkgs.github-mcp-server}/bin/github-mcp-server "''${@:-stdio}"
  '';
in
# ...
```

## 6. Secrets Layout

### secrets/shared/passwords.yaml (MODIFIED)

| Key | Value | Encrypted For | Status |
|-----|-------|---------------|--------|
| `github.pat` | glats' PAT | rog, thinkcentre, t14, mact2 | EXISTS |
| `github.pat_jcuzmar` | jcuzmar's PAT | rog, thinkcentre, t14, mact2 | NEW |
| `github.gpg_key_fingerprint` | `B658D64F6FDBCFD1EBA53509A1D4ECB0118566C8` | mact2 (and optionally Linux) | NEW |

### secrets/user/atlassian.yaml (UNCHANGED)

| Key | Value | Status |
|-----|-------|--------|
| `github.token` | jcuzmar's token | EXISTS — kept for macOS MCP |

### Sops Module Declarations

**`shared/sops.nix`** — add `github/pat_jcuzmar` (uses passwords.yaml, mode 0400)
**`home-darwin/sops.nix`** — add `github/gpg_key_fingerprint` (uses passwords.yaml, mode 0400)

### Secret-to-Wrapper Mapping

| Wrapper | Platform | Secret Read |
|---------|----------|-------------|
| `github-mcp-server-glats` | Linux | `github/pat` (passwords.yaml) |
| `github-mcp-server-glats` | macOS | `github/pat` (passwords.yaml) |
| `github-mcp-server-jcuzmar` | Linux | `github/pat_jcuzmar` (passwords.yaml) |
| `github-mcp-server-jcuzmar` | macOS | `github/token` (atlassian.yaml) |

## 7. MCP Wrapper Design

### Architecture

Each platform defines a `mkGithubMcpWrapper` function that creates a `writeShellScriptBin` derivation. The shared script body:

1. Reads the sops secret path (provided as function argument)
2. Checks the file exists (fail-fast if secret not deployed)
3. Reads the token from the file
4. Exports it as `GITHUB_PERSONAL_ACCESS_TOKEN`
5. `exec`s `github-mcp-server`

The function is parametrized by `name` (the binary name) and `secretPath` (the sops file path), producing two derivations.

### Why No Platform-Specific MCP Command Overrides

Linux and macOS MCP wrappers produce identically-named binaries (`github-mcp-server-glats`, `github-mcp-server-jcuzmar`). The MCP config in `mcps-base.nix` references these binary names. PATH resolution ensures the correct platform-specific binary is found. No platform-specific command overrides are needed.

On Linux: wrappers are installed via `environment.systemPackages` (available to all users, including HM).
On macOS: wrappers are installed via `home.packages` (user-level, available in HM's PATH).

### Simultaneous MCP Entries

Both `github-glats` and `github-jcuzmar` are enabled simultaneously in the MCP config. OpenCode (the MCP client) supports multiple MCP server entries with different names. The agent selects which server to use based on instructions or context. This avoids a toggle pattern where only one identity is active at a time.

## 8. GPG Key Reference Design

### Current State

GPG fingerprint is hardcoded in plaintext in `home-darwin/git.nix`:
```nix
signing.key = "B658D64F6FDBCFD1EBA53509A1D4ECB0118566C8";
```

### Target State

GPG fingerprint read from sops secret path:
```nix
signing.key = builtins.readFile config.sops.secrets."github/gpg_key_fingerprint".path;
```

### Idempotency

- **No activation script needed**: The GPG key is already imported in the user's keyring. Only the _reference_ (fingerprint) moves to sops — the key import itself is unchanged.
- **builtins.readFile caveat**: readFile captures trailing newlines. The sops secret value MUST NOT have a trailing newline. Recommended to store the fingerprint as a single line with no trailing newline. Alternatively, use `lib.strings.trim` on the value.
- **signByDefault**: Remains at `programs.git.signing.signByDefault = true` in the top-level config (not in includeIf blocks), so all commits on macOS are signed regardless of repo location.

### GPG Key Scope

Only macOS has GPG signing. Linux does not set `signing.key` or `signByDefault`. This is unchanged from current behavior.

## 9. Host Config Diff

### rog (Linux, NixOS)

| Aspect | Before | After |
|--------|--------|-------|
| Default identity | glats | glats (unchanged) |
| Work repos | manual config | auto ~/Work/** → jcuzmar |
| MCP binary | `github-mcp-server-wrapped` | `github-mcp-server-glats` + `github-mcp-server-jcuzmar` |
| MCP config name | `github` | `github-glats` + `github-jcuzmar` |
| Secrets | `github/pat` | +`github/pat_jcuzmar` |
| Auth method | HTTPS + GH_TOKEN | Unchanged |
| GPG | None | None |

### thinkcentre (Linux, NixOS)

Same as rog.

### t14 (Linux, NixOS — omarchy-nix)

Same as rog, with mkForce on defaults preserved. The includeIf for ~/Work/** is independent of omarchy-nix's user.email override and works correctly.

### mact2 (macOS, nix-darwin)

| Aspect | Before | After |
|--------|--------|-------|
| Default identity | jcuzmar | jcuzmar (unchanged) |
| Work repos | ~/.git-falabella via home.file | programs.git.includes inline (same content) |
| Personal repos | manual config | auto ~/Personal/** → glats |
| MCP binary | `github-mcp-server-wrapped` | `github-mcp-server-glats` + `github-mcp-server-jcuzmar` |
| MCP config name | `github` (overridden in mcps-extra.nix) | `github-glats` + `github-jcuzmar` (no override needed) |
| GPG signing key | hardcoded in git.nix | sops-referenced |
| Secrets | `github/token`, `github/pat` | +`github/pat_jcuzmar`, +`github/gpg_key_fingerprint` |
| Legacy files | ~/.git-falabella (home.file) | REMOVED |

## 10. Critical Design Decisions

### D1: macOS jcuzmar wrapper reads `github/token` (not `github/pat_jcuzmar`)

- **Decision**: On macOS, `github-mcp-server-jcuzmar` reads `github/token` from `atlassian.yaml`, not `github/pat_jcuzmar` from `passwords.yaml`.
- **Rationale**: `github/token` is the existing, tested token used by macOS tools. `github/pat_jcuzmar` is a new PAT created for Linux MCP usage. Both are jcuzmar tokens but from different sources. Using the existing token avoids breaking macOS auth without benefit.
- **Tradeoff**: Two tokens for the same user on different platforms. This is already the case before this change — the macOS `github/token` and Linux `github/pat` are different tokens.

### D2: Linux stays on HTTPS (no SSH migration)

- **Decision**: Linux hosts keep HTTPS + `GH_TOKEN` for GitHub auth. No SSH keys are added.
- **Rationale**: Zero benefit to switching. The `includeIf` git config only handles user.name/email, not SSH key selection. Linux already has a working token auth pipeline via sops + shell init. Adding SSH keys would require managing SSH private keys via sops and adding GitHub SSH host entries to `home-linux/ssh.nix`, which is scope creep.
- **Tradeoff**: `gh auth login` for jcuzmar on Linux remains manual. The user must run `gh auth login` when they need the GH CLI to authenticate as jcuzmar on a Linux host.

### D3: Both MCP entries enabled simultaneously

- **Decision**: Both `github-glats` and `github-jcuzmar` are enabled in the MCP config.
- **Rationale**: Removing the need to toggle MCP entries. The agent decides which to use. OpenCode supports multiple MCP entries with different names.
- **Tradeoff**: If the agent calls both simultaneously, it may see tools from both identities. In practice, the agent uses a single MCP at a time.

### D4: `lib.mkForce` preserved on Linux defaults

- **Decision**: `lib.mkForce` on `user.name` and `user.email` in `home-linux/git.nix` is preserved.
- **Rationale**: Prevents omarchy-nix's `omarchy.email_address` from overriding the default on t14. The `mkForce` only affects HM option merging — it does NOT propagate into `programs.git.includes` contents, so includeIf overrides work correctly.

### D5: GPG key fingerprint via sops (no activation script)

- **Decision**: The GPG key fingerprint moves to sops as a plain text secret. No activation script for GPG key import.
- **Rationale**: The GPG key is already imported in the keyring. Only the _config reference_ moves. `builtins.readFile` reads the fingerprint from the sops-deployed file.
- **Caveat**: The sops value must NOT have a trailing newline (or use `lib.strings.trim`).

### D6: `git-credentials.yaml` removal

- **Decision**: Delete `secrets/shared/git-credentials.yaml`.
- **Rationale**: Zero Nix module references. Unused opaque credential blob.
- **Risk**: Low. If a future need arises, the file can be recreated from the encrypted version (sops re-encrypt would need the original plaintext, which may not be available). If the user is uncertain, keep the file but mark it clearly as unused.

## 11. Implementation Phases (Refined)

### Phase 1: Secrets + Identity Definitions + Git Config

1. Add `github.pat_jcuzmar` and `github.gpg_key_fingerprint` to `secrets/shared/passwords.yaml` via `sops`
2. Create `shared/git-identity.nix` with both identity definitions
3. Modify `shared/sops.nix` — add `github/pat_jcuzmar` declaration
4. Modify `home-darwin/sops.nix` — add `github/gpg_key_fingerprint` declaration
5. Modify `home-linux/git.nix` — add includeIf for ~/Work/**
6. Modify `home-darwin/git.nix` — refactor home.file → includes, add glats includeIf, move GPG key to sops

**Verification**: `nix flake check --no-build` for all four hosts

### Phase 2: MCP Wrappers + Config

1. Modify `modules/features/services/github-mcp-server.nix` — parametrize to produce two wrappers
2. Modify `home-darwin/github-mcp-server-wrapper.nix` — same parametrize pattern
3. Modify `shared/opencode/mcps-base.nix` — replace single entry with two named entries
4. Modify `home-darwin/opencode/mcps-extra.nix` — remove obsolete github override

**Verification**: `nix flake check --no-build` + MCP connection test

### Phase 3: Cleanup

1. Remove `secrets/shared/git-credentials.yaml` from repo
2. Final verification: all acceptance criteria + `nix flake check --no-build`

## 12. Acceptance Criteria Mapping

| AC | Description | Phase | File(s) Affected |
|----|-------------|-------|------------------|
| AC-1 | Linux ~/dev/* → glats identity | 1 | home-linux/git.nix |
| AC-2 | Linux ~/Work/* → jcuzmar identity | 1 | home-linux/git.nix |
| AC-3 | macOS ~/dev/* → jcuzmar identity | 1 | home-darwin/git.nix |
| AC-4 | macOS ~/Personal/* → glats identity | 1 | home-darwin/git.nix |
| AC-5 | MCP github-glats connects | 2 | github-mcp-server.nix, mcps-base.nix |
| AC-6 | MCP github-jcuzmar connects | 2 | github-mcp-server.nix, mcps-base.nix |
| AC-7 | nix flake check passes all hosts | 3 | All |
| AC-8 | ~/.git-falabella removed on mact2 | 3 | home-darwin/git.nix |
| AC-9 | git-credentials.yaml removed | 3 | secrets/shared/git-credentials.yaml |
| AC-10 | GPG signing works on mact2 | 1 | home-darwin/git.nix, home-darwin/sops.nix |

## 13. Non-Functional Requirements Coverage

| NFR | Approach |
|-----|----------|
| NFR-1: Build Integrity | Verify each phase with `nix flake check --no-build` |
| NFR-2: Rollback Completeness | Each phase is independently revertible — git revert of the commit restores previous state |
| NFR-3: No Secret Exposure | All secrets only in encrypted sops files; plaintext fingerprint removed from git.nix |
| NFR-4: Cross-Platform Consistency | Linux default glats + override jcuzmar; macOS default jcuzmar + override glats (logical inverse) |

## 14. Open Questions

1. **GPG signing for glats repos on macOS**: Personal repos on macOS will be signed with jcuzmar's GPG key (the global `signing.key`). Is this acceptable, or should Personal repos have a separate GPG key? (Deferred — out of scope. The spec's AC-10 only requires signing to still work on mact2, not per-identity signing.)

2. **GH_TOKEN for jcuzmar on Linux**: Currently only `GH_TOKEN` (glats' token) is exported in shell init. For `gh` CLI to work as jcuzmar on Linux, the user must run `gh auth login` manually. Should we also export `GH_ENTERPRISE_TOKEN` or similar for jcuzmar? (Deferred — out of scope. The proposal explicitly notes this as a manual step.)

3. **git-credentials.yaml content**: The file exists but is referenced by zero Nix modules. If the user wants to preserve its content for reference, document its purpose before deletion.
