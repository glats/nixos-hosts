{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.desktop.suite;

  sharedProfiles = [
    ./profiles/core.nix
    ./profiles/dev.nix
    ./profiles/media.nix
    ./profiles/virt.nix
    ./profiles/browsers.nix
  ];
  suiteProfile =
    if cfg == "mate" then
      [ ./profiles/mate.nix ]
    else if cfg == "gnome" then
      [ ./profiles/gnome.nix ]
    else
      [ ];

  allProfiles = sharedProfiles ++ suiteProfile;
  profilePkgs = lib.concatMap (p: import p { inherit pkgs; }) allProfiles;
in
{
  imports = [ ./options.nix ];

  environment.systemPackages = profilePkgs;
}
