{
  ...
}:

{
  # mpv default: use VA-API hardware decoding on this AMD laptop.
  # The radeonsi VA driver comes from `mesa` (transitively pulled in by
  # hardware.graphics.enable + nixos-hardware T14 AMD Gen 4 profile);
  # see modules/base/profiles/media.nix for the full VA-API stack notes
  # and modules/hardware/amd-laptop.nix for the verification recipe.
  xdg.configFile."mpv/mpv.conf".text = "hwdec=vaapi\n";
}
