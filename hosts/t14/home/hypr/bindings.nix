# T14 Hyprland keybindings — non-visual extensions on top of omarchy.
#
# Omarchy owns the full binding surface.  This module adds only
# t14-specific scripts that omarchy does not provide.
{ ... }:

{
  wayland.windowManager.hyprland.extraConfig = ''
    # T14: Window switcher (walker-based, uses omarchy's walker menu
    # backend).  `bindd` requires 5 positional fields: mod, key,
    # description, dispatcher, arg.  The previous form had only 4
    # (missing the description), so hyprland silently dropped the
    # binding.  Keep a description between key and dispatcher.
    bindd = SUPER, Q, Window switcher, exec, window-switcher.sh

    # T14: SUPER+M -> local window-switcher script (path resolves via
    # PATH that omarchy's hyprland session inherits from
    # ~/.local/share/omarchy/bin, which is where the script is
    # deployed by `home.file` in default.nix).
    bind = SUPER, M, exec, window-switcher.sh

    # T14: Lid switch -> omarchy monitor handling.  The `on` handler
    # turns off the internal panel and routes to external monitors; the
    # `off` handler restores the internal panel when no external
    # monitor is connected.  `bindl` runs even when the session is
    # locked.
    bindl = , switch:on:Lid Switch, exec, omarchy-hw-external-monitors && omarchy-hyprland-monitor-internal off
    bindl = , switch:off:Lid Switch, exec, omarchy-hw-external-monitors || omarchy-hyprland-monitor-internal on

    # T14: SUPER+SHIFT+R -> wofi run dialog (overrides the omarchy
    # SUPER,R calculator binding with a run launcher).  Intentional
    # t14 override.
    bind = SUPER SHIFT, R, exec, wofi --show run

    # T14: SUPER+ALT+RETURN -> launch tmux in the user's preferred
    # terminal at the current working directory.  Mirrors the
    # upstream omarchy Tmux binding; declared here so the t14
    # fragment is self-contained.
    bindd = SUPER ALT, RETURN, Tmux, exec, uwsm-app -- xdg-terminal-exec --dir="$(omarchy-cmd-terminal-cwd)" tmux new

    # T14: SUPER+SHIFT+ALT+F -> file manager opened in the current
    # working directory.  Mirrors the upstream omarchy bindd for
    # file-manager-cwd.
    bindd = SUPER ALT SHIFT, F, File manager (cwd), exec, uwsm-app -- nautilus --new-window "$(omarchy-cmd-terminal-cwd)"

    # TODO: add a manual mouse-wiggle toggle binding here once a key is chosen.
    # Keep this commented so upstream SUPER CTRL, I remains the only active
    # idle toggle binding managed by omarchy-nix.
    # bind = SUPER SHIFT, ?, exec, mouse-wiggle
  '';
}
