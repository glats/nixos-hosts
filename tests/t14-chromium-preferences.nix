# Run: nix eval --impure --json "path:$PWD#nixosConfigurations.t14" --apply 'host: import ./tests/t14-chromium-preferences.nix { inherit host; }'
{ host }:
let
  lib = host.pkgs.lib;
  hm = host.config.home-manager.users.glats;
  seed = hm.home.activation.seedChromiumPreferences or null;
  checks = {
    preferencesNotLinked = !(hm.xdg.configFile ? "chromium/Default/Preferences");
    preferencesSeededOnlyWhenAbsent =
      seed != null
      && builtins.elem "linkGeneration" seed.after
      && lib.hasInfix "chromium/Default/Preferences" seed.data
      && lib.hasInfix "! -e" seed.data;
    flagsPreserved = lib.hasInfix "--ozone-platform=wayland" hm.xdg.configFile."chromium-flags.conf".text;
  };
in
assert lib.assertMsg (lib.all (ok: ok) (builtins.attrValues checks)) (
  "T14 Chromium preference checks failed: "
  + lib.concatStringsSep ", " (builtins.attrNames (lib.filterAttrs (_: ok: !ok) checks))
);
checks
