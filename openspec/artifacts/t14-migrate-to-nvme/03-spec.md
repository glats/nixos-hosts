# SDD Delta Spec: t14-migrate-to-nvme (v2 — Direct)

## Requirements

### R1 — Storage Layout
- NVMe con GPT: ESP (vfat, ~1GiB) + XFS root (remainder)
- Swap: archivo swap en XFS o partición separada (a elección del usuario)
- Particiones alineadas a 1 MiB

### R2 — Filesystem Migration
- Raíz cambia de btrfs (subvolumes) a XFS (plano)
- `/home` y `/nix` son directorios normales en XFS, no mounts separados

### R3 — Initrd Support
- `boot.initrd.supportedFilesystems = [ "xfs" ]` agregado al host config
- Sin esto el kernel stage 1 no puede montar XFS

### R4 — Installation Method
- Usar `nixos-install --root --flake` desde el sistema corriendo
- NO se necesita live USB
- NO se necesita rsync de /nix/store
- Bootloader (systemd-boot) instalado automáticamente

### R5 — Data Preservation
- `/home/` migrado completo con rsync
- `/var/lib/sops-nix/key.txt` copiado byte-por-byte
- `/etc/ssh/ssh_host_*` copiados (para evitar warnings de host key changed)

### R6 — System Identity
- sops-nix debe funcionar en el primer boot (key.txt preservado)
- machine-id será nuevo (nixos-install genera uno) — journal no preservado

### R7 — Flake Integration
- Único cambio en `hosts/t14/default.nix`: agregar `boot.initrd.supportedFilesystems`
- `hosts/t14/hardware-configuration.nix` generado por `nixos-generate-config`
- `nix flake check` debe pasar

### R8 — Rollback
- /dev/sda nunca se modifica
- Boot desde sda en BIOS = sistema original intacto

## Scenarios

### S1 — Happy path
Given sistema corriendo en sda,
When se ejecuta la migración directa,
Then NVMe bootea con todos los servicios, sops desencripta, Hyprland funciona.

### S2 — XFS no soportado en initrd
Given falta `boot.initrd.supportedFilesystems = [ "xfs" ]`,
When sistema intenta bootear desde NVMe,
Then kernel stage 1 falla al montar raíz.
Fix: bootear desde sda, agregar la línea, rebuild.

### S3 — sops key no copiada
Given /var/lib/sops-nix/key.txt no se copió al nuevo root,
When sistema bootea desde NVMe,
Then sops genera key nueva y no puede desencriptar secrets.
Fix: copiar key desde sda, rebuild.

### S4 — Rollback
Given migración no funciona como se espera,
When BIOS selecciona sda,
Then sistema original funciona exactamente como antes.

### S5 — Sin swap
Given no se configuró swap en NVMe,
When sistema bootea,
Then no hay swap (funcional, pero sin soporte para hibernación).
Fix: agregar archivo swap post-migración.

## Verification Criteria
- [ ] R1: `lsblk` muestra NVMe con GPT, vfat ESP + XFS root
- [ ] R2: `findmnt /` muestra xfs, `/home` y `/nix` son directorios en /
- [ ] R3: `cat /run/current-system/configuration.nix | grep supportedFilesystems` incluye xfs
- [ ] R4: `bootctl status` muestra NVMe ESP como activo
- [ ] R5: `/home/glats/` íntegro, `diff /var/lib/sops-nix/key.txt` = mismo hash que antes
- [ ] R6: `sops -d /run/secrets/glats_hashed_password` funciona
- [ ] R7: `nix flake check` pasa en el repo
- [ ] R8: BIOS boot desde sda funciona (verificado antes de wipear)
