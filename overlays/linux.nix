# Linux-specific overlay
# Provides packages and overrides needed by NixOS hosts
{
  self,
  inputs,
}:
final: prev: {
  # Cross-platform packages from flake outputs
  inherit (self.packages.${prev.stdenv.hostPlatform.system})
    nixos-scripts
    gentle-ai
    engram
    gentle-ai-assets
    gentle-ai-assets-vanilla
    engram-assets
    engram-assets-vanilla
    secret-guard-assets
    opencode-npm-packages
    opencode
    openfang
    ;

  # Local pkgs/ derivations
  asus-fan-control = final.callPackage ../pkgs/asus-fan-control {
    asus-fan-control-src = inputs.asus-fan-control-src;
  };
  pipewire-module-xrdp = final.callPackage ../pkgs/pipewire-module-xrdp {
    pipewire-module-xrdp-src = inputs.pipewire-module-xrdp-src;
  };

  # Workaround for linux-zen 7.0.12 producing vmlinuz instead of bzImage
  # See https://github.com/NixOS/nixpkgs/issues/521113
  linuxPackages_zen = prev.linuxPackages_zen.extend (
    _: ksuper: {
      kernel = ksuper.kernel.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          if [ -f "$out/vmlinuz" ] && [ ! -e "$out/bzImage" ]; then
            ln -s vmlinuz "$out/bzImage"
          fi
        '';
      });
    }
  );

  # Symbola font: archive.org snapshot 20221006174450 returns HTTP 503.
  # Try alternate archive.org snapshot from 20201013230756 (Gentoo ebuild).
  # Upstream dn-works.com changes the zip without version bumps, so archive.org
  # snapshots may drift. If hash mismatches, nix will report the correct one.
  symbola = prev.symbola.overrideAttrs (oldAttrs: {
    src = prev.fetchzip {
      url = "https://web.archive.org/web/20201013230756/https://dn-works.com/wp-content/uploads/2020/UFAS-Fonts/Symbola.zip";
      stripRoot = false;
      hash = "sha256-TsHWmzkEyMa8JOZDyjvk7PDhm239oH/FNllizNFf398=";
    };
  });

  libmateweather = prev.libmateweather.overrideAttrs (oldAttrs: {
    # Fix pointer offset bug in METAR parsing
    postPatch = (oldAttrs.postPatch or "") + ''
      substituteInPlace libmateweather/weather-metar.c \
        --replace-fail 'p += WEATHER_LOCATION_CODE_LEN + 11;' 'p += WEATHER_LOCATION_CODE_LEN + 17;'
    '';
  });
}
