# Compare evaluated policy with a supplied pre-migration flake.
# Run with candidate and baseline flake values from isolated source snapshots.
{ candidate, baseline }:
let
  policy = host: {
    omarchy = builtins.removeAttrs host.omarchy [ "wifi" ];
    greetd = host.services.greetd.settings;
    mouse = host.home-manager.users.glats.systemd.user.services.mouse-wiggle;
    input = host.home-manager.users.glats.wayland.windowManager.hyprland.settings.input;
    packages = map toString host.home-manager.users.glats.home.packages;
    logind = host.services.logind.settings;
  };
in
assert
  policy candidate.nixosConfigurations.t14.config == policy baseline.nixosConfigurations.t14.config;
{
  preserved = true;
}
