# Design: Reliable tmux Session Recovery (`tmux-resume`)

## Technical Approach

Add `tmux-resume` as a zsh shell function in `shared/shell-aliases.nix` (`programs.zsh.initContent`), the same file that already hosts `nix-switch`, `gpo`, `glog`. It never calls Resurrect directly; it only polls `tmux has-session`/`tmux attach` in a short bounded loop so Continuum's existing one-shot, async `@continuum-restore on` (fires once per fresh server, ~1s init delay per `tmux-continuum/scripts/continuum_restore.sh`) has time to land before the user sees a verdict. `tmux a` is untouched.

## Architecture Decisions

| Decision | Choice | Alternatives | Rationale |
|---|---|---|---|
| Implementation location | zsh function in `shared/shell-aliases.nix` | `pkgs/` derivation | No compiled logic, no non-Nix deps beyond `tmux`; matches existing shell-function pattern in this exact file; a `pkgs/` package adds build/packaging overhead (`callPackage`, `lib/packages.nix` entry) for ~20 lines of shell with zero reuse outside the shell |
| Exposure | Plain shell function (not `shellAliases`) | tmux binding, standalone script | Needs control flow (loop, exit codes) `shellAliases` can't express; already the pattern used for `gpo`, `glog` |
| Session detection | `tmux has-session` exit code, polled | Parse `tmux list-sessions` output | `has-session` is the documented low-noise boolean check; avoids parsing session list text |
| Retry cadence | `sleep 0.2` per attempt, hard cap ~3s total (15 attempts) | Exponential backoff, indefinite wait | Continuum's own delay is ~1s; 3s gives 2x headroom without user-perceived hang; fixed short interval is simplest to reason about and test deterministically |
| Snapshot-absent detection | After timeout, check for a Resurrect `last` snapshot file at the known default paths (`$XDG_DATA_HOME/tmux/resurrect/last`, `~/.local/share/tmux/resurrect/last`, `~/.tmux/resurrect/last`) | Parse Resurrect logs, query `@resurrect-dir` via `tmux show-option` | `@resurrect-dir` is unset in `shared/tmux.nix`, so upstream default paths are stable and enumerable without invoking a plugin script; used only to pick the *message*, never to trigger a restore |
| Restore trigger | None — never call `resurrect/scripts/restore.sh` | Explicitly restore before/after attach | Continuum is the sole restore authority per proposal; a second invocation risks duplicate panes/processes (confirmed failure mode in tmux-continuum issue history) |
| Bootstrap avoidance | Never call `tmux new-session -A` / `-d` | Bootstrap then let Resurrect replace it | Confirmed upstream bug class (tmux-continuum #50): a bootstrap session before restore reliably produces an extra numbered session (`0`) surviving the restore in some install orders |
| Error surfacing | Check `tmux -V`/binary presence and inspect first `has-session` stderr for non-"no server"/"no sessions" text before entering the retry loop | Only report at timeout | A genuine tmux error (missing binary, broken socket) should fail fast, not be masked as a 3s "restore" wait |

## Data Flow

    tmux-resume (zsh fn)
       │
       ├─ tmux binary present? ──no──> print error, exit 127
       │
       ├─ loop (<=15x, 0.2s): tmux has-session -t? ──yes──> tmux attach ──> done
       │        │
       │        └─ stderr matches unrelated tmux error? ──yes──> print raw error, exit non-zero (no more retries)
       │
       └─ loop exhausted ─┬─ Resurrect "last" file found at any default path? ──yes──> "restore still in progress / timed out" message, exit 1
                           └─ not found ──> "no snapshot to restore" message, exit 1

Continuum's own background restore (already configured, unmodified) races independently in the background; `tmux-resume` only observes its result via `has-session`.

## File Changes

| File | Action | Description |
|---|---|---|
| `shared/shell-aliases.nix` | Modify | Add `tmux-resume()` function next to existing helpers in `programs.zsh.initContent`; no change to `shellAliases` map |
| `shared/tmux.nix` | No change | `@continuum-restore on` and process policy stay exactly as-is |
| `linux/home/tmux.nix`, `darwin/home/tmux.nix` | No change | Both already import `shared/tmux.nix`; both compose `shared/shell-aliases.nix` via existing `home/shell.nix` chains — verified during Step 2 reading, no new import needed |
| `pkgs/` | Not used | Rejected per Architecture Decisions |

## Interfaces / Contracts

```sh
tmux-resume() {
  command -v tmux >/dev/null 2>&1 || { echo "tmux-resume: tmux not found" >&2; return 127 }
  local tries=15 delay=0.2 i err
  for ((i=0; i<tries; i++)); do
    if tmux has-session 2>/tmp/tmux-resume.err; then
      exec tmux attach
    fi
    err=$(cat /tmp/tmux-resume.err)
    # a real tmux error (not "no server running on <socket>") short-circuits
    if [[ -n "$err" && "$err" != *"no server"* && "$err" != *"no session"* ]]; then
      echo "$err" >&2; return 1
    fi
    sleep "$delay"
  done
  for f in "${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect/last" "$HOME/.tmux/resurrect/last"; do
    [[ -e "$f" ]] && { echo "tmux-resume: restore did not finish within timeout" >&2; return 1; }
  done
  echo "tmux-resume: no snapshot to restore" >&2; return 1
}
```
(Illustrative — exact quoting/tempfile handling finalized during implementation; behavior contract above is binding.)

## Testing Strategy

| Layer | What to Test | Approach |
|---|---|---|
| Unit (shell) | Retry loop bounds, error-message branching | `bats`/manual script harness stubbing a fake `tmux` shim that simulates "no server" then "session appears after N calls" |
| Integration | Real tmux + Resurrect snapshot fixtures on Linux (nixpkgs plugins) and mact2 (TPM) | Manual cold-start reproduction per host: kill tmux server, remove socket, run `tmux-resume`, assert exactly the snapshot's sessions exist, no bootstrap session, no duplicate restore |
| Regression | `tmux a` unaffected | Confirm `tmux a` still native (no wrapper) after `shared/shell-aliases.nix` change |

## Threat Matrix

N/A — no routing, VCS/PR automation, or executable-file classification boundary. `tmux-resume` is a bounded local shell wrapper around already-configured `tmux attach`; it spawns no new subprocess types beyond `tmux` itself and stat/test on known fixed local paths. Process-integration risk (accidental double restore, bootstrap session) is addressed directly in Architecture Decisions above.

## Migration / Rollout

No migration required. Additive shell function; removing it (rollback) restores prior behavior with zero state to reconcile, per proposal's rollback plan.

## Open Questions

- [ ] Exact default Resurrect `last`-file path set should be verified against the installed nixpkgs `tmuxPlugins.resurrect` version during implementation (paths above are upstream defaults, unconfirmed against the pinned nixpkgs revision).
</content>
