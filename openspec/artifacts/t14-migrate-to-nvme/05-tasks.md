# SDD Tasks: t14-migrate-to-nvme (v2 — Direct)

**12 tareas** en 4 fases. Sin live USB. Sin rsync de /nix/store. Sin live ISO.

## Phase 1: Preparación (en sistema corriendo)

### T1 — Agregar XFS al initrd ✅
**Type:** config-change
**Deps:** none
**Description:** Editar `hosts/t14/default.nix` y agregar:
```nix
boot.initrd.supportedFilesystems = [ "xfs" ];
```
**Success:** Línea agregada al archivo.

### T2 — Validar flake ✅
**Type:** verification
**Deps:** T1
**Description:**
```bash
cd ~/.nixos
nix flake check --no-build
```
**Success:** `nix flake check` pasa.

### T3 — Backup datos críticos
**Type:** setup
**Deps:** T2
**Description:**
```bash
sha256sum /var/lib/sops-nix/key.txt > ~/sops-key-checksum.txt
sha256sum /etc/ssh/ssh_host_ed25519_key > ~/ssh-key-checksum.txt
lsblk > ~/lsblk-before.txt
```
**Success:** Checksums guardados, git push hecho.

### T4 — Verificar NVMe detectado
**Type:** setup (INFO)
**Deps:** T3
**Description:** `lsblk | grep nvme` — el NVMe debe aparecer como `/dev/nvme0n1`. Si no aparece, revisar conexión física/BIOS.
**Success:** NVMe visible en `lsblk`.

## Phase 2: Particionado y Formateo

### T5 — Particionar NVMe
**Type:** migration-step
**Deps:** T4
**Description:**
```bash
sudo parted /dev/nvme0n1 -- mklabel gpt
sudo parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 1GiB
sudo parted /dev/nvme0n1 -- set 1 boot on
sudo parted /dev/nvme0n1 -- mkpart root xfs 1GiB 100%
sudo parted /dev/nvme0n1 -- print
```
**Success:** `parted --print` muestra 2 particiones: ESP (fat32) + root (xfs).

### T6 — Formatear particiones
**Type:** migration-step
**Deps:** T5
**Description:**
```bash
sudo mkfs.fat -F 32 -n NIXBOOT /dev/nvme0n1p1
sudo mkfs.xfs -L NIXROOT /dev/nvme0n1p2
sudo blkid /dev/nvme0n1p1 /dev/nvme0n1p2
```
**Success:** Ambas particiones formateadas. UUIDs registrados.

### T7 — (Opcional) Partición swap
**Type:** migration-step (opcional)
**Deps:** T5
**Description:** Si se quiere swap separado:
```bash
sudo parted /dev/nvme0n1 -- mkpart swap linux-swap -8GiB 100%
sudo mkswap -L NIXSWAP /dev/nvme0n1p3
sudo swapon /dev/nvme0n1p3
```
O crear archivo swap en XFS:
```bash
sudo truncate -s 0 /mnt/swapfile
sudo chattr +C /mnt/swapfile  # deshabilitar CoW
sudo fallocate -l 8G /mnt/swapfile
sudo chmod 600 /mnt/swapfile
sudo mkswap /mnt/swapfile
```
**Success:** Swap activo en el nuevo disco.

## Phase 3: Instalación

### T8 — Montar NVMe y generar hardware config
**Type:** migration-step
**Deps:** T6
**Description:**
```bash
sudo mkdir -p /mnt
sudo mount /dev/disk/by-label/NIXROOT /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/disk/by-label/NIXBOOT /mnt/boot
sudo nixos-generate-config --root /mnt
cat /mnt/etc/nixos/hardware-configuration.nix
```
**Success:** Hardware config generado mostrando XFS root + vfat boot en NVMe UUIDs.

### T9 — Instalar NixOS en NVMe
**Type:** migration-step (CORE)
**Deps:** T2, T8
**Description:**
```bash
sudo nixos-install --root /mnt --flake /etc/nixos#t14 --no-root-passwd
```
**Success:** `nixos-install` completa sin errores. Bootloader instalado en ESP del NVMe.

### T10 — Migrar datos de usuario + secrets
**Type:** migration-step
**Deps:** T9
**Description:**
```bash
# /home/ — datos de usuario
sudo rsync -aAX --info=progress2 /home/ /mnt/home/

# sops key — CRÍTICO (sin esto no desencripta secrets en primer boot)
sudo mkdir -p /mnt/var/lib/sops-nix
sudo cp /var/lib/sops-nix/key.txt /mnt/var/lib/sops-nix/
sha256sum /mnt/var/lib/sops-nix/key.txt  # debe coincidir con backup

# SSH host keys — opcional (evita warnings)
sudo cp /etc/ssh/ssh_host_* /mnt/etc/ssh/ 2>/dev/null || true

# Verificar
ls /mnt/home/glats/
```
**Success:** `/home/glats/` completo, sops key copiada con SHA256 verificado.

## Phase 4: Reboot y Verificación

### T11 — Reboot y seleccionar NVMe en BIOS
**Type:** migration-step
**Deps:** T10
**Description:**
```bash
sudo umount -R /mnt
sudo reboot
# Durante POST: F2/Del → Boot Menu → seleccionar NVMe
```
**Success:** Sistema bootea desde NVMe. systemd-boot muestra entries.

### T12 — Verificación post-migración
**Type:** verification
**Deps:** T11
**Description:** Checklist desde el nuevo sistema:
```bash
# 1. Dispositivos correctos
lsblk -f
# 2. sops funciona
sops -d /run/secrets/glats_hashed_password | head -3
# 3. Bootloader correcto
bootctl status
# 4. No hay servicios fallados
systemctl --failed
# 5. Flake válido
cd /etc/nixos && nix flake check --no-build
# 6. Hyprland funciona (login gráfico)
# 7. Full rebuild
sudo nixos-rebuild switch --flake /etc/nixos#t14
```
**Success:** Todos los checks pasan. sops desencripta, bootctl muestra NVMe ESP, rebuild exitoso.

## Bonus: Post-Migración (opcional, tras 1 semana)

### T13 — Commit del cambio
```bash
cd ~/.nixos
git add hosts/t14/default.nix
git add hosts/t14/hardware-configuration.nix
git commit -m "chore(t14): migrate from SATA btrfs to NVMe XFS"
git push
```

### T14 — Wipe old SATA (opcional)
```bash
sudo sgdisk -z /dev/sda
```

## Resumen de Tareas

| # | Tarea | Tipo | Dependencias |
|---|-------|------|-------------|
| T1 | Agregar XFS al initrd | config-change | — |
| T2 | Validar flake | verification | T1 |
| T3 | Backup datos críticos | setup | T2 |
| T4 | Verificar NVMe detectado | setup | T3 |
| T5 | Particionar NVMe | migration-step | T4 |
| T6 | Formatear particiones | migration-step | T5 |
| T7 | (Opcional) Partición swap | migration-step | T5 |
| T8 | Montar NVMe + generar hw-config | migration-step | T6 |
| T9 | nixos-install | migration-step | T2, T8 |
| T10 | Migrar /home + secrets | migration-step | T9 |
| T11 | Reboot + BIOS NVMe | migration-step | T10 |
| T12 | Verificación post-migración | verification | T11 |
| T13 | Commit (opcional) | cleanup | T12 |
| T14 | Wipe SATA (opcional) | cleanup | T13 |
