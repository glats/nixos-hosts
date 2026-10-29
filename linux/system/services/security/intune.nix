{ config, lib, ... }:

let
  portalTlsOverlay = final: prev: {
    intune-portal = prev.intune-portal.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.makeWrapper ];
      postFixup = (old.postFixup or "") + ''
        wrapProgram $out/bin/intune-portal --prefix GIO_EXTRA_MODULES : ${final.glib-networking}/lib/gio/modules
      '';
    });
  };
in
{
  services.intune.enable = config.corporate.compliance.enable;

  nixpkgs.overlays = lib.mkIf config.corporate.compliance.enable [ portalTlsOverlay ];
}
