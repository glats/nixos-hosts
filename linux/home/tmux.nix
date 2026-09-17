# Linux tmux configuration.  Shared base lives in ../../shared/tmux.nix.
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
