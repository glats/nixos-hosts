{ config, pkgs, ... }:

{
  home = {
    activation.install-tpm = ''
      if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
        echo "> Cloning tmux plugin manager (tpm) to $HOME/.tmux/plugins/tpm"
        "${pkgs.git}/bin/git" clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
      fi
    '';
  };

  programs.tmux = {
    enable = true;

    escapeTime = 0;

    plugins = with pkgs.tmuxPlugins; [
      resurrect
      sessionist
      yank
    ];

    extraConfig = ''
      set -g allow-passthrough on

      set -g exit-empty off
      set -g exit-unattached off

      set -gq base-index 1
      set -g renumber-windows on
      set -gq focus-events on
      set -gq history-limit 10000
      set -gq set-titles on
      setw -gq aggressive-resize on
      setw -gq mode-keys vi
      setw -gq xterm-keys on

      set -g mouse on

      bind -T copy-mode-vi v send -X begin-selection
      bind P paste-buffer

      bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "xclip -i -selection clipboard"
      bind -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel "xclip -i -selection clipboard"
      bind -T copy-mode y send-keys -X copy-pipe-and-cancel "xclip -i -selection clipboard"
      bind -T copy-mode Enter send-keys -X copy-pipe-and-cancel "xclip -i -selection clipboard"
      bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "xclip -i -selection clipboard"

      # ── base16 pattern ──
      # status bar
      set -g status-style fg=#${config.colorScheme.palette.base05},bg=#${config.colorScheme.palette.base01}

      # window titles
      setw -g window-status-style fg=#${config.colorScheme.palette.base05},bg=#${config.colorScheme.palette.base01}
      setw -g window-status-current-style fg=#${config.colorScheme.palette.base0D},bg=#${config.colorScheme.palette.base01}

      # pane border
      set -g pane-border-style fg=#${config.colorScheme.palette.base01}
      set -g pane-active-border-style fg=#${config.colorScheme.palette.base04}

      # message text
      set -g message-style fg=#${config.colorScheme.palette.base05},bg=#${config.colorScheme.palette.base02}

      # pane number display / copy mode
      set -g mode-style fg=#${config.colorScheme.palette.base04},bg=#${config.colorScheme.palette.base02}

      # ── clock ──
      setw -g clock-mode-colour '#${config.colorScheme.palette.base0D}'

      set -g @resurrect-capture-pane-contents 'on'

      run "$HOME/.tmux/plugins/tpm/tpm"
    '';
  };
}
