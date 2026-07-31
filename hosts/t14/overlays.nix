# Host-specific package patches for t14.
# Each entry in nixpkgs.overlays patches a single package for t14 only.
{ ... }:

{
  nixpkgs.overlays = [
    # Patch xdg-desktop-portal to allow non-flatpak callers for the
    # Settings portal. xdp 1.20.x added an authorization callback that
    # resolves the caller's app ID via /proc/PID/root/.flatpak-info.
    # For non-flatpak apps (native Nautilus on Hyprland), this fails
    # and the portal denies Settings.Read with AccessDenied.
    (final: prev: {
      xdg-desktop-portal = prev.xdg-desktop-portal.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ../../patches/xdg-desktop-portal/settings-allow-unsandboxed.patch
        ];
      });
    })

    # Patch gvfs to fix anonymous SMB mounting from GNOME Files.
    # gvfs unconditionally sets smbc_setOptionUseCCache(smb_context, 1) at
    # init. With samba 4.23+, when UseCCache=TRUE and no Kerberos credential
    # cache exists, smbc_stat() returns EINVAL instead of falling back to
    # NTLMSSP. This breaks anonymous/guest SMB shares in Nautilus.
    # See: https://gitlab.gnome.org/GNOME/gvfs/-/work_items/857
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
