{
  lib,
  stdenv,
  kernel,
}:

stdenv.mkDerivation {
  pname = "rog-efi-poweroff";
  version = "unstable-2026-09-10";

  src = ./.;

  hardeningDisable = [ "all" ];

  makeFlags = [
    "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  ];

  installPhase = ''
    runHook preInstall
    install -D rog-efi-poweroff.ko "$out/lib/modules/${kernel.modDirVersion}/misc/rog-efi-poweroff.ko"
    runHook postInstall
  '';

  meta = {
    description = "GL553VD EFI ResetSystem power-off module (ACPI S5 firmware freeze workaround)";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.linux;
  };
}
