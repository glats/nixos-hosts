# T14 Home Manager — DEFAULTS ONLY (no personalizations).
#
# This is the minimal Omarchy configuration. Only the upstream
# omarchy-nix homeManagerModules.default is imported. No t14 overlays,
# no custom themes, no shared home-linux modules.
#
# Goal: make Omarchy defaults work first. Personalizations will be
# re-added later once the base is stable.
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [
    # Omarchy HM module — provides everything: Hyprland, waybar, walker,
    # ghostty, alacritty, kitty, btop, zsh, tmux, neovim, git, starship,
    # theme-switcher, etc. This is the ONLY import for the defaults-only
    # configuration.
    inputs.omarchy-nix.homeManagerModules.default

    # OpenCode stack (shared with rog/thinkcentre)
    ../../../shared/opencode.nix
    ../../../shared/opencode-profile.nix
    ../../../shared/sops.nix
    inputs.sops-nix.homeManagerModules.sops
  ];

  # Hyprland input: latam keyboard layout (t14-specific)
  wayland.windowManager.hyprland.settings.input = {
    kb_layout = "latam";
    kb_variant = "";
  };

  # === Hyprland crash logging ===
  # The user has been hitting Hyprland crashes on the latest
  # hyprland-0.54.3+date=2026-03-27 build and needs persistent logs
  # to triage. By default Hyprland writes its log to
  #   $XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.log
  # (typically /run/user/1000/hypr/XXXXXXXX/hyprland.log) and keeps
  # historical crash reports under
  #   $XDG_CACHE_HOME/hyprland/hyprlandCrashReport[PID].txt
  # but the WRITE is gated by `debug:disable_logs` which defaults to
  # true — meaning the file is created but never written, and stdout
  # logs are dropped. Setting it to false enables both the logfile
  # and stdout logging. We also set `enable_stdout_logs` so messages
  # still appear in the journal (greetd's user session -> systemd
  # user manager) and `gl_debugging` so wlroots surfaces GL errors
  # that often precede the crashes. None of this changes runtime
  # behavior beyond verbose logging.
  wayland.windowManager.hyprland.settings.debug = {
    disable_logs = false;
    enable_stdout_logs = true;
    gl_debugging = true;
    # Colored stdout is great for interactive debugging but useless
    # in the journal/logfile — keep ANSI codes off so the saved log
    # is greppable.
    colored_stdout_logs = false;
  };

  # Required by Home Manager
  home.stateVersion = "25.05";
}
