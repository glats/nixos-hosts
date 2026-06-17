# Shared tmux configuration for Linux and Darwin.
#
# Provides common settings (allow-passthrough, base-index, focus-events,
# history-limit, base16 theme, resurrect, etc.). Platform files import this
# module and add platform-specific configuration:
#   - Linux: escapeTime=0, nixpkgs plugins, xclip clipboard bindings
#   - Darwin: escapeTime=10, TPM-based plugins, pbcopy clipboard bindings
{ config, ... }:
{
  programs.tmux = {
    enable = true;

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
      set -g status-position bottom

      # base16 theme
      set -g status-style fg=#${config.colorScheme.palette.base05},bg=#${config.colorScheme.palette.base01}
      setw -g window-status-style fg=#${config.colorScheme.palette.base05},bg=#${config.colorScheme.palette.base01}
      setw -g window-status-current-style fg=#${config.colorScheme.palette.base0D},bg=#${config.colorScheme.palette.base01}
      set -g pane-border-style fg=#${config.colorScheme.palette.base02}
      set -g pane-active-border-style fg=#${config.colorScheme.palette.base04}
      set -g message-style fg=#${config.colorScheme.palette.base05},bg=#${config.colorScheme.palette.base02}
      set -g mode-style fg=#${config.colorScheme.palette.base07},bg=#${config.colorScheme.palette.base02}
      setw -g clock-mode-colour '#${config.colorScheme.palette.base0D}'

      set -g @resurrect-capture-pane-contents 'on'
    '';
  };
}
