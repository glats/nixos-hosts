{ username, ... }:

{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "25.05";
  home.enableNixpkgsReleaseCheck = false;

  home.sessionVariables.NIXOS_REPO = "$HOME/.nixos";

  home.sessionPath = [ "$HOME/.local/bin" ];

  xdg.userDirs.setSessionVariables = true;
}
