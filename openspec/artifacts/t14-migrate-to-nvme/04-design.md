# SDD Technical Design: t14-migrate-to-nvme (v2 — Direct)

## 1. Architecture Overview

Migración directa desde sistema NixOS corriendo. Sin live USB. Sin rsync de /nix/store.

```
Sistema corriendo en /dev/sda (btrfs)
         │
         ├── 1. parted /dev/nvme0n1 → GPT (ESP + XFS)
         ├── 2. mkfs.vfat + mkfs.xfs
         ├── 3. mount NVMe en /mnt
         ├── 4. nixos-generate-config --root /mnt → hardware-configuration.nix
         ├── 5. nixos-install --root /mnt --flake /etc/nixos#t14
         │       └── build closure + install bootloader auto
         ├── 6. rsync /home/ + cp sops key + cp SSH keys
         └── 7. reboot → BIOS → NVMe
```

## 2. Partition Scheme

```
/dev/nvme0n1
├── nvme0n1p1: 1GiB, vfat, ESP (/boot)
└── nvme0n1p2: resto, XFS, root (/)
```

Swap: el usuario decide. Opciones:
- Partición swap separada
- Archivo swap en XFS (truncate + mkswap + swapon)
- Sin swap (solo si no usa hibernación)

**Comandos**:
```bash
sudo parted /dev/nvme0n1 -- mklabel gpt
sudo parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 1GiB
sudo parted /dev/nvme0n1 -- set 1 boot on
sudo parted /dev/nvme0n1 -- mkpart root xfs 1GiB 100%
sudo mkfs.fat -F 32 -n NIXBOOT /dev/nvme0n1p1
sudo mkfs.xfs -L NIXROOT /dev/nvme0n1p2
```

## 3. Único Cambio en el Repo

Agregar en `hosts/t14/default.nix`:
```nix
boot.initrd.supportedFilesystems = [ "xfs" ];
```

Razón: el kernel en stage 1 (initrd) necesita el driver XFS para montar la raíz. Sin esto, el boot falla con "an error occurred at stage 1".

No es necesario tocar nada más. El hardware-configuration.nix se genera automáticamente.

## 4. Instalación con nixos-install

```bash
sudo mount /dev/disk/by-label/NIXROOT /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/disk/by-label/NIXBOOT /mnt/boot
sudo nixos-generate-config --root /mnt
sudo nixos-install --root /mnt --flake /etc/nixos#t14 --no-root-passwd
```

**Qué hace nixos-install:**
1. Copia `/etc/nixos` a `/mnt/etc/nixos` (o usa el flake path)
2. Construye el system closure con `nix build`
3. Ejecuta `switch-to-configuration boot` dentro del chroot
4. Esto instala systemd-boot en el ESP montado en `/mnt/boot`
5. Genera machine-id nuevo

**Flag `--no-root-passwd`**: no pide password para root (se usa sudoers y el passwd de user).

## 5. Post-Install: Migración de Datos

```bash
# /home/ — datos de usuario (lo único pesado)
sudo rsync -aAX /home/ /mnt/home/

# sops key — CRÍTICO para desencriptar secrets en primer boot
sudo mkdir -p /mnt/var/lib/sops-nix
sudo cp /var/lib/sops-nix/key.txt /mnt/var/lib/sops-nix/

# SSH host keys — opcional, evita warnings
sudo cp /etc/ssh/ssh_host_* /mnt/etc/ssh/ 2>/dev/null || true
```

**Por qué copiar sops key y no la SSH key**: sops-nix usa `sops.age.keyFile = "/var/lib/sops-nix/key.txt"`. Si no se copia, `generateKey = true` genera una nueva que no está en `.sops.yaml`. La SSH key es fallback, pero mejor tener la key original.

## 6. Bootloader

nixos-install llama a `switch-to-configuration boot` dentro del chroot, que:
1. Construye entries en `/boot/loader/entries/nixos-*.conf`
2. systemd-boot detecta automáticamente los entries nuevos
3. `boot.loader.efi.canTouchEfiVariables` intenta setear boot order — en chroot falla silenciosamente, pero los entries se escriben igual

Post-reboot: `sudo bootctl status` para confirmar que el ESP del NVMe está activo.

## 7. Post-Migration File Layout

```
/ (XFS en nvme0n1p2)
├── boot/ (vfat en nvme0n1p1)
├── etc/
│   └── nixos → /etc/nixos (copy de nixos-install)
├── home/glats/ (rsync -aAX)
├── nix/store/ (fresco de nixos-install)
└── var/
    └── lib/
        └── sops-nix/
            └── key.txt (copiado del viejo)
```

## 8. Flujo de Reboot

1. `sudo umount -R /mnt`
2. `sudo reboot`
3. Durante POST, entrar a BIOS (F2/F12/Del)
4. Boot Menu → seleccionar NVMe drive
5. systemd-boot aparece con entries para t14
6. Sistema bootea normalmente
7. sops-nix desencripta secrets (key.txt preservado)
8. Login a Hyprland

## 9. Primer Build Post-Migración

```bash
cd /etc/nixos
nix flake check
sudo nixos-rebuild switch --flake /etc/nixos#t14
```

Esto hace el switch completo desde el nuevo disco.

## 10. Rollback

BIOS → seleccionar /dev/sda. Sistema original intacto. Nada se escribió en sda durante la migración.
