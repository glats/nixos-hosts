# Design: Host-aware GitHub CLI Account Priority

## Technical Approach

Add one shared Home Manager module that owns a host policy for the active `gh`
account, not `gh` credentials. Its activation entry runs after `writeBoundary`,
checks the mutable `~/.config/gh/hosts.yml` for the configured existing user,
then runs the packaged `gh auth switch` command. The platform-derived default is
`glats` on Linux and `jcuzmar-Falabella_FTC` on Darwin, so all four current
hosts receive the intended policy through their existing shared module lists.

## Architecture Decisions

| Decision | Choice | Alternatives considered | Rationale |
|---|---|---|---|
| Module boundary | Create `shared/gh-default-account.nix`; import it from both canonical shared-module lists. | Platform-specific duplicate modules; host-local commands. | Matches existing cross-platform shared modules and reaches rog, t14, thinkcentre, and mact2 without host-list duplication. |
| Option policy | Expose `home.github.defaultAccount` as an overridable string, defaulted from `pkgs.stdenv.hostPlatform.isDarwin`. | Four per-host assignments; hard-coded command. | Encodes the current Linux-personal/Darwin-work policy while allowing a future host override. |
| State ownership | Keep `hosts.yml`, logins, and tokens user/`gh` managed. Change only the active marker through `gh auth switch --hostname github.com --user`. | `programs.gh.hosts`; direct YAML edits. | Declarative `hosts.yml` would clobber mutable multi-login/keyring state; the native command preserves it. |
| Failure and override | Missing target login and switch errors are non-fatal; a manual switch persists until the next HM activation. | Fail activation; permanent imperative override. | First-run hosts must activate cleanly. Reasserting the declared host policy on each activation is deliberate and documented. |

## Data Flow

```
Nix option (platform default or host override)
  -> HM activation after writeBoundary
  -> filesystem-only `hosts.yml` user-key guard
  -> `gh auth switch --hostname github.com --user <account>`
  -> top-level github.com.user changes; users map/keyring tokens stay intact
```

The guard performs only `[ -f "$HOME/.config/gh/hosts.yml" ]` and a local,
exact account-key check. It MUST NOT call `gh auth status`, `gh auth token`, or
any other command that can resolve credentials/keyring data. If the key is
absent, it exits successfully without invoking `gh`. When present, the fixed,
absolute `${pkgs.gh}/bin/gh` command is called with quoted arguments and both
output and failure are non-fatal. `entryAfter [ "writeBoundary" ]` places this
after Home Manager's write/migration boundary, including `migrateGhAccounts`.

## File Changes

| File | Action | Description |
|---|---|---|
| `shared/gh-default-account.nix` | Create | Define `home.github.defaultAccount` and the guarded activation entry. |
| `linux/home/shared-modules.nix` | Modify | Import the shared module for rog, t14, and thinkcentre. |
| `darwin/home/shared-modules.nix` | Modify | Import the shared module for mact2. |
| `darwin/home/default.nix` | Unchanged | Darwin default comes from the shared option; no redundant override. |
| `shared/github-mcp-wrapper.nix` | Unchanged | Explicit `gh auth token --user` wrappers remain authoritative. |
| `shared/opencode/mcps-base.nix` | Unchanged | `github-personal` and `github-work` registrations remain unchanged. |

## Interfaces / Contracts

```nix
home.github.defaultAccount = lib.mkOption {
  type = lib.types.str;
  default = if pkgs.stdenv.hostPlatform.isDarwin
    then "jcuzmar-Falabella_FTC" else "glats";
  description = "Existing github.com gh login selected after activation.";
};
```

An override such as `{ home.github.defaultAccount = "glats"; }` replaces only
that host's activation target. This is a new option; no migration or compatibility
shim is required. It is not an authentication option and must never provision,
delete, or validate tokens.

## Testing Strategy

| Layer | What to Test | Approach |
|---|---|---|
| Evaluation | Both shared lists evaluate and emit the platform default. | `nix flake check --no-build` for rog, t14, thinkcentre, and mact2. |
| Activation | Existing target switches active account; missing `hosts.yml` or target is a successful no-op. | Run generated HM activation in disposable homes with fixture `hosts.yml`; inspect active account and unchanged `users:` entries. |
| Host verification | Linux reports `glats`; mact2 reports work account; both accounts remain listed. | On each real host run `gh auth status --active --hostname github.com` and status listing after activation. |
| Regression | MCP account selection remains explicit. | Confirm no diff in the two MCP files and invoke both wrappers against their respective logged-in users. |

## Threat Matrix

| Boundary | Applicability | Design response | Planned RED tests |
|---|---|---|---|
| Documentation-like paths | N/A — no path classification or execution. | Fixed config path only. | None. |
| Git repository selection | N/A — no repository command. | No cwd/repository input. | None. |
| Commit state | N/A — no commit operation. | No Git mutation. | None. |
| Push state | N/A — no push operation. | No remote/ref handling. | None. |
| PR commands | N/A — no PR operation. | No composed PR command. | None. |

## Migration / Rollout

No data migration is required. Deploy normally; already logged-in hosts switch on
the next activation, while unlogged-in hosts no-op. Roll back by removing the
module imports and activation entry, then activate again. Existing `hosts.yml`
accounts and keyring tokens remain untouched; choose an account manually with
`gh auth switch` afterward if desired.

## Open Questions

None.
