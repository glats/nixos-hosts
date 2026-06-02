{ pkgs, primaryUser, ... }:
{
  # Some users' Home Manager releases don't expose programs.gnupg/programs.pinentry.
  # To be broadly compatible, just ensure the packages are installed so you can
  # run gpg and pinentry from the shell. Configure Git below to use gpg.
  home.packages = with pkgs; [
    gnupg
    pinentry_mac
    nix-index
  ];

  # Configure git to use gpg signing by default if key is set
  programs.git = {
    enable = true;
    # We don't override userName/email here (git.nix already sets them)
    signing = {
      # keep signByDefault here; key is set in git.nix to avoid conflicts
      signByDefault = true;
    };
  };
}
