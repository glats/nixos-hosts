# Design: Unify GitHub Auth

## Technical Approach

Promote the Darwin `github-mcp-server-wrapper.nix` module verbatim to `shared/github-mcp-wrapper.nix`, import it from both platform shared-module lists, and surgically remove every Linux PAT artifact. No new options surface — users and accounts are hardcoded per single-user repo convention.

## Architecture Decisions

| Decision | Choice | Alternatives Rejected | Rationale |
|---|---|---|---|
| Module options | No options — hardcode `glats` / `jcuzmar-Falabella_FTC` | NixOS module options for user/account | Single-user repo; ponytail-minimal; options would add boilerplate with zero value |
| Promotion strategy | Copy-as-is from Darwin | Rewrite for cross-platform | Darwin wrapper already proven; behavioral diff = zero |
| PAT removal scope | Delete files + import lines + shell export + sops declarations | Comment-out / feature-flag | Dead config is harmful; encrypted ciphertext survives in `passwords.yaml` if rollback needed |

## Data Flow

```
HM activation
  └── shared/github-mcp-wrapper.nix
        └── home.packages = [
              github-mcp-server-personal  (mkGithubMcpWrapper { name="personal"; user="glats"; })
              github-mcp-server-work       (mkGithubMcpWrapper { name="work";     user="jcuzmar-Falabella_FTC"; })
            ]

Each wrapper at runtime:
  TOKEN=$(gh auth token --hostname github.com --user <user>)
  if empty → stderr "run: gh auth login --hostname github.com" && exit 1
  exec ${pkgs.github-mcp-server}/bin/github-mcp-server stdio  (env GITHUB_PERSONAL_ACCESS_TOKEN=$TOKEN)
```

**Note**: `pkgs.github-mcp-server` is referenced by Nix store path inside the wrapper script, not from system PATH. Removing `linux/system/services/github-mcp-server.nix` therefore does **not** break MCP function — the binary is still closure-reachable via the HM package.

## Module Interface

`shared/github-mcp-wrapper.nix` exposes **no options**. Signature:

```nix
{ pkgs, ... }:
```

Accounts are hardcoded. This is intentional (see decision table above). Any future multi-user need would warrant a new change with explicit options — not an open-ended escape hatch now.

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `shared/github-mcp-wrapper.nix` | **Create** | Promoted Darwin wrapper (behavior-identical) |
| `darwin/home/shared-modules.nix` | **Modify** | Replace `./github-mcp-server-wrapper.nix` → `../../shared/github-mcp-wrapper.nix` |
| `linux/home/shared-modules.nix` | **Modify** | Add `../../shared/github-mcp-wrapper.nix` |
| `darwin/home/github-mcp-server-wrapper.nix` | **Delete** | Superseded by shared module |
| `linux/system/services/github-mcp-server.nix` | **Delete** | PAT-based Linux service |
| `linux/system/services/github-token-check.nix` | **Delete** | PAT pre-check activation script |
| `linux/home/shell.nix` ~line 98 | **Modify** | Remove `GH_TOKEN` sops-path export block |
| `linux/system/base/sops.nix` lines 16-24 | **Modify** | Remove `github/personal_pat` + `github/work_pat` declarations only |
| `hosts/rog/default.nix` ~lines 55-56 | **Modify** | Remove github-mcp-server + github-token-check imports |
| `hosts/thinkcentre/default.nix` ~lines 49-50 | **Modify** | Same |
| `hosts/t14/default.nix` ~lines 64-65 | **Modify** | Same |

**Preserved untouched**: `shared/gpg.nix`, `secrets/shared/passwords.yaml` (encrypted — never edit directly), all `github/{personal,work}_gpg_key` + fingerprint sops declarations.

## Migration / Breaking Changes

| What breaks | Who is affected | Migration path |
|---|---|---|
| `/run/secrets/github/personal_pat` no longer deployed | Any script cat-ing that path | Use `gh auth token --hostname github.com --user glats` instead |
| `GH_TOKEN` not set in shell | Shell scripts relying on it | `gh` resolves its own auth; `gh` commands keep working unchanged |
| `github-mcp-server` not in system PATH | Direct invocations by name (unlikely) | Use wrapper `github-mcp-server-personal` or `-work` |

**Rollback**: `git revert <commit>` restores all deleted files and import lines. Encrypted PAT ciphertext remains in `passwords.yaml` for recovery — no data is destroyed.

## Deployment Sequencing

| Host | Action | Prerequisite |
|---|---|---|
| `rog` | `nixos-build` → switch now | `gh auth login` ×2 (personal + work) if not done |
| `t14` | pull + `nixos-build` at next session | Same gh login prerequisite |
| `thinkcentre` | config lands in flake; **switch deferred** (slow post-upgrade rebuild) | Same gh login prerequisite before switching |
| `mact2` | gains moved file path at next `darwin-rebuild`; behavior unchanged | Already on gh; no action needed |

**Per-host one-time prerequisite** (Linux hosts only):
```bash
gh auth login --hostname github.com   # repeat for each account (device flow works over SSH)
# Verify:
github-mcp-server-personal stdio < /dev/null
github-mcp-server-work     stdio < /dev/null
# Both should print MCP server startup JSON, not auth errors
```

## Testing Strategy

| Layer | What | How |
|---|---|---|
| Eval | All 4 hosts evaluate | `nix flake check --no-build` |
| Eval | Linux + Darwin HM eval | `nix build .#homeConfigurations.glats@rog.activationPackage` + mact2 equivalent |
| Functional | Wrapper token resolution | Run verification commands above on each switched host |
| Negative | Missing account fails fast | On a test user without gh login, wrapper must exit non-zero with `gh auth login` in stderr |

## Threat Matrix

N/A — no routing, VCS/PR automation, or process-integration boundary. Wrappers exec a fixed binary; the only variable is the token value sourced from `gh`. No untrusted input reaches the subprocess invocation.

## Open Questions

None — design is complete.
