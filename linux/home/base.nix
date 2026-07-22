{ username, ... }:

{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "25.05";
  home.enableNixpkgsReleaseCheck = false;

  # NIXOS_REPO: canonical path to the flake repo, used by shared shell aliases
  # (ncf, nix-switch, hms, etc.) and nixos-build scripts.
  home.sessionVariables.NIXOS_REPO = "$HOME/.nixos";

  # Prepend user-local bin to PATH so scripts dropped in ~/.local/bin
  # (e.g. openfang-start) are resolvable on every Linux host
  # (rog, thinkcentre, t14).
  home.sessionPath = [ "$HOME/.local/bin" ];

  # Explicit opt-in silencing eval warning.
  # Default flips true -> false for stateVersion >= 26.05.
  xdg.userDirs.setSessionVariables = true;
}
