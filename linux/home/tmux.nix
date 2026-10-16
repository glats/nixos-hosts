{
  ...
}:
{
  imports = [
    ../../shared/tmux.nix
  ];

  programs.tmux = {
    escapeTime = 0;
  };
}
