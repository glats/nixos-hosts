{ ... }:

{
  nixpkgs.overlays = [
    (final: prev: {
      xdg-desktop-portal = prev.xdg-desktop-portal.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ../../patches/xdg-desktop-portal/settings-allow-unsandboxed.patch
        ];
      });
    })

    (final: prev: {
      gnome = prev.gnome // {
        gvfs = prev.gnome.gvfs.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [
            ../../patches/gvfs/disable-ccache-for-anonymous-smb.patch
          ];
        });
      };
    })
  ];
}
