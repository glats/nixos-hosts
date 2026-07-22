{ config
, lib
, pkgs
, ...
}:

let
  cfg = config.my.desktop.suite;

  # Profile composition. Each profile is a function
  # `{ pkgs }: [ ... ]` that returns a flat list of packages.
  # Suite-level decisions happen here: shared profiles are always
  # imported, suite-specific profiles are appended based on
  # my.desktop.suite. Profiles themselves contain NO conditions.
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
  # Import the my.* option declarations so every host that pulls in
  # packages.nix (rog, thinkcentre, t14) sees them — t14 does not go
  # through modules/profiles/base.nix and would otherwise miss the
  # my.desktop.suite option declared in modules/base/options.nix.
  imports = [ ./options.nix ];

  environment.systemPackages = profilePkgs;
}
