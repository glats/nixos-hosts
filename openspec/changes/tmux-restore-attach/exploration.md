## Exploration: tmux restore attach

### Current State
- **Confirmed:** OpenSpec is in hybrid mode, so this exploration is stored here and must also be persisted to Engram. No existing main spec covers tmux.
- **Confirmed:** `shared/tmux.nix` enables Continuum auto-restore and pane-content capture, but does not set `@resurrect-processes`. Resurrect therefore restores its conservative default program set (including `vim` and `nvim`), contrary to the requested policy.
- **Confirmed:** Resurrect documents `set -g @resurrect-processes 'false'` as disabling all program restoration while retaining sessions, windows, pane layouts, working directories, focus state, and optional captured content.
- **Confirmed:** Continuum restores only on server start, sleeps one second, then invokes Resurrect synchronously from its background restore script. Native `tmux attach-session` starts a server when absent but does not wait for that background work; a no-session result during this interval is therefore expected race behavior, not evidence that restore failed.
- **Confirmed:** Linux uses pinned nixpkgs plugin packages and explicitly runs Continuum a second time after `extraConfig`; mact2 clones TPM and its plugins at Home Manager activation, then TPM loads them asynchronously with `run -b`. The plugin source/version and exact load timing therefore differ by platform.
- **Hypothesis:** mact2's observed delay/error is caused by the TPM/Continuum restore race or a second tmux installation/socket, not by macOS tmux semantics. This must be measured before selecting a platform-specific repair.

### Affected Areas
- `shared/tmux.nix` — shared restore policy and Continuum settings; natural home for the no-process policy.
- `linux/home/tmux.nix` — nixpkgs plugin order and the intentional second Continuum load.
- `darwin/home/tmux.nix` — TPM bootstrap, mutable plugin clones, plugin load order, and mact2-specific restore timing.
- `shared/shell-aliases.nix` — likely declarative location for a cross-platform zsh `tmux` attach wrapper/function.
- `linux/home/shell.nix` and `darwin/home/shell.nix` — platform shell composition; confirm the shared function reaches both.
- `flake.nix` and `flake.lock` — confirm the pinned nixpkgs/Home Manager versions and avoid introducing a new dependency solely for tmux startup.

### Approaches
1. **Set only `@resurrect-processes 'false'`** — add the documented shared Resurrect option.
   - Pros: smallest declarative change; directly stops restoring saved binaries; preserves windows, layouts, directories, and captured history.
   - Cons: does not make `tmux a` wait or show restore progress; does not resolve the mact2 no-session race.
   - Effort: Low

2. **Keep Continuum auto-restore and wrap attach-or-bootstrap** — intercept interactive `tmux a` to create/attach a bootstrap session and retry until Continuum has restored.
   - Pros: can prevent a false no-session exit and display progress; GitHub prior art commonly uses `tmux new-session -A -s <name>` as an atomic create-or-attach primitive.
   - Cons: `new-session -A` creates a real extra session; Continuum can restore only after its fixed delay, so polling is heuristic and may attach to bootstrap rather than restored state. It also changes only shell-mediated invocations.
   - Effort: Medium

3. **Adjust Continuum/TPM loading only** — remove Linux's duplicate Continuum load, ensure Continuum is last after `status-right`, or alter TPM initialization.
   - Pros: improves determinism and protects autosave; Continuum upstream confirms it relies on an interpolation in `status-right` and should load last.
   - Cons: does not provide synchronous attach UX or disable process relaunch; changing timing can mask rather than fix mact2's actual cause. TPM remains mutable/network-dependent at activation.
   - Effort: Low–Medium

4. **Controlled synchronous restore wrapper (recommended)** — disable automatic Continuum restore, retain its periodic save, and make `tmux a` explicitly bootstrap a server, present a restoring message, invoke Resurrect's configured restore path in the foreground, then attach only after completion. Preserve native tmux behavior for all other commands.
   - Pros: eliminates the documented one-second background race; gives deterministic visible activity and no false no-session response; allows a single shared UX; combines cleanly with `@resurrect-processes 'false'` to restore topology/directories without binary relaunch.
   - Cons: requires careful argument handling, absent/corrupt-save fallback, cleanup, and a deliberate escape hatch for manual native restore; restoring manually must not race with Continuum's auto restore (use its documented `tmux_no_auto_restore` guard or turn auto-restore off).
   - Effort: Medium

### Recommendation
Adopt approach 4 plus the shared `@resurrect-processes 'false'` policy. It is the only option supported by the plugin documentation that meets all requested outcomes simultaneously: restore structural state, never relaunch saved workloads, show restoration, and attach after restoration rather than racing it. Keep Continuum for its 15-minute saves, but do not let it independently auto-restore when the controlled `tmux a` path owns restoration. First diagnose mact2, then make Linux and Darwin use the same wrapper contract; separately normalize plugin loading only if diagnostics prove it is needed.

Required mact2 diagnosis before proposal/apply:
1. Capture `type -a tmux`, `tmux -V`, `echo "$TMUX_TMPDIR"`, `tmux display-message -p '#{socket_path}'`, and `ps -axo pid,ppid,command | grep '[t]mux'` immediately before/during failure to detect another binary/server/socket.
2. Capture `tmux show-options -g | grep -E 'resurrect|continuum'`, `tmux show-environment -g | grep TMUX_PLUGIN`, and the generated `~/.config/tmux/tmux.conf` order to prove the loaded options and plugins.
3. Inspect metadata only (not secrets) for `~/.config/tmux/plugins/{tpm,tmux-resurrect,tmux-continuum}` revisions, `~/.tmux/resurrect/last`, `~/tmux_no_auto_restore`, and user LaunchAgents. Reproduce once with `tmux -vv` and preserve the tmux logs.

### Risks
- A wrapper that blindly uses `new-session -A` can leave or attach an unwanted bootstrap session; define behavior for no snapshot and named targets.
- Manual restore plus enabled Continuum auto-restore can execute two restores; one mechanism must own restore and the other must be disabled/guarded.
- `@resurrect-processes 'false'` intentionally stops recovery of editors and monitoring tools as well as arbitrary binaries; acceptance must explicitly approve that trade-off.
- TPM's unpinned mutable clones make mact2 less reproducible than Linux; do not attribute the problem to this until the required diagnostics identify a version/load discrepancy.

### Ready for Proposal
Yes, conditionally. The proposal can specify the shared no-process policy and a controlled synchronous `tmux a` restore contract now; it MUST record the mact2 diagnostic evidence before deciding whether to change TPM/Continuum loading or remove Linux's duplicate load.
