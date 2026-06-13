# T14 remmina launcher deployment.
#
# The user's 4 remote-desktop connections (mact2 / oneplus5 / rog /
# thinkcentre) and the gen-remmina-desktops.sh helper are stored in
# `./remmina/` and deployed to:
#
#   * ~/.local/share/applications/   — 4 .desktop launchers (app menu)
#   * ~/.local/share/remmina/        — 4 .remmina connection files
#   * ~/.local/bin/gen-remmina-desktops.sh  — generator script (executable)
#
# The desktop files reference the connection files via absolute paths
# (e.g. `/home/glats/.local/share/remmina/group_rdp_rog_172-16-0-5.remmina`).
# HM's home.file preserves the file basename, so the absolute path in
# the `Exec=` line resolves at runtime.
{ ... }:

{
  home.file = {
    # .desktop launchers — visible in the Hyprland app menu
    ".local/share/applications/remmina-mact2.desktop" = {
      source = ./remmina/remmina-mact2.desktop;
    };
    ".local/share/applications/remmina-oneplus5.desktop" = {
      source = ./remmina/remmina-oneplus5.desktop;
    };
    ".local/share/applications/remmina-rog.desktop" = {
      source = ./remmina/remmina-rog.desktop;
    };
    ".local/share/applications/remmina-thinkcentre.desktop" = {
      source = ./remmina/remmina-thinkcentre.desktop;
    };

    # .remmina connection files — referenced by Exec= in the launchers
    ".local/share/remmina/group_gvnc_mact2_mact2-local.remmina" = {
      source = ./remmina/group_gvnc_mact2_mact2-local.remmina;
    };
    ".local/share/remmina/group_rdp_oneplus5_172-16-0-12.remmina" = {
      source = ./remmina/group_rdp_oneplus5_172-16-0-12.remmina;
    };
    ".local/share/remmina/group_rdp_rog_172-16-0-5.remmina" = {
      source = ./remmina/group_rdp_rog_172-16-0-5.remmina;
    };
    ".local/share/remmina/group_rdp_thinkcentre_172-16-0-11.remmina" = {
      source = ./remmina/group_rdp_thinkcentre_172-16-0-11.remmina;
    };

    # Generator script — regen launchers from the .remmina files
    ".local/bin/gen-remmina-desktops.sh" = {
      source = ./remmina/gen-remmina-desktops.sh;
      executable = true;
    };
  };
}
