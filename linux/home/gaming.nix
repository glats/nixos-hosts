{ lib, pkgs, ... }:

let
  # ROM platform directories to scaffold under ~/roms/.
  platforms = [
    "snes"
    "n64"
    "gc"
    "wii"
    "psx"
    "ps2"
    "ps3"
    "switch"
    "psp"
    "neogeo"
    "genesis"
    "gb"
    "gba"
  ];
in
{
  # ROM scaffolding — immutable dirs (fine, user adds files inside them)
  home.file = builtins.listToAttrs (
    map
      (name: {
        name = "roms/${name}";
        value = {
          source = pkgs.runCommand "roms-${name}" { } "mkdir -p $out";
          recursive = true;
        };
      })
      platforms
  );

  # RetroArch config — mutable (home.activation copies on first run so RA
  # can save to it. home.file creates an immutable symlink that breaks
  # RA's save-on-exit. Pattern from home-manager VSCode module.)
  home.activation.writeRetroarchCfg = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        CFG="$HOME/.config/retroarch/retroarch.cfg"
        # Remove stale immutable symlink from old home.file-based deploy
        if [ -L "$CFG" ]; then
          rm "$CFG"
        fi
        if [ ! -f "$CFG" ]; then
          mkdir -p "$(dirname "$CFG")"
          cat > "$CFG" <<'RAEOF'
    video_driver = "vulkan"
    video_fullscreen = "true"
    video_monitor_index = "0"

    audio_driver = "pipewire"

    input_joypad_driver = "udev"
    input_autodetect_enable = "true"
    input_max_users = "4"

    menu_driver = "ozone"
    menu_show_start_screen = "false"

    core_updater_buildbot_url = ""
    RAEOF
        fi
  '';

  # SDL2 controller mapping placeholder
  home.sessionVariables.SDL_GAMECONTROLLERCONFIG = "";
}
