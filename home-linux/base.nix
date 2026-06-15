{ username, ... }:

{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "25.05";
  home.enableNixpkgsReleaseCheck = false;

  # Explicit opt-in silencing eval warning.
  # Default flips true -> false for stateVersion >= 26.05.
  xdg.userDirs.setSessionVariables = true;
}
