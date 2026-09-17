{
  pkgs,
  lib,
  config,
  primaryUser,
  ...
}:

{
  imports = [
    ../../shared/tmux.nix
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

  };

  programs.tmux = {
    # CRITICAL: ESC key responsiveness.
    # Without this, tmux waits 500ms after ESC to check if it's an escape
    # sequence, breaking "ESC to interrupt" in opencode and other TUI apps.
    # Value 10 is a compromise: still responsive but tolerates escape sequences.
    escapeTime = 10;

    extraConfig = ''
      # macOS clipboard integration via OSC 52 (set-clipboard already set in shared/tmux.nix)
      bind -T copy-mode-vi v send -X begin-selection

    '';
  };
}
