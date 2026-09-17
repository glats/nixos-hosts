## Exploration: centralize-cross-platform-tmux-tpm

### Current State
`shared/tmux.nix` owns common tmux settings but not the TPM declarations. Darwin correctly declares the seven TPM repositories and starts TPM in its `programs.tmux.extraConfig`; Linux attempts the same repositories through `programs.tmux.plugins`, which Home Manager defines as packages or `{ plugin = package; extraConfig = ...; }` values, then replaces the shared `extraConfig` with `lib.mkForce`. Both platform files use `activation.install-tpm`, which is not the Home Manager `home.activation` DAG interface. The generated Linux configuration therefore cannot satisfy the plugin option type and loses shared settings. Both platform module lists import their respective tmux module; t14 also relies on Linux's forced tmux values to neutralize Omarchy's module.

Home Manager emits `programs.tmux.extraConfig` after its managed plugin block, while TPM requires `set -g @plugin` entries followed by its `run` command at the bottom of the tmux configuration. Its current module source confirms that `programs.tmux.plugins` accepts only tmux plugin packages/submodules. Home Manager documents `home.activation` as a `lib.hm.types.dagOf` whose state-changing nodes must be idempotent and run after `writeBoundary`; TPM installation should additionally run after `linkGeneration` so the generated tmux configuration exists. TPM's upstream README confirms its declaration format and that initialization belongs at the end of the configuration.

### Affected Areas
- `shared/tmux.nix` — central location for the complete ordered TPM declaration block, TPM initialization, and the cross-platform activation contract.
- `linux/home/tmux.nix` — remove invalid package-typed TPM strings and the forced replacement of shared configuration; retain Linux escape-time and any Linux-only integration.
- `darwin/home/tmux.nix` — remove duplicated TPM declarations/bootstrap; retain Darwin escape-time, the legacy `.tmux.conf` shim, and Darwin-only helper integration.
- `linux/home/shared-modules.nix` — imports the Linux tmux module for all Linux hosts, including the filtered t14 composition.
- `darwin/home/shared-modules.nix` — imports the Darwin tmux module for macm5.
- `hosts/t14/home/omarchy.nix` — its comment and tmux merge assumption must be updated if `lib.mkForce` is removed.

### Approaches
1. **Pure nixpkgs plugins** — replace TPM with `pkgs.tmuxPlugins` packages in the shared module.
   - Pros: reproducible store-pinned plugins, no activation-time Git network access, and direct Home Manager support.
   - Cons: changes the requested TPM model; plugins absent from nixpkgs require custom derivations; TPM update/install workflow disappears.
   - Effort: Medium.

2. **Centralized TPM declarations** — keep TPM and declare its ordered repositories once in `shared/tmux.nix`; use only `programs.tmux.extraConfig` for those repository strings.
   - Pros: meets the one-source requirement, preserves existing TPM behavior and plugin set, fixes the typed-option misuse, and leaves platform modules small.
   - Cons: activation remains network-dependent and TPM-managed plugin revisions are mutable outside the Nix lock file.
   - Effort: Low.

3. **Hybrid TPM bootstrap with nixpkgs plugins** — use TPM for only unavailable plugins and Home Manager packages for the rest.
   - Pros: reduces TPM's runtime surface while retaining unavailable plugins.
   - Cons: two managers can source duplicate plugins and make ordering/debugging ambiguous; it does not minimize architecture.
   - Effort: Medium.

### Recommendation
Choose **centralized TPM declarations**. Keep every `set -g @plugin` line, `TMUX_PLUGIN_MANAGER_PATH`, and the final `run -b "$HOME/.config/tmux/plugins/tpm/tpm"` together in `shared/tmux.nix`, after its common tmux settings. Do not set `programs.tmux.plugins` for TPM repository strings; leave it unset/empty so Home Manager does not type-check them as packages or generate competing `run-shell` entries.

Use one correct shared activation node for the common bootstrap, rather than duplicating it in both platform modules:

```nix
home.activation.installTpm = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
  TPM_DIR="$HOME/.config/tmux/plugins/tpm"
  export TMUX_PLUGIN_MANAGER_PATH="$HOME/.config/tmux/plugins"
  export PATH="${pkgs.tmux}/bin:${pkgs.git}/bin:$PATH"

  run mkdir -p "$TMUX_PLUGIN_MANAGER_PATH"
  if [ ! -d "$TPM_DIR/.git" ]; then
    [ ! -e "$TPM_DIR" ] || run rm -rf "$TPM_DIR"
    run ${pkgs.git}/bin/git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
  fi
  [ ! -x "$TPM_DIR/bin/install_plugins" ] || run --quiet "$TPM_DIR/bin/install_plugins"
'';
```

The interface is exactly `home.activation.<name> = lib.hm.dag.entryAfter [ "linkGeneration" ] <script>;`, not `activation.install-tpm`. `run` preserves Home Manager dry-run behavior; the directory test makes repeated activations idempotent. Linux should retain `programs.tmux.escapeTime = 0;`. Darwin should retain `escapeTime = 10`, its `.tmux.conf` compatibility shim, and only genuinely Darwin-specific helper packages. The t14 override should stop depending on `lib.mkForce` for plugin/config replacement; if an Omarchy conflict remains, constrain only that conflict explicitly.

Migration: first move the exact Darwin repository order into the shared `extraConfig`; then move the corrected activation node to shared, delete both platform copies and Linux's forced `plugins`/`extraConfig`, and update the t14 comment/override. Evaluate one Linux Home Manager configuration (including t14) and the macm5 Darwin configuration before activation. Existing TPM clones and plugin directories remain in place, so the first successful activation reuses TPM and refreshes only declared plugins.

Rollback: revert the shared declaration/activation move and restore the prior Darwin block only. Do not delete `$HOME/.config/tmux/plugins`; it is user runtime state and retaining it lets the prior working Darwin TPM configuration resume. Linux has no valid prior plugin configuration to preserve, so rollback there is configuration-only.

### Risks
- TPM clones and plugin installation require GitHub/network availability at activation time; a temporary outage can leave new plugins absent even though Nix evaluation succeeds.
- TPM repository declarations are not Nix content-addressed; upstream changes or manual `prefix + U` updates reduce reproducibility compared with nixpkgs plugins.
- TPM must remain the last runtime loader in the generated configuration; later platform `extraConfig` that runs after it can violate upstream TPM ordering.
- t14 currently documents reliance on `lib.mkForce`; removing broad force semantics may expose a real Omarchy merge conflict that requires a narrow override.

### Ready for Proposal
Yes — propose a small cross-platform Home Manager refactor for Linux hosts (rog, thinkcentre, t14) and macm5, with TPM declarations and bootstrap centralized in `shared/tmux.nix`, corrected Home Manager activation DAG syntax, and no migration to nixpkgs plugin management.
