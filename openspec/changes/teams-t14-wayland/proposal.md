# Propuesta: teams-t14-wayland

## Intención

Instalar Microsoft Teams (`teams-for-linux`) en el host NixOS t14 con soporte completo de Wayland, cámara, micrófono y audio. El paquete `teams-for-linux` (IsmaelMartinez, v2.7.13 en nixpkgs unstable) es el mismo fork que usa AUR — confirmado como la opción canónica para Linux.

## Alcance

### Dentro del alcance
- Agregar `teams-for-linux` como paquete exclusivo del host t14
- Establecer `NIXOS_OZONE_WL=1` como variable de entorno global en t14 para que el wrapper de nixpkgs active flags de Wayland
- Habilitar módulo de cámara (`v4l2` kernel + pipewire camera bridge) en t14
- Configurar `~/.config/teams-for-linux/config.json` con optimizaciones Wayland:
  - `disableGpuAutoOff: true` (requerido para cámara)
  - `enableWebRTCPipeWireCapturer` + `WebRtcPipeWireCamera` features
  - `disableHardwareMediaKeyHandling: true` (no implementado en Hyprland)
- Notificaciones vía Electron (más confiables que system notifications en Hyprland)

### Fuera del alcance
- Instalación en otros hosts (rog, thinkcentre, mact2)
- Soporte de estado idle/away (limitación conocida de Chromium en Hyprland)
- Actualización del paquete a v2.13.0 (gap de nixpkgs; documentar como limitación conocida)

## Capacidades

### Nuevas capacidades
- `teams-wayland-support`: Teams for Linux funcionando nativamente en Wayland con soporte completo de medios (cámara, micrófono, audio, screen sharing)

### Capacidades modificadas
- Ninguna

## Enfoque

1. **Paquete**: Agregar `pkgs.teams-for-linux` en `hosts/t14/home/omarchy.nix` dentro de `home.packages`
2. **Variable de entorno**: Agregar `NIXOS_OZONE_WL = "1"` en `environment.variables` dentro de `hosts/t14/default.nix` (mismo patrón que `modules/base/users.nix:52`)
3. **Cámara**: Agregar `boot.kernelModules = [ "v4l2loopback" ]` y habilitar pipewire camera en `hosts/t14/default.nix`
4. **Configuración de Teams**: Crear `config.json` via `xdg.configFile` en `hosts/t14/home/omarchy.nix` (mismo patrón que `mpv/mpv.conf` en línea 288)
5. **Verificación**: Probar cámara con `v4l2-ctl --list-devices`, micrófono con `pactl list sources`

## Áreas afectadas

| Área | Impacto | Descripción |
|------|---------|-------------|
| `hosts/t14/default.nix` | Modificado | `NIXOS_OZONE_WL` env var + módulo de cámara |
| `hosts/t14/home/omarchy.nix` | Modificado | Paquete `teams-for-linux` + `config.json` |

## Riesgos

| Riesgo | Probabilidad | Mitigación |
|--------|-------------|------------|
| v2.7.13 carece de correcciones críticas de Wayland presentes en v2.13.0 | Media | Documentar como limitación conocida; monitorear actualización en nixpkgs |
| PipeWire camera bridge no funcional con hardware AMD | Baja | Probar `v4l2-ctl --list-devices` post-build; pipewire + wireplumber ya presentes vía Omarchy |
| Idle/away roto (Chromium en Hyprland) | Alta | Documentar como limitación conocida; no bloquea funcionalidad core |

## Plan de rollback

Revertir los cambios en `hosts/t14/default.nix` y `hosts/t14/home/omarchy.nix`, luego ejecutar `nixos-build`. Las variables de entorno y módulo de cámara agregados no causan efectos secundarios permanentes si se desinstala el paquete.

## Dependencias

- PipeWire + WirePlumber (ya presente vía Omarchy)
- xdg-desktop-portal-hyprland (ya presente vía Omarchy)
- Cámara USB funcional conectada al hardware t14

## Criterios de éxito

- [ ] `teams-for-linux` aparece en el launcher y se ejecuta en Wayland nativo (`echo $NIXOS_OZONE_WL` devuelve `1`)
- [ ] Cámara disponible en Teams (probar con reunión de prueba)
- [ ] Micrófono captura audio (probar con grabación en Teams)
- [ ] Audio bidireccional funcional (altavoces + micrófono)
- [ ] Screen sharing funciona vía PipeWire + portal
- [ ] `nix flake check --no-build` pasa para todos los hosts
