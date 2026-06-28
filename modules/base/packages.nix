{ config
, lib
, pkgs
, ...
}:

let
  cfg = config.my.desktop.suite;

  # Profile composition. Each profile is a function
  # `{ pkgs, config, lib, ... }: [ ... ]` that returns a flat list of
  # packages. `config` and `lib` are threaded through so profiles can
  # gate individual entries with `lib.mkIf (cfg != "gnome")` to skip
  # packages that omarchy-nix already provides on t14. Hosts can opt
  # out of specific profiles in their own configuration (out of scope
  # for the current change).
  basePkgs = import ./profiles/base.nix {
    inherit pkgs config lib;
  };
  devPkgs = import ./profiles/dev.nix {
    inherit pkgs config lib;
  };
  mediaPkgs = import ./profiles/media.nix {
    inherit pkgs config lib;
  };
  virtPkgs = import ./profiles/virt.nix {
    inherit pkgs;
  };
  browserPkgs = import ./profiles/browsers.nix {
    inherit pkgs config lib;
  };

  # Suite profile selection — driven by my.desktop.suite. Hosts that
  # need no suite (headless servers, future hosts) get an empty list.
  suitePkgs =
    if cfg == "mate" then
      import ./profiles/mate.nix { inherit pkgs; }
    else if cfg == "gnome" then
      import ./profiles/gnome.nix { inherit pkgs; }
    else
      [ ];
in
{
  # Import the my.* option declarations so every host that pulls in
  # packages.nix (rog, thinkcentre, t14) sees them — t14 does not go
  # through modules/profiles/base.nix and would otherwise miss the
  # my.desktop.suite option declared in modules/base/options.nix.
  imports = [ ./options.nix ];

  environment.systemPackages =
    basePkgs ++ suitePkgs ++ devPkgs ++ mediaPkgs ++ virtPkgs ++ browserPkgs;
}
