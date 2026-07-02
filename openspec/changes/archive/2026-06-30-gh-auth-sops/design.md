# Design: GitHub Auth via sops-nix for Linux Hosts

## Technical Approach

Wire the existing `github/pat` sops secret through Home Manager so that `gh`, `git`, and the GitHub MCP server are all authenticated on rog, thinkcentre, and t14. The approach follows the established `shared/opencode.nix` pattern: declare the secret at HM level, export it as an env var in zsh init. Git identity is set via `programs.git.settings.user.*`. The `gh` git credential helper (enabled by default in HM) handles HTTPS git auth — no `~/.git-credentials` file needed.

## Architecture Decisions

### Decision: HM-level sops declaration for `github/pat`

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Add `github/pat` to `shared/sops.nix` (HM level) | Follows opencode pattern; HM secrets go to `~/.config/sops-nix/secrets/` (separate from NixOS `/run/secrets/`); no conflict | **Chosen** |
| Hardcode `/run/secrets/github/pat` path in shell.nix | Fragile; bypasses HM sops abstraction; breaks if mount path changes | Rejected |
| Reuse NixOS sops path from HM | HM sops uses `~/.config/sops-nix/secrets/`, NOT `/run/secrets/`; different namespace | Not possible |

**Rationale**: sops-nix HM module decrypts to `${xdg.configHome}/sops-nix/secrets/` via a systemd user service. NixOS sops decrypts to `/run/secrets/` via a system service. These are independent namespaces — no conflict. The same `passwords.yaml` is decrypted by both using different age keys (user key for HM, host SSH key for NixOS).

### Decision: `programs.git.settings.user.name` over deprecated `programs.git.userName`

| Option | Tradeoff | Decision |
|--------|----------|----------|
| `programs.git.settings.user.name` | Current HM API; writes directly to gitconfig `[user]` section | **Chosen** |
| `programs.git.userName` | Deprecated; HM redirects to `settings.user.name` via `mkSettingsRenamedOptionModules` | Rejected |

**Rationale**: HM source confirms `userName` and `userEmail` are renamed options (mapped to `settings.user.name` / `settings.user.email`). Using the current path avoids deprecation warnings.

### Decision: Rely on `gitCredentialHelper` default for git HTTPS auth

| Option | Tradeoff | Decision |
|--------|----------|----------|
| `programs.gh.gitCredentialHelper.enable = true` (default) | Sets `credential.helper = gh auth git-credential` per-host; no file to manage | **Chosen** |
| Materialize `~/.git-credentials` via `home.file` | Requires managing a sops-backed file; conflicts with existing unmanaged file on rog | Rejected |

**Rationale**: HM's `gh` module defaults `gitCredentialHelper.enable` to `true`. This writes gitconfig entries like `[credential "https://github.com"]\n  helper = gh auth git-credential`. Combined with `GH_TOKEN`, this gives authenticated git HTTPS with zero file management.

## Data Flow

```
                    ┌─────────────────────────────┐
                    │ secrets/shared/passwords.yaml│
                    │ (encrypted github.pat)       │
                    └──────────┬──────────────────┘
                               │
              ┌────────────────┼────────────────────┐
              │                │                     │
    NixOS sops (system)        │      HM sops (user)
    key: host SSH ed25519      │      key: ~/.config/sops/age/keys.txt
              │                │                     │
              ▼                │           ▼
  /run/secrets/github/pat     │  ~/.config/sops-nix/secrets/github/pat
              │                │           │
              ▼                │           ▼
  MCP wrapper reads at     │  zsh init reads at
  exec time → exports      │  shell start → exports
  GITHUB_PERSONAL_ACCESS_  │  GH_TOKEN
  TOKEN                    │           │
              │                │           ├─→ gh CLI (auth status, pr, etc.)
              ▼                │           └─→ git via credential.helper
  github-mcp-server stdio   │              (gh auth git-credential)
              │                │
              ▼                │
  OpenCode MCP tools       ──┘
  (GitHub API calls)
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `hosts/rog/secrets.nix` | Modify | Remove lines 49-55 (`sops.secrets."git-credentials"` block) |
| `home-linux/git.nix` | Modify | Add `settings.user.name = "Redacted Name"` and `settings.user.email = "personal@example.com"` |
| `shared/sops.nix` | Modify | Add `sops.secrets."github/pat"` with `sopsFile = ../secrets/shared/passwords.yaml` and `mode = "0400"` |
| `home-linux/shell.nix` | Modify | Append `GH_TOKEN` export to `programs.zsh.initContent` (lib.mkAfter) |

### Exact changes

**`hosts/rog/secrets.nix`** — delete lines 49-55:
```nix
  # REMOVE THIS BLOCK:
  # Git credentials for homemanager git module
  sops.secrets."git-credentials" = {
    sopsFile = ../../secrets/shared/git-credentials.yaml;
    owner = "glats";
    group = "users";
    mode = "0600";
  };
```

**`home-linux/git.nix`** — add user identity to settings:
```nix
{ config, lib, ... }:

{
  programs.git = {
    enable = true;
    signing.format = "openpgp";
    settings = {
      core.editor = "nvim -u NONE";
      core.pager = "delta";
      delta.enable = true;
      user.name = "Redacted Name";
      user.email = "personal@example.com";
    };
  };
}
```

**`shared/sops.nix`** — add github/pat secret (HM-level declaration):
```nix
  # GitHub PAT (also declared at NixOS level for MCP wrapper)
  sops.secrets."github/pat" = {
    sopsFile = ../secrets/shared/passwords.yaml;
    mode = "0400";
  };
```

**`home-linux/shell.nix`** — append GH_TOKEN export to existing `initContent`:
```nix
    initContent = lib.mkAfter ''
      # ... existing code-work() function ...

      if [ -f "${config.sops.secrets."github/pat".path}" ]; then
        export GH_TOKEN="$(cat ${config.sops.secrets."github/pat".path})"
      fi
    '';
```

## Host Applicability

| Module | rog | thinkcentre | t14 | mact2 |
|--------|-----|-------------|-----|-------|
| `hosts/rog/secrets.nix` | ✅ (remove) | N/A | N/A | N/A |
| `home-linux/git.nix` | ✅ via shared-modules.nix | ✅ via shared-modules.nix | ✅ via omarchy.nix:66 | ❌ (home-darwin) |
| `shared/sops.nix` | ✅ via shared-modules.nix:36 | ✅ via shared-modules.nix:36 | ✅ via omarchy.nix (imports shared/sops.nix) | ❌ (home-darwin has own sops) |
| `home-linux/shell.nix` | ✅ via shared-modules.nix | ✅ via shared-modules.nix | ✅ via omarchy.nix | ❌ (home-darwin) |

## Edge Cases

1. **First activation on rog**: An unmanaged `~/.git-credentials` exists from manual setup. Since we do NOT materialize this file (we use `gitCredentialHelper` instead), HM will not touch it. No conflict. If the user wants to clean it up, they can `rm ~/.git-credentials` manually.

2. **Missing secret**: The `if [ -f ... ]` guard in shell.nix ensures zsh starts without error if sops hasn't decrypted yet. `GH_TOKEN` simply won't be set.

3. **`secrets/shared/git-credentials.yaml`**: After removing the NixOS declaration from `rog/secrets.nix`, no Nix file references this sops file. The encrypted file can remain on disk (harmless) or be deleted in a follow-up. `nix flake check` will pass because no module references it.

4. **Dual sops declaration**: `github/pat` is declared at both NixOS level (`modules/base/sops.nix`, for the MCP wrapper) and HM level (`shared/sops.nix`, for the shell export). These are independent — NixOS decrypts to `/run/secrets/github/pat`, HM decrypts to `~/.config/sops-nix/secrets/github/pat`. No conflict.

## Verification Strategy

| Spec Requirement | Verification Command |
|-----------------|---------------------|
| Git identity set | `git config user.name` → `Redacted Name` |
| Git identity set | `git config user.email` → `personal@example.com` |
| GH_TOKEN exported | `echo $GH_TOKEN` → non-empty `gho_*` string |
| GH_TOKEN graceful missing | Remove sops file → zsh starts without error |
| gh authenticated | `gh auth status` → exit 0 |
| Git HTTPS authenticated | `git clone https://github.com/glats/.nixos.git /tmp/test-clone` → success |
| No git-credentials file | `test ! -f ~/.git-credentials` → true (on fresh hosts) |
| MCP no regression | OpenCode GitHub tools → no auth errors |
| Cleanup | `nix flake check --no-build` → pass |
| No dangling refs | `rg 'git-credentials' --include='*.nix'` → no matches |

## Migration / Rollout

No migration required. The change is additive (git identity, GH_TOKEN export, HM sops declaration) plus one removal (unused `git-credentials` secret from rog). Rollout: `nixos-build switch` on each host.

## Open Questions

None.
