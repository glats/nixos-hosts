{ pkgs, lib, ... }:

let
  palette = import ../../shared/palette.nix;
  colors = import ../../lib/colors.nix { inherit lib; };
  p = palette.palette;
in

{
  services.kmscon = {
    enable = true;
    hwRender = false;
    useXkbConfig = true;
    fonts = [
      {
        name = "CaskaydiaCove Nerd Font Mono";
        package = pkgs.nerd-fonts.caskaydia-cove;
      }
    ];
    extraConfig = ''
      palette=custom
      palette-background=${colors.hexToRgb p.base00}
      palette-foreground=${colors.hexToRgb p.base05}
      palette-black=${colors.hexToRgb p.base00}
      palette-red=${colors.hexToRgb p.base08}
      palette-green=${colors.hexToRgb p.base0B}
      palette-yellow=${colors.hexToRgb p.base0A}
      palette-blue=${colors.hexToRgb p.base0D}
      palette-magenta=${colors.hexToRgb p.base0E}
      palette-cyan=${colors.hexToRgb p.base0C}
      palette-light-grey=${colors.hexToRgb p.base05}
      palette-dark-grey=${colors.hexToRgb p.base03}
      palette-light-red=${colors.hexToRgb p.base09}
      palette-light-green=${colors.hexToRgb p.brightGreen}
      palette-light-yellow=${colors.hexToRgb p.brightYellow}
      palette-light-blue=${colors.hexToRgb p.brightBlue}
      palette-light-magenta=${colors.hexToRgb p.brightMagenta}
      palette-light-cyan=${colors.hexToRgb p.brightCyan}
      palette-white=${colors.hexToRgb p.base07}
    '';
  };

  # === Eagerly instantiate kmscon on tty1-tty6 ===
  # The NixOS kmscon module already registers `kmsconvt@.service` as a
  # template alias for `autovt@.service`, so logind spawns kmscon on a
  # given TTY on first VT-switch. In practice this can race against the
  # kernel's in-TTY text fallback on slow boots and on some laptops
  # (Lenovo T14 included) where logind's autovt hook fires after the
  # text appears, leaving a brief "broken TTY" flash. Statically
  # pulling kmsconvt@tty1..tty6 into multi-user.target guarantees the
  # kmscon process is up before any user can VT-switch, so multiple
  # working TTYs are always available (Chvt 1..6 lands on kmscon, never
  # the kernel VT).
  #
  # tty1 is special: the kmscon module already adds it to
  # getty.target.wants, so adding it again here would be a no-op
  # duplicate. We start at tty2 and explicitly wantBy multi-user.target
  # so the units are started in dependency order at boot and stay up
  # across logout.
  systemd.services =
    lib.genAttrs
      [
        "kmsconvt@tty2"
        "kmsconvt@tty3"
        "kmsconvt@tty4"
        "kmsconvt@tty5"
        "kmsconvt@tty6"
      ]
      (_: {
        wantedBy = [ "multi-user.target" ];
      });
}
