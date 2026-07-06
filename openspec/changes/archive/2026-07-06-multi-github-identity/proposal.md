# Proposal: multi-github-identity

## Intent

Manage two GitHub identities (glats personal + jcuzmar work) declaratively across all four hosts. Currently each host has a single default identity with no automated switching; Linux hosts work via HTTPS+GH_TOKEN with glats' PAT, macOS works via SSH with jcuzmar's keys. Work repos on Linux and personal repos on macOS require manual identity configuration.

## Scope

### In Scope
- Git conditional includes via `programs.git.includes` with inline `contents` across all hosts
- Both GitHub PATs in sops (glats existing, jcuzmar new)
- MCP: two server entries (github-glats, github-jcuzmar) with per-identity token wrappers
- GPG signing key moved from plaintext in git.nix to sops (macOS)
- Refactor darwin `home.file.".git-falabella"` to `programs.git.includes`

### Out of Scope
- SSH key management via sops (remains out-of-band)
- `gh auth` imperative login automation (GH CLI auth is inherently imperative)
- Per-repo direnv switching
- Windows/WSL hosts

### To Remove
- `home-darwin/git.nix` `home.file.".git-falabella"` anti-pattern
- `secrets/shared/git-credentials.yaml` (unused opaque blob, if confirmed unused)

## Technical Approach

Unified architecture using Home Manager's `programs.git.includes` with inline `contents`:

```
includes = [{
  condition = "gitdir:~/Work/**";
  contents = { user.name = "..."; user.email = "..."; };
}]
```

**Host defaults**: Linux hosts default to glats identity; macOS defaults to jcuzmar. Each has a complementary includeIf that overrides to the other identity for the relevant repo tree.

**GPG signing**: Move hardcoded fingerprint to sops, reference via `config.sops.secrets."github/gpg_key_fingerprint".path` in git config. Only macOS has GPG signing enabled.

**GH auth gap**: HM's `programs.gh` only manages `settings.yml`, not auth tokens. The `GH_TOKEN` env var (Linux) and SSH key (macOS) remain the auth methods. No automated `gh auth login` — user must run `gh auth login` for jcuzmar on Linux when needed.

## Host-by-Host Plan

| Host | Default Identity | includeIf Override | Auth Method | MCP Token |
|------|-----------------|-------------------|-------------|-----------|
| rog | glats | ~/Work/** → jcuzmar | HTTPS + GH_TOKEN (glats) | glats PAT |
| thinkcentre | glats | ~/Work/** → jcuzmar | HTTPS + GH_TOKEN (glats) | glats PAT |
| t14 | glats | ~/Work/** → jcuzmar | HTTPS + GH_TOKEN (glats) | glats PAT |
| mact2 | jcuzmar | ~/Personal/** → glats | SSH (work key default, personal alias) | jcuzmar token |

## Secrets Plan

| Secret | Source | Hosts | Status |
|--------|--------|-------|--------|
| `github/pat` | `passwords.yaml` | All (system) | Exists — glats' PAT |
| `github/pat_jcuzmar` | `passwords.yaml` | All | **New** — jcuzmar's PAT for Linux MCP |
| `github/token` | `atlassian.yaml` | mact2 only | Exists — jcuzmar's token, keep |
| `github/gpg_key_fingerprint` | `passwords.yaml` | All/mact2 | **New** — move from plaintext |
| `secrets/shared/git-credentials.yaml` | — | — | **Remove** (unused) |

## MCP Plan

Replace single `github` MCP entry with two named entries:

- **github-glats**: uses glats PAT; default for rog/thinkcentre/t14; reference from existing linux wrapper
- **github-jcuzmar**: uses jcuzmar PAT; default for mact2; new wrapper on all hosts

On Linux: system-level `github-mcp-server-wrapped` becomes `github-mcp-server-glats` reading `github/pat`; add `github-mcp-server-jcuzmar` reading `github/pat_jcuzmar`.

On macOS: existing wrapper reads `github/token` (jcuzmar) → becomes `github-mcp-server-jcuzmar`; add `github-mcp-server-glats` reading `github/pat`.

MCP config: `mcps-base.nix` adds both entries. Platform-specific overrides set the correct active entry per host.

## Rollback Plan

1. **Git config revert**: Remove added includeIf blocks from git.nix files → back to single identity
2. **MCP revert**: Delete new MCP entries, restore single `github` → previous MCP behavior
3. **Secrets revert**: Remove `pat_jcuzmar` and `gpg_key_fingerprint` from sops files
4. **Full revert**: `git revert` the feature commit, rebuild affected hosts

Each phase is independently revertible. Worst case: one build cycle to undo.

## Success Criteria

1. `git config user.name` shows glats identity in `~/dev/*` on Linux, jcuzmar identity in `~/Work/*`
2. `git config user.name` shows jcuzmar identity in `~/dev/*` on macOS, glats identity in `~/Personal/*`
3. MCP entry `github-glats` connects and uses glats PAT
4. MCP entry `github-jcuzmar` connects and uses jcuzmar PAT
5. `nix flake check --no-build` passes for all four hosts
6. `~/.git-falabella` no longer exists on mact2 (removed legacy anti-pattern)

## Implementation Phases

### Phase 1: Secrets + Git Config
- Add `pat_jcuzmar` and `gpg_key_fingerprint` to sops files
- Refactor `home-linux/git.nix` — add jcuzmar includeIf for ~/Work/**
- Refactor `home-darwin/git.nix` — replace home.file with programs.git.includes, add glats includeIf for ~/Personal/**, move GPG key to sops
- Declare new secrets in all sops config modules

### Phase 2: MCP Servers
- Create dual wrappers (github-mcp-server-glats, github-mcp-server-jcuzmar)
- Update `mcps-base.nix` with two entries
- Platform overrides via `mcps-extra.nix`
- Verify both MCP entries work

### Phase 3: Cleanup
- Remove `home.file.".git-falabella"` artifact
- Confirm `git-credentials.yaml` is unused and remove
- Update shell init for multi-token where needed

## Dependencies

- NixOS/nix-darwin build available for all hosts
- sops-nix working on all hosts (confirmed)
- GPG key fingerprint available from user for `gpg_key_fingerprint` secret value
- jcuzmar PAT value needed from user for `pat_jcuzmar` secret value
