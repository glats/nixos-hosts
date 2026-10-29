{ flake }:
let
  lib = flake.inputs.nixpkgs.lib;
  basePkgs = import flake.inputs.nixpkgs {
    system = "x86_64-linux";
    config.allowUnfree = true;
  };
  host = flake.nixosConfigurations.t14.config;
  hostPkgs = flake.nixosConfigurations.t14._module.args.pkgs;
  child = host.specialisation.compliance-off.configuration;
  glibNetworking = hostPkgs.glib-networking;
  portalOf =
    cfg:
    lib.findFirst (
      pkg: lib.hasPrefix "intune-portal" (pkg.name or "")
    ) null cfg.environment.systemPackages;
  portal = portalOf host;
  broker = hostPkgs.microsoft-identity-broker;
  checks = {
    portalPresentWhenOn = host.services.intune.enable && portal != null;
    portalWrapsGioTlsProvider =
      portal != null
      &&
        lib.hasInfix
          (builtins.unsafeDiscardStringContext "wrapProgram $out/bin/intune-portal --prefix GIO_EXTRA_MODULES : ${glibNetworking}/lib/gio/modules")
          (builtins.unsafeDiscardStringContext (portal.postFixup or ""));
    wrapperNativeInputPresent =
      portal != null && lib.elem hostPkgs.makeWrapper (portal.nativeBuildInputs or [ ]);
    priorPackageAttributesPreserved =
      portal != null
      && portal.version == basePkgs.intune-portal.version
      && portal.dontPatchELF == true
      && portal.src.outPath == basePkgs.intune-portal.src.outPath
      && portal.buildPhase == basePkgs.intune-portal.buildPhase
      && portal.installPhase == basePkgs.intune-portal.installPhase;
    wrappedPortalIsSystemdPackage = portal != null && lib.elem portal host.systemd.packages;
    offOmitsPortal = !child.services.intune.enable && portalOf child == null;
    brokerUnchanged =
      lib.elem broker host.environment.systemPackages
      && lib.elem broker host.systemd.packages
      && broker.drvPath == basePkgs.microsoft-identity-broker.drvPath
      && !(lib.hasInfix "GIO_EXTRA_MODULES" (broker.postFixup or ""));
  };
in
assert lib.assertMsg (lib.all (ok: ok) (builtins.attrValues checks)) (
  "T14 Intune TLS packaging checks failed: "
  + lib.concatStringsSep ", " (builtins.attrNames (lib.filterAttrs (_: ok: !ok) checks))
);
checks
