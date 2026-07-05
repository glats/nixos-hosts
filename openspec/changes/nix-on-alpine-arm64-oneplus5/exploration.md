# Exploration (v2): Nix on Alpine ARM64 (OnePlus 5) — NO-BUILD CONSTRAINT

## Executive Summary

**CONDITIONAL-GO.** Con la restriccion de **zero builds en el telefono**, el enfoque cambia a un modelo hibrido de dos capas:

1. **Alpine `apk`** para todos los binarios del sistema (zsh, git, tmux, neovim, age, etc.) — musl-native, zero Nix
2. **Home Manager desde rog** cross-compilando config + assets para aarch64-linux via QEMU binfmt, enviados por `nix copy`

---

## Three Approaches

### A. Hybrid (Recomendado para v1)
- Alpine apk para system binaries
- HM construido en rog via QEMU binfmt emulation para aarch64-linux
- OpenCode binary desde pre-built GitHub release
- `nix copy` al telefono

**Complejidad**: Media | **Build time**: ~30 min (first build) | **Esfuerzo**: 5-8 files, 2-3 sesiones

### B. Zero-Nix (Fallback)
- Sin Nix en el telefono
- HM config generado en rog, archivos de config rsynced
- OpenCode descargado directo de GitHub
- Sin actualizaciones declarativas

**Complejidad**: Baja | **Build time**: 5 min | **Esfuerzo**: 3-5 files, 1 sesion

### C. Full Cross-Compile (Futuro)
- aarch64-linux en todos los flake outputs
- Cada paquete nixpkgs build en rog para el telefono
- HM completo con activation scripts

**Complejidad**: Alta | **Build time**: Horas | **Esfuerzo**: Demasiado para v1

---

## Arquitectura Recomendada (Hybrid v1)

### Capa 1: Alpine apk (musl-native, zero Nix)
Instalar via `apk add` en el telefono:
- `nix` (el Nix package manager)
- `zsh`, `git`, `tmux`, `neovim`
- `age` (para sops-nix)
- `openssh`, `curl`, `jq`
- Otros runtime deps que HM necesite

### Capa 2: Home Manager desde rog
- `boot.binfmt.emulatedSystems = [ "aarch64-linux" ]` en rog NixOS
- HM modules pura config (sin `home.packages`) se evaluan rapido
- `nix build .#homeConfigurations.glats@oneplus5.activationPackage --system aarch64-linux`
- `nix copy` results al telefono via SSH
- `home-manager switch` en el telefono usando los paths copiados

### Capa 3: OpenCode
- Pre-built ARM64 binary de GitHub releases (ya definido en `pkgs/opencode/default.nix`)
- Si autoPatchelfHook falla (glibc), descargar el tarball directo
- HM module de config (`shared/opencode.nix`) funciona sin cambios

---

## Module Selection

**Include** (pure config o Alpine binary disponible):
```
base.nix, shell.nix (sin nixos-scripts), git.nix, gh.nix,
ssh.nix, shared/shell-aliases.nix, shared/tmux.nix (sin plugins),
shared/opencode-profile.nix, shared/opencode-theme.nix,
neovim.nix (todos deps en Alpine), shared/sops.nix, theme.nix (sin GTK/QT)
```

**Exclude** (desktop/GUI/irrelevant):
```
ghostty, kitty, alacritty, rofi, mate, mate-rog-autostart,
conky-rog, picom, chrome-apps, webcam-rog, remote-desktop
```

**Phased in**:
```
shared/opencode.nix (Phase 2), openfang.nix (later), shell-gpt.nix (optional)
```

---

## Riesgos

| Riesgo | Impacto | Mitigacion |
|--------|---------|------------|
| autoPatchelfHook en musl | Medio — OpenCode patch para glibc | Descargar binary static directo de GitHub |
| Binarios glibc via gcompat | Medio — QEMU-builds producen glibc | Preferir apk para system binaries |
| tmuxPlugins skip | Bajo | Tmux basico de apk, sin plugins nixpkgs |
| nixpkgs binary cache glibc-only | Medio — QEMU builds compilan desde source | Cross-compile from source o usar cache glibc aarch64 |

---

## Workflow Propuesto

1. Agregar `aarch64-linux` a `flake.nix` (packages, formatter, checks)
2. Agregar `boot.binfmt.emulatedSystems` a rog
3. Crear `hosts/oneplus5/home/modules.nix` con seleccion curada
4. Agregar `homeConfigurations.glats@oneplus5` en flake.nix
5. Build + copy al telefono
6. `home-manager switch` en el telefono
7. Agregar OpenCode config
8. Agregar sops-nix
