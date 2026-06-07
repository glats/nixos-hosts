# Contexto: T14 - Plan de trabajo

## Fecha: 2026-06-04
## Autor: glats

## Estado actual

- **T14**: Lenovo ThinkPad T14 (AMD Ryzen, iGPU AMD)
- **OS**: NixOS 26.05 instalado, booteable
- **Branch**: `master` (repo en /home/glats/.nixos)
- **Config actual**: TTY-only (minimal)

## Qué funciona ahora

- [x] Boot a TTY (kmscon)
- [x] Terminal con zsh, tmux, nvim
- [x] Opencode disponible
- [x] Git, SSH configurados
- [x] SOPS preparado (host_t14 en .sops.yaml, secrets re-encriptados)

## Qué NO funciona ahora

- [ ] Hyprland (no está activo)
- [ ] Display manager (no hay SDDM/greetd)
- [ ] Omarchy (no importado)
- [ ] Waybar, Mako, etc. (no configurados)
- [ ] SOPS de sistema (desactivado en t14/default.nix)

## Próximos pasos (prioridad)

### 1. Activar Hyprland + Omarchy (Phase 1)

**Objetivo**: Tener un desktop funcional con Hyprland

**Acciones**:
- Importar `omarchy-nix` en flake.nix
- Activar `programs.hyprland` en t14/default.nix
- Configurar SDDM como display manager
- Agregar `hardware.graphics` para AMD iGPU
- Agregar `security.polkit` para auth
- Revisar que `home-manager` tenga los módulos de Omarchy

**Archivos a tocar**:
- `hosts/t14/default.nix`
- `flake.nix` (si falta omarchy-nix)
- `hosts/t14/home/` (waybar, mako, hypr config)

### 2. SOPS de sistema (Phase 2)

**Objetivo**: Descifrar secrets automáticamente al bootear

**Acciones**:
- Descomentar `../../modules/base/sops.nix` y `./secrets.nix` en t14/default.nix
- Verificar que `/etc/ssh/ssh_host_ed25519_key.pub` existe
- Confirmar que `sops updatekeys` funciona para todos los secrets

**Archivos a tocar**:
- `hosts/t14/default.nix`
- `hosts/t14/secrets.nix`

### 3. Personalización (Phase 3)

**Objetivo**: Ajustar la experiencia del usuario

**Ideas**:
- Revisar layout de teclado (`es,latam` ya está)
- Ajustar monitor/mouses si es necesario
- Configurar opencode providers si cambian
- Revisar si se necesita `mouse-wiggle` o similar
- Revisar Remmina si se necesita para trabajo

## Notas técnicas

### Hardware
- **CPU**: AMD Ryzen Pro (Zen 2)
- **GPU**: AMD Radeon Graphics (integrada)
- **RAM**: ~32GB
- **Disco**: /dev/nvme0n1 (XFS root, FAT32 /boot)
- **WiFi**: Intel AX200 (probablemente)

### Configuración actual
- **Bootloader**: systemd-boot
- **Shell**: zsh
- **Editor**: neovim
- **Terminal**: tmux + kmscon
- **Network**: networkmanager, avahi, firewall, ssh
- **Users**: glats (admin), root

### SOPS keys
- **admin_glats**: age1j4mxejwmktekgf24sju92ryayh5jlmv4ldxj62e2srwghpkpuujscct9lt
- **host_t14**: age196hvyhz9nhwdxyadwj36umtssxqdhde80x3xyhkt9l9va73mtq3s3pxvnk
- **host_rog**: age1q46qlf4kt0pc255nrl4r24m5hnvqwqf9wd8n6206f0zg95v6993qvd9cr8
- **host_thinkcentre**: age1uhv0z8e04q2385wlrn0vgd237ts2exea375yr4yeqwx5v9zgw9esdg3rsn
- **host_mact2**: age1ngeetv5mnt8ax30tmm6799qs2779905v0jafpywuydrvw2sz7yds7rlp5z

## Comandos útiles

```bash
# Rebuild
nixos-rebuild switch --flake .#t14

# Verificar flake
nix flake check

# Formatear
format-nix

# Revisar logs
journalctl -n 50

# Revisar sops
sops -d secrets/system/passwords.yaml
```

## Riesgos conocidos

1. **Hyprland en AMD**: Puede necesitar drivers específicos o config de renderizado
2. **Omarchy en NixOS**: Es un fork experimental, puede tener bugs
3. **SOPS**: Si se pierde la key privada de admin, hay que regenerar todos los secrets
4. **Bootloader**: systemd-boot vs GRUB (actualmente systemd-boot)

## Referencias

- Repo: https://github.com/glats/nixos-hosts
- Omarchy: https://github.com/glats/omarchy-nix
- SOPS: /home/glats/.nixos/docs/sops-new-host.md
- Install guide: /home/glats/.nixos/hosts/t14/INSTALL.md

## Historial de cambios

- **2026-06-04**: Instalación minimal de t14 (TTY-only)
- **2026-06-04**: Fix de sops, merge a master
- **2026-06-04**: Documento de contexto creado

## Próxima acción

Decidir: ¿empezamos con Hyprland+Omarchy o algo más?
