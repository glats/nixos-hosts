{ pkgs, ... }:

{
  imports = [
    ../shared/tmux.nix
  ];

  # Pure Nix: no TPM, no git clones, everything from nixpkgs.
  programs.tmux = {
    escapeTime = 0;

    plugins = with pkgs.tmuxPlugins; [
      resurrect
      sessionist
      yank
    ];

    extraConfig = ''
      bind -T copy-mode-vi v send -X begin-selection
      bind P paste-buffer

      bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "xclip -i -selection clipboard"
      bind -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel "xclip -i -selection clipboard"
      bind -T copy-mode y send-keys -X copy-pipe-and-cancel "xclip -i -selection clipboard"
      bind -T copy-mode Enter send-keys -X copy-pipe-and-cancel "xclip -i -selection clipboard"
      bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "xclip -i -selection clipboard"
    '';
  };
}
