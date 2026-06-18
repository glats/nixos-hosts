{ username, ... }:

{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "25.05";
  home.enableNixpkgsReleaseCheck = false;

  # Prepend user-local bin to PATH so scripts dropped in ~/.local/bin
  # (e.g. connect-wayvnc-t14, openfang-start, gen-remmina-desktops.sh) are
  # resolvable on every Linux host (rog, thinkcentre, t14).
  home.sessionPath = [ "$HOME/.local/bin" ];

  # Explicit opt-in silencing eval warning.
  # Default flips true -> false for stateVersion >= 26.05.
  xdg.userDirs.setSessionVariables = true;
}
