# Linux-specific overlay
# Provides packages and overrides needed by NixOS hosts
{ self
, inputs
,
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

  # linuxPackages_zen is used as-is from nixpkgs (pinned via flake.lock).
  # The kernel produces vmlinuz instead of bzImage on 7.x (nixpkgs#521113).
  # Instead of overriding the kernel (which changes the hash and forces a
  # from-source rebuild), we set system.boot.loader.kernelFile = "vmlinuz"
  # in modules/features/boot.nix. The file IS a valid bzImage — just
  # named vmlinuz. The kernel stays in cache.nixos.org.

  # Symbola font: archive.org snapshots of dn-works.com URLs are brittle and
  # frequently dropped. Use the same snapshot as nixpkgs master (20221006174450).
  # If hash mismatches, nix will report the correct one.
  symbola = prev.symbola.overrideAttrs (oldAttrs: {
    src = prev.fetchzip {
      url = "https://web.archive.org/web/20221006174450/https://dn-works.com/wp-content/uploads/2020/UFAS-Fonts/Symbola.zip";
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
