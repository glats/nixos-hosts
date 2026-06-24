{ pkgs
, lib
, config
, primaryUser
, ...
}:

{
  imports = [
    ../shared/tmux.nix
  ];

  # Home Manager configuration for tmux kept in a separate file to keep
  # `home/default.nix` tidy.
  home = {
    # Install tmux and helpers for macOS clipboard integration
    packages = with pkgs; [ tmux ] ++ lib.optionals stdenv.isDarwin [ reattach-to-user-namespace ];

    # Keep ~/.tmux.conf as a shim that sources the actual config (for TPM scripts)
    file.".tmux.conf".text = ''
      if-shell "test -f $HOME/.config/tmux/tmux.conf" "source-file $HOME/.config/tmux/tmux.conf"
    '';

    # Ensure TPM (tmux plugin manager) is present by cloning on activation
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
  };

  programs.tmux = {
    # CRITICAL: ESC key responsiveness.
    # Without this, tmux waits 500ms after ESC to check if it's an escape
    # sequence, breaking "ESC to interrupt" in opencode and other TUI apps.
    # Value 10 is a compromise: still responsive but tolerates escape sequences.
    escapeTime = 10;

    extraConfig = ''
      # Use a 256-color capable default and ensure terminals that advertise
      # a custom name (like Ghostty's "xterm-ghostty") are treated like xterm
      # so tmux enables modern features (SGR mouse / 1006). This fixes mouse
      # events when the terminal reports a non-standard TERM name.
      set -g default-terminal "screen-256color"
      set -as terminal-overrides ',xterm-ghostty:XT'

      # macOS clipboard integration via OSC 52 (set-clipboard already set in shared/tmux.nix)
      bind -T copy-mode-vi v send -X begin-selection

      # TPM plugin declarations
      set -g @plugin 'tmux-plugins/tpm'
      set -g @plugin 'tmux-plugins/tmux-resurrect'
      set -g @plugin 'tmux-plugins/tmux-sessionist'
      set -g @plugin 'tmux-plugins/tmux-yank'
      set -g @plugin 'christoomey/vim-tmux-navigator'

      set-environment -g TMUX_PLUGIN_MANAGER_PATH "$HOME/.config/tmux/plugins"

      # Initialize TPM (runs on config source)
      run -b "$HOME/.config/tmux/plugins/tpm/tpm"
    '';
  };
}
