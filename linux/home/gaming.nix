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
  # ── RetroArch config + ROM scaffolding ──────────────────────────────
  # Merged into a single home.file attrset so both the retroarch.cfg and
  # the ROM directories coexist (NixOS module system merges attrs, but a
  # second `home.file = { ... }` would shadow the first — hence the `//`).
  home.file = {
    ".config/retroarch/retroarch.cfg" = {
      text = ''
        # Video — Vulkan on AMD iGPU
        video_driver = "vulkan"
        video_fullscreen = "true"
        video_monitor_index = "0"

        # Audio — PipeWire (Omarchy default)
        audio_driver = "pipewire"

        # Input — udev joypad + autoconfig
        input_joypad_driver = "udev"
        input_autodetect_enable = "true"
        input_max_users = "4"

        # Menu — ozone (controller-navigable)
        menu_driver = "ozone"
        menu_show_start_screen = "false"

        # Offline — cores are declarative, no online updater
        core_updater_buildbot_url = ""
      '';
    };
  }
  // builtins.listToAttrs (
    map (name: {
      name = "roms/${name}";
      value = {
        source = pkgs.runCommand "roms-${name}" { } "mkdir -p $out";
        recursive = true;
      };
    }) platforms
  );

  # ── SDL2 controller mapping placeholder ─────────────────────────────
  home.sessionVariables.SDL_GAMECONTROLLERCONFIG = "";
}
