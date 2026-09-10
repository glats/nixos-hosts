# rog-efi-poweroff
# Out-of-tree kernel module: DMI-scoped EFI ResetSystem power-off for the
# ASUS ROG GL553VD, whose firmware freezes at the hardware-level ACPI S5
# transition (kernel modules are inherently C — documented exception to
# the Go-only operational-scripts policy, per repo AGENTS.md).
{ lib
, stdenv
, kernel
,
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
