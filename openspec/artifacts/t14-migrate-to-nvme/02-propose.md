# SDD Change Proposal: t14-migrate-to-nvme (v2 — Direct)

## 1. Intent
Migrar el ThinkPad T14 AMD Gen4 de `/dev/sda` (btrfs) a `/dev/nvme0n1` (XFS) **sin live USB**, directamente desde el sistema corriendo, usando `nixos-install --root --flake`.

## 2. Scope
- Particionar/ formatear NVMe: ESP (vfat) + XFS root
- Agregar `boot.initrd.supportedFilesystems = [ "xfs" ]` al host config (único cambio en el repo)
- `nixos-install --root /mnt --flake /etc/nixos#t14` — construye todo fresco
- Migrar solo `/home/`, `/var/lib/sops-nix/key.txt`, `/etc/ssh/ssh_host_*`
- Bootloader manejado automáticamente por nixos-install
- Reboot y seleccionar NVMe en BIOS

## 3. Partition Layout
| Partition | Size | FS | Mount |
|-----------|------|----|-------|
| nvme0n1p1 | 1 GiB | vfat | /boot |
| nvme0n1p2 | remainder | XFS | / |

**Swap**: Opcional. Si se quiere, partición swap separada o archivo swap en XFS.

## 4. Approach: nixos-install directo desde sistema corriendo
- No necesita live USB
- No necesita rsync de /nix/store (nixos-install construye closure fresco)
- Bootloader (systemd-boot) instalado automáticamente por nixos-install
- Único cambio en el repo: agregar `boot.initrd.supportedFilesystems = [ "xfs" ]`

## 5. Plan (~30 min total)
1. Editar `hosts/t14/default.nix` — agregar XFS al initrd
2. `sudo nix flake check` — validar
3. Particionar NVMe con `parted`
4. Formatear: vfat ESP + XFS root
5. Montar en /mnt
6. `sudo nixos-generate-config --root /mnt`
7. `sudo nixos-install --root /mnt --flake /etc/nixos#t14 --no-root-passwd`
8. Copiar `/home/`, sops key, SSH host keys
9. `sudo umount -R /mnt && sudo reboot`
10. BIOS → seleccionar NVMe

## 6. Riesgos
- **XFS en initrd**: Si no se agrega `boot.initrd.supportedFilesystems = [ "xfs" ]`, el kernel stage 1 no puede montar / y el boot falla.
- **sops key**: Copiar `/var/lib/sops-nix/key.txt` al nuevo root antes del primer boot.
- **Boot order**: BIOS debe tener NVMe como primer dispositivo de boot.
- **Swap**: Si se usa hibernación, mover o recrear swap.

## 7. Rollback
BIOS → seleccionar /dev/sda como boot device. El sistema viejo está intacto.

## 8. Effort
~30 minutos, mayormente esperar nixos-install build.
