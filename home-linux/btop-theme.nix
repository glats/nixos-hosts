# Shared btop theme fragment.
#
# Writes `~/.config/btop/themes/nix-colors.theme` from
# `config.colorScheme.palette` base16 colors. Imported by every Linux
# host via `home-linux/shared-modules.nix`. Has no host conditionals
# — btop variants per host live in `btop-file.nix` (rog, thinkcentre)
# and `btop-settings.nix` (t14).
{
  config,
  ...
}:
let
  palette = config.colorScheme.palette;

  btopTheme = ''
    # Glats custom theme for btop

    theme[main_bg]="#${palette.base00}"
    theme[main_fg]="#${palette.base05}"
    theme[title]="#${palette.base07}"
    theme[hi_fg]="#${palette.base0D}"
    theme[selected_bg]="#${palette.base02}"
    theme[selected_fg]="#${palette.base07}"
    theme[inactive_fg]="#${palette.base03}"
    theme[graph_text]="#${palette.base04}"
    theme[proc_misc]="#${palette.base04}"
    theme[cpu_box]="#${palette.base0B}"
    theme[mem_box]="#${palette.base09}"
    theme[net_box]="#${palette.base0E}"
    theme[proc_box]="#${palette.base0C}"
    theme[div_line]="#${palette.base02}"
    theme[temp_start]="#${palette.base0B}"
    theme[temp_mid]="#${palette.base0A}"
    theme[temp_end]="#${palette.base08}"
    theme[cpu_start]="#${palette.base0B}"
    theme[cpu_mid]="#${palette.base0A}"
    theme[cpu_end]="#${palette.base08}"
    theme[free_start]="#${palette.base0B}"
    theme[free_mid]="#${palette.base0A}"
    theme[free_end]="#${palette.base08}"
    theme[cached_start]="#${palette.base0C}"
    theme[cached_mid]="#${palette.base0D}"
    theme[cached_end]="#${palette.base0E}"
    theme[available_start]="#${palette.base0B}"
    theme[available_mid]="#${palette.base0A}"
    theme[available_end]="#${palette.base08}"
    theme[used_start]="#${palette.base08}"
    theme[used_mid]="#${palette.base09}"
    theme[used_end]="#${palette.base0A}"
    theme[download_start]="#${palette.base0E}"
    theme[download_mid]="#${palette.base0D}"
    theme[download_end]="#${palette.base0C}"
    theme[upload_start]="#${palette.base0E}"
    theme[upload_mid]="#${palette.base0D}"
    theme[upload_end]="#${palette.base0C}"
    theme[process_start]="#${palette.base0B}"
    theme[process_mid]="#${palette.base0A}"
    theme[process_end]="#${palette.base08}"
  '';
in
{
  home.file."~/.config/btop/themes/nix-colors.theme".text = btopTheme;
}
