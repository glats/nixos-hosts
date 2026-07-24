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
      set -s set-clipboard on
      set -g @override_copy_command "printf '\033]52;c;%s\033\\' \"$(base64 | tr -d '\012')\" >/dev/tty"

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

      # 256-color capable default terminal and RGB terminal-overrides.
      # Without this, tmux falls back to 8-color "screen" and approximates
      # hex colors to the nearest ANSI palette entry — causing wrong colors
      # when SSHing from terminals like Ghostty (xterm-ghostty) or Kitty.
      set -g default-terminal "screen-256color"
      set -as terminal-overrides ",*:Tc"

      # base16 theme (community standard: base00 bg with blue accents)
      set -g status-style fg=#${config.colorScheme.palette.base05},bg=#${config.colorScheme.palette.base00}
      setw -g window-status-style fg=#${config.colorScheme.palette.base05},bg=#${config.colorScheme.palette.base00}
      setw -g window-status-current-style fg=#${config.colorScheme.palette.base0D},bg=#${config.colorScheme.palette.base00}
      set -g pane-border-style fg=#${config.colorScheme.palette.base02}
      set -g pane-active-border-style fg=#${config.colorScheme.palette.base0D}
      set -g message-style fg=#${config.colorScheme.palette.base0D},bg=default
      set -g mode-style fg=#${config.colorScheme.palette.base00},bg=#${config.colorScheme.palette.base0D}
      setw -g clock-mode-colour '#${config.colorScheme.palette.base0D}'

      # Status bar layout and content
      set -g status-interval 5
      set -g status-left-length 30
      set -g status-right-length 50
      set -g window-status-separator ""

      # Automatic window rename: folder when idle, command name when running
      setw -g automatic-rename on
      setw -g automatic-rename-format '#{?#{==:#{pane_current_command},zsh},#{b:pane_current_path},#{pane_current_command}}'

      # Left: colored session name block
      set -g status-left "#[fg=#${config.colorScheme.palette.base00},bg=#${config.colorScheme.palette.base0D},bold] #S #[bg=default] "

      # Right: mode indicators (COPY, PREFIX, ZOOM) + hostname + datetime
      set -g status-right "#[fg=#${config.colorScheme.palette.base0D}]#{?pane_in_mode,COPY ,}#{?client_prefix,PREFIX ,}#{?window_zoomed_flag,ZOOM ,}#[fg=#${config.colorScheme.palette.base03}]#h #[fg=#${config.colorScheme.palette.base03}]#(date '+%d %b %H:%M') "

      # Window status format
      setw -g window-status-format "#[fg=#${config.colorScheme.palette.base03}] #I:#W "
      setw -g window-status-current-format "#[fg=#${config.colorScheme.palette.base0D},bold] #I:#W "

      # Message command style
      set -g message-command-style "bg=#${config.colorScheme.palette.base02},fg=#${config.colorScheme.palette.base0D}"

      set -g @resurrect-capture-pane-contents 'on'

      # tmux-continuum: continuous saving + auto-restore
      set -g @continuum-save-interval '15'
      set -g @continuum-restore on

      # Universal bindings
      unbind [
      bind Space copy-mode
      bind s choose-tree
      bind -T copy-mode-vi v send -X begin-selection
      bind p paste-buffer

      # vim-tmux-navigator key bindings (C-h/C-j/C-k/C-l) are
      # auto-installed by the plugin itself when sourced by Home
      # Manager (nixpkgs plugins) or TPM.  We do NOT duplicate them
      # here to avoid double-bind warnings.
    '';
  };
}
