{
  lib,
  ...
}:

let
  mesh = import ../../shared/ssh/lan-mesh.nix { inherit lib; };
in
{
  environment.etc."resolver/lan".text = ''
    nameserver ${mesh.router.hostName}
  '';
}
