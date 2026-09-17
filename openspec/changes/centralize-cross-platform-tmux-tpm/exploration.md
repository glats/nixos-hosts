## Exploration: centralize-cross-platform-tmux-tpm

### Current State
The already-centralized TPM runtime lives in `shared/tmux.nix`: it declares the seven plugins, sets `TMUX_PLUGIN_MANAGER_PATH`, and runs TPM last. Its activation bootstrap has an activation-only `PATH` containing Nix `tmux` and `git`, but the running tmux server receives no corresponding runtime `PATH`. The physical macm5 failure is therefore expected: TPM's [`plugin_functions.sh`](https://github.com/tmux-plugins/tpm/blob/master/scripts/helpers/plugin_functions.sh) parses plugin declarations with unqualified `awk`; its loader also creates later `run-shell` bindings for install, update, and clean actions. On macm5, that server/runtime path cannot find `awk`.

`darwin/home/tmux.nix` imports the shared module, installs tmux and a Darwin clipboard helper, supplies the `.tmux.conf` compatibility shim, and sets `escapeTime = 10`. `linux/home/tmux.nix` only imports the same shared module and sets `escapeTime = 0`. Both platform shared-module lists include their respective leaf, so changing the shared runtime block applies to rog, thinkcentre, t14, and macm5 without a leaf-specific duplication.

TPM upstream documents that tmux `run-shell` does not read shell startup files and recommends setting a global `PATH` before any `run` command for macOS/Brew failures ([TPM troubleshooting](https://github.com/tmux-plugins/tpm/blob/master/docs/tpm_not_working.md)). The tmux manual confirms that `$PATH` in a parsed config is expanded from the global environment, allowing a Nix prefix to preserve the inherited path ([tmux(1)](https://man7.org/linux/man-pages/man1/tmux.1.html)). Context7 was attempted for both tmux and Home Manager documentation before code inspection, but its monthly quota was exhausted; no Context7 API claims are used here. Exa independently returned TPM's upstream macOS PATH guidance and the macOS gawk failure report in [TPM issue #146](https://github.com/tmux-plugins/tpm/issues/146).

### Affected Areas
- `shared/tmux.nix` — the only production file required: add an idempotent, global tmux runtime `PATH` prefix immediately before the TPM loader.
- `darwin/home/tmux.nix` — inspected and intentionally unchanged; it continues to own only Darwin clipboard integration, package installation, the compatibility shim, and `escapeTime`.
- `linux/home/tmux.nix` — inspected and intentionally unchanged; it continues to own only Linux `escapeTime`.
- `openspec/changes/centralize-cross-platform-tmux-tpm/exploration.md` — this runtime addendum.

### Approaches
1. **Global tmux PATH before the TPM loader** — prepend a bounded Nix tool path (at least `gawk`, plus TPM's runtime dependencies such as Bash, core utilities, Git, and tmux) to the tmux global `PATH` immediately before `run -b`, while retaining the inherited `$PATH`.
   - Pros: fixes `awk` for loader execution and later TPM key bindings; applies consistently to Darwin and Linux; keeps `/usr/bin`, `/bin`, Homebrew, and user paths available; preserves one TPM owner and no leaf changes.
   - Cons: tmux's global environment is mutable; the implementation must guard against repeated prefixing when TPM reloads the configuration.
   - Effort: Low.

2. **Loader-specific PATH** — execute only `run -b "$HOME/.config/tmux/plugins/tpm/tpm"` with an inline PATH containing Nix and system tools.
   - Pros: smallest textual change and no global tmux environment mutation.
   - Cons: insufficiently durable: TPM registers later `run-shell` install/update/clean commands, and those separate processes will again use the tmux server environment without `awk`; it also diverges from TPM's own global-PATH guidance.
   - Effort: Low.

3. **Install `gawk` as a Home Manager package** — add `pkgs.gawk` to Darwin packages (or shared packages).
   - Pros: makes `awk` available in interactive Nix-profile shells and is easy to explain.
   - Cons: does not guarantee availability to an already-running or GUI-launched tmux server; package installation changes the profile but not tmux's captured runtime environment, so it does not address the reported failure mechanism.
   - Effort: Low.

4. **Add a module option with per-platform path injection** — expose a shared tmux runtime-path option and set Darwin/Linux values in their leaf modules.
   - Pros: permits future host-specific toolchains, including an explicitly chosen Homebrew prefix.
   - Cons: reintroduces platform ownership for a common TPM requirement, creates option and merge-surface complexity, and risks drift. Nix-provided TPM tools do not require Homebrew tmux paths because the loader and its scripts can use the injected Nix tools.
   - Effort: Medium.

### Recommendation
Choose **global tmux PATH before the TPM loader** in `shared/tmux.nix`, with an idempotence guard. The generated tmux configuration should, immediately before the existing final `run -b`, set the global `PATH` once to a Nix prefix containing TPM's runtime commands (including `gawk` as the provider of `awk`) followed by the existing `$PATH`. Retaining `$PATH` is essential: a fixed replacement such as the upstream `/opt/homebrew/bin:/bin:/usr/bin` example would clobber the user, Nix-profile, and potentially Homebrew paths captured by tmux.

The guard must test a dedicated tmux global-environment marker before prefixing, then set that marker after the prefix. That avoids Nix-store PATH duplication when TPM's install/update workflow reloads the configuration. Do not rely on the activation script's exported PATH: it affects activation only. Do not add a Darwin-only Homebrew path, a leaf option, or `gawk` to `home.packages`; the durable boundary is the tmux server environment shared by the loader and TPM's later bindings. Keep the existing final-loader ordering unchanged, because TPM requires its plugin declarations before loading and then sources plugin configuration from that loader.

This leaves TPM's mutable process model intact: its Git clone, plugin installation, and `prefix + I`/`prefix + U` operations remain network-dependent and outside the Nix lock file, but every invocation now gets the same declared Nix tool prefix. The implementation scope is exactly `shared/tmux.nix`; no production leaf, package list, activation DAG, or Homebrew configuration should change.

### Risks
- A global PATH prefix becomes part of tmux server state; the guard must be correct so repeated `source-file`/TPM reloads do not grow PATH indefinitely.
- Existing tmux servers keep their old environment until their configuration is reloaded or the server is restarted, so physical validation must include a fresh/reloaded macm5 server and a TPM action that reaches `plugin_functions.sh`.
- TPM remains mutable runtime software: GitHub availability and upstream plugin revisions can still affect install/update behavior independently of Nix evaluation.
- A static PATH replacement would break Homebrew or user-installed plugin dependencies; preserving `$PATH` is a non-negotiable compatibility condition.

### Ready for Proposal
Yes — propose a narrow runtime fix: add a guarded global tmux PATH prefix in `shared/tmux.nix` before TPM's existing loader, supplying Nix `gawk` and TPM runtime tools while preserving the inherited path. Validate on macm5 with a new/reloaded tmux server and `prefix + I` or `prefix + U`, then confirm Linux hosts retain their platform-specific `escapeTime` behavior unchanged.
