# Shared superfile theme configuration -- pure Nix function, NOT a HM module.
#
# Returns a TOML string with all color keys mapped from the nix-colors palette.
# Platform-specific HM modules consume this and deploy via xdg.configFile (Linux)
# or home.file (Darwin).
#
# Usage:
#   let themeToml = import ../../shared/superfile.nix { colorScheme = config.colorScheme; };
#   in { xdg.configFile."superfile/theme/glats.toml".text = themeToml; ... }
{ colorScheme, codeSyntaxHighlight ? "dracula" }:
let
  p = colorScheme.palette;
in
''
code_syntax_highlight = "${codeSyntaxHighlight}"
file_panel_fg = "#${p.base05}"
file_panel_bg = "#${p.base00}"
file_panel_border = "#${p.base02}"
file_panel_preview_fg = "#${p.base05}"
file_panel_preview_bg = "#${p.base00}"
file_panel_preview_border = "#${p.base02}"
normal_file_fg = "#${p.base05}"
selected_file_fg = "#${p.base0D}"
select_file_bg = "#${p.base01}"
directory_fg = "#${p.base0E}"
cut_file_fg = "#${p.base08}"
zip_file_fg = "#${p.base0A}"
hidden_file_fg = "#${p.base03}"
sidebar_fg = "#${p.base05}"
sidebar_bg = "#${p.base00}"
sidebar_border = "#${p.base02}"
sidebar_title = "#${p.base0C}"
sidebar_dir_fg = "#${p.base0E}"
sidebar_dir_open_fg = "#${p.base0E}"
process_bar_fg = "#${p.base0D}"
process_bar_bg = "#${p.base01}"
modal_fg = "#${p.base05}"
modal_bg = "#${p.base00}"
modal_border = "#${p.base02}"
modal_cancel = "#${p.base08}"
modal_confirm = "#${p.base0B}"
modal_overlay_bg = "#${p.base00}"
input_fg = "#${p.base05}"
input_bg = "#${p.base00}"
input_border = "#${p.base02}"
footer_fg = "#${p.base05}"
footer_bg = "#${p.base00}"
footer_selected_fg = "#${p.base0D}"
cursor = "#${p.base06}"
error = "#${p.base08}"
highlight = "#${p.base0B}"
border_active = "#${p.base0D}"
border_inactive = "#${p.base03}"
gradient_1 = "#${p.base0D}"
gradient_2 = "#${p.base0E}"
active_file_fg = "#${p.base0B}"
''
