# T14 btop local additions.
#
# Omarchy's HM module supplies a default btop config (programs.btop with
# the tokyo-night theme and a generic layout). This file overrides it
# with the user's t14 personal config and switches to the glats theme.
#
# Why this module exists:
#   * The user keeps a hand-curated btop.conf on the external drive
#     (color_theme = "glats", vim_keys = true, proc_tree = true, etc.).
#   * The glats theme file itself is already deployed by
#     omarchy-personalizado.nix (themes/glats/btop.theme) — this module
#     only handles the btop.conf companion file.
#   * The user requires save_config_on_exit = false. Their source file
#     sets it to true (so btop persists tweaks made inside the TUI),
#     but we flip it to false at deploy time: HM's activation step
#     then cannot race with a live btop process overwriting the file,
#     and the deployed conf always matches what HM ships.
#
# Build-time patching:
#   We use pkgs.runCommand to run a single sed substitution at Nix
#   evaluation time, producing a patched btop.conf in /nix/store.
#   This keeps the repo source file (./btop.conf) byte-identical to
#   the file on the external drive — easier to re-sync — while
#   shipping the deployed conf with the override applied.
{ pkgs, ... }:

let
  patchedBtopConf = pkgs.runCommand "btop.conf" { } ''
    substitute ${./btop.conf} $out \
      --replace-fail 'save_config_on_exit = true' 'save_config_on_exit = false'
  '';
in
{
  xdg.configFile."btop/btop.conf".source = patchedBtopConf;
}
