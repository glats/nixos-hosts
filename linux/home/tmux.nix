# Linux tmux configuration.  Shared base lives in ../../shared/tmux.nix.
# Platform-specific: escapeTime=0, TPM-based plugins (no nixpkgs tmuxPlugins),
# xclip clipboard bindings via OSC 52.
#
# TPM (tmux Plugin Manager) is used to install plugins from GitHub,
# just like on Darwin.  This ensures tmux-resurrect, tmux-continuum,
# tmux-sessionist, tmux-yank, and tmux-open are available and work
# for session save/restore.
#
# TPM is cloned on first activation below; plugin declarations below
# ensure TPM installs the correct plugins from GitHub.
{
  pkgs,
  lib,
  config,
  ...
}:
{
  imports = [
    ../../shared/tmux.nix
  ];

  # Ensure TPM (tmux Plugin Manager) is present by cloning on activation
  activation.install-tpm = ''
    set -euo pipefail
    export TMUX_PLUGIN_MANAGER_PATH="$HOME/.config/tmux/plugins"
    export PATH="${pkgs.tmux}/bin:$PATH:/usr/bin:/bin"
    mkdir -p "$TMUX_PLUGIN_MANAGER_PATH"

    if [ ! -d "$TMUX_PLUGIN_MANAGER_PATH/tpm/.git" ]; then
      echo "[tmux] Cloning plugin manager into $TMUX_PLUGIN_MANAGER_PATH/tpm"
      if [ -d "$TMUX_PLUGIN_MANAGER_PATH/tpm" ]; then
        rm -rf "$TMUX_PLUGIN_MANAGER_PATH/tpm"
      fi
      "${pkgs.git}/bin/git" clone https://github.com/tmux-plugins/tpm "$TMUX_PLUGIN_MANAGER_PATH/tpm"
    fi

    if [ -x "$TMUX_PLUGIN_MANAGER_PATH/tpm/bin/install_plugins" ]; then
      echo "[tmux] Ensuring declared plugins are installed"
      "$TMUX_PLUGIN_MANAGER_PATH/tpm/bin/install_plugins" >/tmp/tmux-install-plugins.log 2>&1 || true
    fi
  '';

  # Pure Nix: no nixpkgs tmuxPlugins, use TPM from GitHub instead.
  programs.tmux = {
    escapeTime = 0;

    plugins = lib.mkForce [
      "tmux-plugins/tpm"
      "tmux-plugins/tmux-resurrect"
      "tmux-plugins/tmux-continuum"
      "tmux-plugins/tmux-sessionist"
      "tmux-plugins/tmux-yank"
      "tmux-plugins/tmux-open"
      "christoomey/vim-tmux-navigator"
    ];

    extraConfig = lib.mkForce ''
      # TPM initialization (must be after plugin declarations)
      set-environment -g TMUX_PLUGIN_MANAGER_PATH "$HOME/.config/tmux/plugins"

      # Initialize TPM (this runs on config source)
      run -b "$HOME/.config/tmux/plugins/tpm/tpm"

      # Continuum save interval
      set -g @continuum-save-interval '15'

      # Continuum auto-restore (on by default; we also explicitise here)
      set -g @continuum-restore on

      # Resurrect capture pane contents
      set -g @resurrect-capture-pane-contents 'on'

      # Universal bindings (from shared tmux.nix)
      unbind [
      bind Space copy-mode
      bind s choose-tree
      bind -T copy-mode-vi v send -X begin-selection
      bind p paste-buffer

      # Keep gx as the Vim-like copy-mode binding.
      bind -T copy-mode-vi g switch-client -T tmux-url-open
      bind -T tmux-url-open x send-keys -X copy-pipe "$HOME/.local/bin/tmux-open-url-at-cursor"
      bind -T tmux-url-open Escape switch-client -T root

      # Prefix+Space enters copy mode; o opens the URL under the cursor.
      bind -T copy-mode-vi o send-keys -X copy-pipe "$HOME/.local/bin/tmux-open-url-at-cursor"

      # vim-tmux-navigator key bindings are auto-installed by the plugin itself
    '';
  };
}
