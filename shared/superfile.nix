# Shared superfile theme configuration -- pure Nix function, NOT a HM module.
#
# Returns a TOML string with the superfile v1.3.3+ theme schema mapped from the
# nix-colors palette. The previous schema (gradient_1/gradient_2, etc.) was
# missing `gradient_color`, which caused superfile to panic on file operations
# (index out of range on empty GradientColor).
#
# Slot semantics mirror the rest of the glats stack for visual harmony:
# selection bg = base02 (kitty/ghostty/btop), cursor = base05 (kitty/ghostty),
# titles = base07 (btop title), active/accent = base0D (tmux/rofi), and
# code preview uses the nord chroma style (cool blues instead of dracula's
# pinks/oranges).
#
# Platform-specific HM modules consume this and deploy via xdg.configFile (Linux)
# or home.file (Darwin).
#
# Usage:
#   let themeToml = import ../../shared/superfile.nix { colorScheme = config.colorScheme; };
#   in { xdg.configFile."superfile/theme/glats.toml".text = themeToml; ... }
{ colorScheme, codeSyntaxHighlight ? "nord" }:
let
  p = colorScheme.palette;
in
''
  code_syntax_highlight          = "${codeSyntaxHighlight}"

  # ========== Border ==========
  file_panel_border              = "#${p.base02}"
  sidebar_border                 = "#${p.base02}"
  footer_border                  = "#${p.base02}"
  file_panel_border_active       = "#${p.base0D}"
  sidebar_border_active          = "#${p.base0D}"
  footer_border_active           = "#${p.base0D}"
  modal_border_active            = "#${p.base0D}"

  # ========== Background ==========
  full_screen_bg                 = "#${p.base00}"
  file_panel_bg                  = "#${p.base00}"
  sidebar_bg                     = "#${p.base00}"
  footer_bg                      = "#${p.base00}"
  modal_bg                       = "#${p.base00}"

  # ========== Foreground ==========
  full_screen_fg                 = "#${p.base05}"
  file_panel_fg                  = "#${p.base05}"
  sidebar_fg                     = "#${p.base05}"
  footer_fg                      = "#${p.base05}"
  modal_fg                       = "#${p.base05}"

  # ========== Main Color ==========
  cursor                         = "#${p.base05}"
  correct                        = "#${p.base0B}"
  error                          = "#${p.base08}"
  hint                           = "#${p.base0C}"
  cancel                         = "#${p.base05}"
  gradient_color                 = ["#${p.base0D}", "#${p.base0E}"]

  # ========== File Panel ==========
  directory_icon_color           = "#${p.base0E}"
  file_panel_top_directory_icon  = "#${p.base0E}"
  file_panel_top_path            = "#${p.base05}"
  file_panel_item_selected_fg    = "#${p.base0D}"
  file_panel_item_selected_bg    = "#${p.base02}"

  # ========== Sidebar ==========
  sidebar_title                  = "#${p.base07}"
  sidebar_item_selected_fg       = "#${p.base0D}"
  sidebar_item_selected_bg       = "#${p.base02}"
  sidebar_divider                = "#${p.base02}"

  # ========== Modal ==========
  modal_cancel_fg                = "#${p.base00}"
  modal_cancel_bg                = "#${p.base08}"
  modal_confirm_fg               = "#${p.base00}"
  modal_confirm_bg               = "#${p.base0B}"

  # ========== Help Menu ==========
  help_menu_hotkey               = "#${p.base08}"
  help_menu_title                = "#${p.base07}"
''
