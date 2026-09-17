## Exploration: centralize-cross-platform-tmux-tpm

### Current State
The centralized TPM runtime in `shared/tmux.nix` declares seven plugins, sets `TMUX_PLUGIN_MANAGER_PATH`, injects a guarded Nix runtime `PATH` into the tmux server, and runs TPM last. Its Home Manager `installTpm` activation node runs after `linkGeneration`, validates or clones the TPM checkout, then unconditionally calls `bin/install_plugins` when present.

The newly observed physical macm5 activation failure is a separate bootstrap-boundary defect from the earlier runtime `awk` failure. Home Manager activation has no usable terminal (`TERM=unknown`), so TPM's `tmux start-server` fails with `missing or unsuitable terminal: unknown`. Even if a terminal value were forced, TPM's command-line installer first reads `TMUX_PLUGIN_MANAGER_PATH` from the *tmux server's global environment*, not the activation shell. A bare `start-server` need not load the managed config into a live server, so TPM then aborts with `FATAL: Tmux Plugin Manager not configured in tmux.conf`. The activation shell export at line 147 does not establish that tmux-server environment. TPM's own source confirms this ordering in [`plugin_functions.sh`](https://github.com/tmux-plugins/tpm/blob/master/scripts/helpers/plugin_functions.sh), while its command-line documentation requires both tmux and an already configured `.tmux.conf` ([managing plugins via command line](https://github.com/tmux-plugins/tpm/blob/master/docs/managing_plugins_via_cmd_line.md)).

`darwin/home/tmux.nix` imports the shared module, installs tmux and a Darwin clipboard helper, supplies the `.tmux.conf` compatibility shim, and sets `escapeTime = 10`. `linux/home/tmux.nix` only imports the same shared module and sets `escapeTime = 0`. Both platform shared-module lists include their respective leaf, so changing the shared runtime block applies to rog, thinkcentre, t14, and macm5 without a leaf-specific duplication.

TPM upstream documents `prefix + I` as its normal installation interaction and keeps the loader at the bottom of the configuration ([TPM README](https://github.com/tmux-plugins/tpm#installation)). Its automatic-install example is tmux-config-time, not Home Manager activation-time ([automatic TPM installation](https://github.com/tmux-plugins/tpm/blob/master/docs/automatic_tpm_installation.md)). TPM issues [#105](https://github.com/tmux-plugins/tpm/issues/105) and [#151](https://github.com/tmux-plugins/tpm/issues/151) specifically show that command-line installation depends on a configured server environment and that a detached temporary session can work only after startup timing and configuration concerns are handled. Context7 was attempted for current tmux and Home Manager documentation before code inspection, but its monthly quota was exhausted; no Context7 API claims are used here. GitHub source/issue research and Exa community research independently support the server/configuration dependency and show that `TERM=unknown` is a headless invocation error rather than an interactive tmux configuration error.

### Affected Areas
- `shared/tmux.nix` — the only production file a later apply should change: retain clone validation and cloning, but stop calling `install_plugins` from Home Manager activation.
- `darwin/home/tmux.nix` — inspected and intentionally unchanged; it continues to own only Darwin clipboard integration, package installation, the compatibility shim, and `escapeTime`.
- `linux/home/tmux.nix` — inspected and intentionally unchanged; it continues to own only Linux `escapeTime`.
- `openspec/changes/centralize-cross-platform-tmux-tpm/{proposal,design,specs/.../spec,tasks}.md` — a subsequent SDD phase must reconcile their current assumption that activation installs plugins; they are intentionally not changed in this exploration-only update.
- `openspec/changes/centralize-cross-platform-tmux-tpm/exploration.md` — this focused activation addendum.

### Approaches
1. **Clone-only activation plus interactive `prefix + I`** — keep the safe fixed-path clone/validation in activation, but defer plugin installation to TPM after a user opens or reloads tmux and presses its documented install binding.
   - Pros: activation no longer requires a terminal or a pre-existing tmux server; preserves the non-destructive clone guard and cross-platform shared ownership; uses TPM in its intended configured, interactive lifecycle; avoids activation failure from plugin/network errors after a successful Home Manager link generation.
   - Cons: plugins are not available until one deliberate first tmux interaction; plugin cloning remains mutable and network-dependent at that interaction.
   - Effort: Low.

2. **Headless temporary tmux server during activation** — set a known TERM, start a detached session, wait for config loading, run TPM installation, then clean up the server.
   - Pros: can preserve automatic plugin installation without a visible tmux client.
   - Cons: TPM scripts use the default tmux socket, so an isolated `-L` server is not straightforward; a default server can collide with or alter a user's running server; startup timing caused the documented configuration-path failure; cleanup risks terminating unrelated sessions; network/plugin failures again abort activation. This is fragile on both Darwin GUI activation and Linux headless hosts.
   - Effort: Medium.

3. **Force `TERM` in activation** — invoke TPM with `TERM=xterm-256color` or another known terminal value.
   - Pros: minimal textual change that addresses the first observed error.
   - Cons: does not create or configure a tmux server, so the second fatal error remains; it falsely asserts terminal capabilities in a non-terminal job and leaves activation coupled to TPM's mutable network/plugin work.
   - Effort: Low.

4. **Config-time automatic TPM installation** — move the automatic-install command into the generated tmux configuration before the final loader, following TPM's documented example.
   - Pros: runs only after tmux has a real server and configuration, and retains automatic first-use behavior.
   - Cons: an initial tmux launch performs network work asynchronously in the user's session; it adds loader-order and retry behavior to the live UI, and it is more behavior than the failure requires.
   - Effort: Low.

### Recommendation
Choose **clone-only activation plus interactive `prefix + I`**. A later apply should make the smallest possible edit in `shared/tmux.nix`: preserve `mkdir`, the non-Git-path refusal, and the shallow TPM clone, but remove the `install_plugins` branch. The existing guarded tmux-server `PATH` prefix stays unchanged because it remains necessary for TPM loader and binding execution once tmux is actually running.

This separates declarative activation safety from TPM's mutable plugin lifecycle. Home Manager may still fail when it cannot create or clone the fixed TPM checkout, preserving the existing safety contract; it must not fail merely because a headless job cannot emulate an interactive tmux server. No Darwin-only TERM value, temporary server, per-platform module, package addition, or automatic config-time install is warranted. The production scope remains exactly `shared/tmux.nix`; this artifact-only phase does not apply that change.

For physical macm5 recovery after a future clone-only activation, start or attach to tmux, reload the managed configuration if the server predates it, then press TPM's install binding:

```sh
if tmux has-session 2>/dev/null; then
  tmux source-file "$HOME/.config/tmux/tmux.conf"
  tmux attach
else
  tmux new -s tpm-bootstrap
fi
# Inside tmux: press Ctrl-b, then Shift-i.
```

If no tmux server exists, `tmux new -s tpm-bootstrap` followed by `Ctrl-b` then `Shift-i` is sufficient. Do not run `bin/install_plugins` from Home Manager activation; only terminate a server to force a clean reload after deliberately closing or preserving its sessions.

### Risks
- A user must complete `prefix + I` once after a fresh TPM clone; the recovery command must be visible in the applied change's documentation or activation message.
- Existing tmux servers need a managed-config reload before the binding is available; `tmux source-file` is safe, whereas killing a server can discard active sessions.
- TPM remains mutable runtime software: GitHub availability and upstream plugin revisions can still affect install/update behavior independently of Nix evaluation.
- The current proposal, design, spec, and task artifacts describe activation-time installation, so a new proposal/spec/design pass must update that contract before any apply.

### Ready for Proposal
Yes — create a narrowly revised proposal/spec/design for clone-only activation before apply. Validate on physical macm5 by activating a generation without any `TERM`/TPM installer failure, then running the recovery sequence above and confirming `prefix + I` installs the declared plugins. Confirm Linux hosts retain their platform-specific `escapeTime` behavior and that repeated activation preserves an existing valid TPM checkout.
