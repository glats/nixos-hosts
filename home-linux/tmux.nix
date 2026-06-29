# Linux tmux configuration.  Shared base lives in ../../shared/tmux.nix.
# Platform-specific: escapeTime=0, nixpkgs plugins (no TPM, no git clones),
# xclip clipboard bindings.
#
# `lib.mkForce` is used on `extraConfig` and `plugins` to drop
# omarchy-nix's tmux module contributions on t14 (its prefix C-Space,
# status-bar theme overrides, vim-tmux-navigator plugin, etc.).  The
# shared base16 theme is preserved by re-evaluating shared/tmux.nix
# with the same `config` and using its extraConfig as the prefix of
# the forced value.  `enable` stays at default priority (all three
# sources agree on `true`) and HM's tmux module runs with the
# home-linux values.
{ pkgs, lib, config, ... }:

let
  # Re-evaluate shared/tmux.nix to grab its extraConfig string with the
  # current colorScheme interpolation.  The `imports` below also pulls
  # in shared, but the `lib.mkForce` on extraConfig replaces the merged
  # value (omarchy + shared) with the one we compute here, so the
  # double-evaluation is intentional: it lets us reference shared's
  # content without relying on the merged attrset.
  sharedExtraConfig = (import ../shared/tmux.nix { inherit config; }).programs.tmux.extraConfig;
in
{
  imports = [
    ../shared/tmux.nix
  ];

  # Pure Nix: no TPM, no git clones, everything from nixpkgs.
  programs.tmux = {
    escapeTime = 0;

    # lib.mkForce replaces the merged plugin list (which on t14 would
    # otherwise include omarchy's `vim-tmux-navigator` on top of our
    # nixpkgs set).  Same set declared in home-darwin/tmux.nix for the
    # darwin host, but via TPM plugin declarations.
    plugins = lib.mkForce (with pkgs.tmuxPlugins; [
      resurrect
      continuum
      sessionist
      yank
      vim-tmux-navigator
    ]);

    # lib.mkForce replaces the merged extraConfig.  On t14 this drops
    # omarchy's prefix C-Space, status-position top, base16-overriding
    # status colours, and the rest of its config/tmux/tmux.conf.
    # Result on all Linux hosts: shared base16 theme (clipboard via OSC 52).
    #
    # Continuum's run-shell below is repeated here deliberately: Home
    # Manager places plugin run-shells BEFORE extraConfig, but continuum
    # needs to modify status-right AFTER extraConfig sets it.  Running it
    # again at the end fixes the save interpolation that gets overwritten.
    extraConfig = lib.mkForce (sharedExtraConfig + ''
      run-shell ${pkgs.tmuxPlugins.continuum}/share/tmux-plugins/continuum/continuum.tmux
    '');
  };
}
