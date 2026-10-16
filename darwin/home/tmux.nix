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

  home = {
    packages = with pkgs; [ tmux ] ++ lib.optionals stdenv.isDarwin [ reattach-to-user-namespace ];

    file.".tmux.conf".text = ''
      if-shell "test -f $HOME/.config/tmux/tmux.conf" "source-file $HOME/.config/tmux/tmux.conf"
    '';

  };

  programs.tmux = {
    escapeTime = 10;

    extraConfig = ''
      # macOS clipboard integration via OSC 52 (set-clipboard already set in shared/tmux.nix)
      bind -T copy-mode-vi v send -X begin-selection

    '';
  };
}
