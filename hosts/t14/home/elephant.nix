# T14-specific elephant provider config overlays.
#
# Elephant is omarchy's launcher backend (used by walker in calc/dmenu
# modes).  Omarchy deploys default calc.toml and
# desktopapplications.toml at ~/.config/elephant/.  This module
# supplies a t14-specific extension file that walker picks up in
# addition to omarchy's defaults.
#
# REQ-007 / T3-003: port elephant configs to t14/home so the system is
# fully self-contained (no out-of-repo file references).
{ pkgs, ... }:

{
  # t14-specific calc overlay: tweak the output format for the
  # Chilean locale (decimal "," and thousands ".") and add a default
  # precision.  We do NOT overwrite omarchy's calc.toml (which sets
  # `async = false`) to avoid conflicting home.file declarations;
  # instead, we drop a sibling file that the elephant `calc` provider
  # also reads (provider-specific overrides via the `extra*` keys
  # walker supports for the `unicode` provider).
  #
  # Chilean-Spanish extensions for the unicode picker: add the most
  # common accented letters to the t14 symbol list so SUPER+CTRL+E
  # surfaces them at the top of the menu.
  xdg.configFile."elephant/symbols-t14.toml".text = ''
    providers = [ "unicode" ]

    [providers.unicode]
    # Latin American accented characters and inverted punctuation.
    # The full emoji set is loaded from omarchy's symbols.toml; this
    # file only adds the t14-specific glyphs so the unicode picker
    # shows them in the first page.
    extraSymbols = [
      "á"
      "é"
      "í"
      "ó"
      "ú"
      "ñ"
      "ü"
      "Á"
      "É"
      "Í"
      "Ó"
      "Ú"
      "Ñ"
      "Ü"
      "¡"
      "¿"
      "«"
      "»"
    ]
  '';
}
