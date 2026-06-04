{ pkgs
, lib
, config
, primaryUser
, ...
}:
{
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
    enable = true;

    # 🔥 CRITICAL: ESC key responsiveness
    # Without this, tmux waits 500ms after ESC to check if it's an escape
    # sequence, breaking "ESC to interrupt" in opencode and other TUI apps.
    # Value 0 means send ESC immediately (required for responsive interrupt).
    escapeTime = 10;

    extraConfig = ''
      # Common tmux settings
      # Use a 256-color capable default and ensure terminals that advertise
      # a custom name (like Ghostty's "xterm-ghostty") are treated like xterm
      # so tmux enables modern features (SGR mouse / 1006). This fixes mouse
      # events when the terminal reports a non-standard TERM name.
      set -g default-terminal "screen-256color"
      set -as terminal-overrides ',xterm-ghostty:XT'
      set -g escape-time 10
      set -gq base-index 1
      set -g renumber-windows on
      set -gq focus-events on
      set -gq history-limit 10000
      set -gq set-titles on
      setw -gq mode-keys vi
      setw -gq xterm-keys on
      set -g mouse on
      set -g @resurrect-capture-pane-contents 'on'

      # ── base16 theme ──
      # status bar
      set -g status-style fg=#${config.colorScheme.palette.base05},bg=#${config.colorScheme.palette.base01}

      # window titles
      setw -g window-status-style fg=#${config.colorScheme.palette.base05},bg=#${config.colorScheme.palette.base01}
      setw -g window-status-current-style fg=#${config.colorScheme.palette.base0D},bg=#${config.colorScheme.palette.base01}

      # pane borders
      set -g pane-border-style fg=#${config.colorScheme.palette.base01}
      set -g pane-active-border-style fg=#${config.colorScheme.palette.base04}

      # message text
      set -g message-style fg=#${config.colorScheme.palette.base05},bg=#${config.colorScheme.palette.base02}

      # pane number display / copy mode
      set -g mode-style fg=#${config.colorScheme.palette.base04},bg=#${config.colorScheme.palette.base02}

      # clock
      setw -g clock-mode-colour '#${config.colorScheme.palette.base0D}'

      set -g allow-passthrough on

      set -g exit-empty off
      set -g exit-unattached off

      # TPM and plugins
      set -g @plugin 'tmux-plugins/tpm'
      set -g @plugin 'tmux-plugins/tmux-resurrect'
      set -g @plugin 'tmux-plugins/tmux-sessionist'
      set -g @plugin 'tmux-plugins/tmux-yank'

      # Initialize TPM and OS-specific settings
      if-shell '[ "$(uname)" = "Darwin" ]' \
        "set -s set-clipboard on; \
         bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel \"pbcopy\"; \
         bind -T copy-mode y send-keys -X copy-pipe-and-cancel \"pbcopy\"; \
         run -b \"$HOME/.tmux/plugins/tpm/tpm\"" \
        "run-shell '/usr/share/tmux-plugin-manager/tpm'"

      set-environment -g TMUX_PLUGIN_MANAGER_PATH "$HOME/.config/tmux/plugins"
      set -gq set-titles on
      setw -gq aggressive-resize on
      # Enable mouse interactions (click panes/tabs) and macOS clipboard sync

      set -g mouse on
      set -s set-clipboard on
      bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "pbcopy"
      bind -T copy-mode y send-keys -X copy-pipe-and-cancel "pbcopy"

      # tmux plugin manager (TPM) + plugins
      set -g @plugin 'tmux-plugins/tpm'
      set -g @plugin 'tmux-plugins/tmux-resurrect'
      set -g @plugin 'tmux-plugins/tmux-sessionist'
      set -g @plugin 'tmux-plugins/tmux-yank'
      set -g @resurrect-capture-pane-contents 'on'
      run -b "$HOME/.config/tmux/plugins/tpm/tpm"
    '';
  };
}
