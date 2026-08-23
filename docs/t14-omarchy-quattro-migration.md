# Guía: Adoptar lo esencial de Omarchy Quattro en t14 (NixOS)

> Estado: propuesta aprobada (scope «Core Quattro»). Estrategia: vendorizar runtime
> upstream + mover el flake completo a `nixos-unstable`.
> Repos afectados: `glats/omarchy-nix` (branch `quattro`) y `nixos-hosts` (este repo).
>
> Investigado el 2026-08-22 contra `basecamp/omarchy@quattro`
> (`2c247e390e357ae0fee3f8565b0c816adb705e6a`, post-release v4.0.0 del 2026-08-14).

---

## 0. Contexto y alcance

Omarchy 4.0 «Quattro» es la reescritura más grande del proyecto: todo el desktop shell
vive en **un solo proceso Quickshell** (`omarchy-shell`). El delta contra el port v3
actual (`glats/omarchy-nix`):

| V3 (fork actual) | Quattro |
|---|---|
| Waybar | Bar dentro de Quickshell (arrastrable a bordes → vertical, doble-click = transparencia, widgets vía `omarchy bar put/move`) |
| Walker | Menú/launcher nativo en el shell, un solo paleta (`SUPER+SPACE`); extensible vía `~/.config/omarchy/extensions/omarchy-menu.jsonc` |
| Mako | Notificaciones como plugin del shell |
| SwayOSD | OSD como plugin (`omarchy osd -i icon -m text -p 50`) |
| hyprlock | Lock screen en el shell (`WlSessionLock` + PAM propio, con fingerprint) |
| hypridle | Idle event-driven dentro del shell (sin polling → CPU ~0 en idle) |
| swaybg | Fondo como overlay del shell + switcher visual (`SUPER+CTRL+SPACE`) |
| polkit-gnome | Agente Polkit tematizado dentro del shell (muestra el comando a autorizar) |
| `hyprland.conf` (hyprlang) | `hyprland.lua` (requiere Hyprland ≥0.55; `.conf` deprecated desde 0.55, «soportado 1–2 releases») |
| iwd standalone + impala | NetworkManager + panel de red del shell |
| Temas base16 (theme-generator.nix) | Un `colors.toml` semántico por tema que genera configs para ~20 apps |

Shell lanzado con `quickshell -n -p "$OMARCHY_PATH/shell"` (un proceso por sesión
gráfica; bar/menú/notificaciones/paneles/lock/polkit son plugins internos).

### Disponibilidad verificada (ago 2026)

| Componente | nixpkgs unstable | Nota |
|---|---|---|
| `hyprland` | 0.56.2 | 26.05 estable trae ~0.54.x (insuficiente para Lua) |
| `quickshell` | 0.3.0 | Arch usa 0.3.1+ (fix: `kill` síncrono en restarts del shell — migrations/1787399318.sh). Posible override puntual |
| Home Manager master | — | `wayland.windowManager.hyprland.configType = "lua"` + `extraLuaFiles` ya mergeados (PR #9307) |

### Qué adoptar y qué no (criterio de fit)

| De Quattro | Decisión | Por qué |
|---|---|---|
| Shell Quickshell (bar, menú, notificaciones, OSD, lock, idle, polkit, fondo) | ADOPTAR | Es el corazón de Quattro; reemplaza 6+ componentes por uno tematizado |
| Hyprland Lua (0.56) | ADOPTAR | hyprlang está deprecated; HM ya genera Lua; migrar ahora evita migrar con urgencia después |
| Idle event-driven del shell | ADOPTAR | Cierra la saga hypridle/mouse-wiggle ya resuelta a favor de upstream |
| NetworkManager | ADOPTAR | Unifica con rog/thinkcentre (ya usan NM); habilita el panel de red del shell |
| Tema `glats` en formato `colors.toml` | ADOPTAR | Un solo archivo genera temas para ~20 apps; jubila el base16-generator |
| `shell.toml` (override estético por máquina) | ADOPTAR | Reemplaza limpiamente los `omarchy.fonts.*` locales de t14 |
| Switchers visuales de tema/fondo | Gratis | Vienen con el shell |
| Foot como terminal default | SKIP | Se usa ghostty; quattro lo sigue tematizando |
| Tensaku/Omawrite/Omacut/Omacalc/Moonlight/dua | LATER | Apps opcionales |
| Selector de agente coding (`SUPER+SHIFT+CTRL+A`) | LATER | opencode ya está integrado a manera propia |
| Herdr, plugins de terceros (`omarchy plugin add`) | LATER | Ecosistema; no bloquea el core |
| Migration runner, ISO/dual-boot, factory reset, first-run provisioning | SKIP | Específico de Arch/instalador; NixOS no lo necesita |

---

## 1. Arquitectura del runtime Quattro (lo que se vendoriza)

### 1.1 Layout instalado en `$out/share/omarchy`

```
share/omarchy/
  default/            # defaults lua de Hyprland (default.hypr.*), apps, fonts, agents skills
  shell/              # el Quickshell shell (QML): entry shell.qml + plugins/
    shell.qml
    Commons/ Ui/ Services/
    services/{PluginRegistry.qml, BarWidgetRegistry.qml}
    plugins/{bar/, menu/, notifications/, osd/, polkit/, background/,
             clipboard/, emojis/, panels/{audio,bluetooth,monitor,network,power,weather}/,
             image-picker/, lock/}
  bin/                # 433 scripts `omarchy-*` (ver §2)
  themes/             # 22 temas: catppuccin(-latte), ethereal, everforest, flexoki-light,
                      # gruvbox, hackerman, kanagawa, last-horizon, lumon, lupine,
                      # matte-black, miasma, nord, osaka-jade, retro-82, ristretto,
                      # rose-pine, solitude, tokyo-night, vantablack, white
  config/             # configs base de apps (foot, ghostty, kitty, alacritty, btop,
                      # chromium, git, lazygit, tmux, wireplumber, obsidian, xournalpp…)
  version
```

NO vendorizar: `install/`, `migrations/`, `test/`, `manual/`, `plans/`, `etc/`,
`.github/` (específicos de Arch/ISO/CI).

### 1.2 Resolución de rutas: `$OMARCHY_PATH` y el bootstrap Lua

Upstream garantiza un solo mecanismo de rutas (su propio AGENTS.md):

- `$OMARCHY_PATH` llega al proceso vía entorno de sesión UWSM.
- `~/.config/hypr/hyprland.lua` (del usuario) hace:
  ```lua
  dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")
  require("default.hypr.omarchy")   -- carga todos los defaults
  ```
- `bootstrap.lua` arma `package.path` con capas en orden:
  `~/.local/state/?.lua` → `~/.config/?.lua` → `$OMARCHY_PATH/?.lua`.
  Los defaults del paquete pueden mejorar sin tocar tu `~/.config`.
- `default/hypr/envs.lua` re-exporta al entorno de Hyprland:
  ```lua
  hl.env("OMARCHY_PATH", paths.omarchy_path)
  -- y antepone $OMARCHY_PATH/bin al PATH del compositor:
  ```

**Consecuencia para Nix:** basta con exportar
`environment.sessionVariables.OMARCHY_PATH = "${omarchy-runtime}/share/omarchy";`
a nivel de sistema — greeter, UWSM y Hyprland lo heredan, y `envs.lua` hace el resto
(incluido el PATH de los scripts `bin/`). No hace falta tocar el PATH del sistema.

Otros envs que `envs.lua` fija (no duplicar en Nix): `XCURSOR_SIZE/HYPRCURSOR_SIZE=24`,
backends Wayland (`GDK_BACKEND`, `QT_QPA_PLATFORM*`, `MOZ_ENABLE_WAYLAND`,
`ELECTRON_OZONE_PLATFORM_HINT`), `XCOMPOSEFILE=~/.XCompose`,
`xwayland.force_zero_scaling=true`.

⚠️ Interacción con t14: Edge corre forzado a X11 vía wrapper propio — verificar que
`ELECTRON_OZONE_PLATFORM_HINT=wayland` no pelee con ese wrapper (el wrapper usa flags
explícitos, deberían ganar).

### 1.3 Autostart real (lo que Nix debe satisfacer)

```lua
-- default/hypr/autostart.lua
hl.on("hyprland.start", function()
  hl.exec_cmd("systemctl --user import-environment $(env | cut -d'=' -f 1)")
  hl.exec_cmd("dbus-update-activation-environment --systemd --all")
  hl.exec_cmd("omarchy-launch-shell")                    -- ← el shell
  hl.exec_cmd("omarchy-provision-first-run")             -- ← NO-OP en Nix (installer)
  hl.exec_cmd("omarchy-powerprofiles-init")
  hl.exec_cmd(o.launch("omarchy-hyprland-monitor-watch"))
  hl.exec_cmd(o.launch("udiskie --automount --no-notify --no-tray"))
  hl.exec_cmd("sleep 2 && omarchy-hook post-boot")       -- hooks opcionales
end)
```

Notas de port:
- `omarchy-launch-shell` además tee-ea logs al journal (systemd-cat) — útil en t14.
- `omarchy-provision-first-run`: stub vacío o exclusión (feature de ISO).
- `udiskie`: agregar el paquete si no está.
- `omarchy-hook post-boot`: sistema de hooks en `~/.config/omarchy/hooks/` — puede
  reemplazar partes de `omarchy-post-boot.nix` local (LATER).

---

## 2. Inventario `bin/` (433 scripts) y estrategia de auditoría

Enfoque recomendado: **whitelist por categoría**, no script-por-script. Categorías
observadas upstream:

| Categoría (prefijo) | Ejemplos | Veredicto para Nix |
|---|---|---|
| `omarchy-shell*`, `omarchy-launch-*`, `omarchy-restart-*`, `omarchy-refresh-*` | launch-shell, launch-or-focus, restart-shell, refresh-shell | ✅ INCLUIR (core UX) |
| `omarchy-audio-*`, `omarchy-brightness-*`, `omarchy-bluetooth-*`, `omarchy-network-*`, `omarchy-dns` | output-switch, display-ddc, network-qr, speedtest | ✅ INCLUIR (alimentan paneles del shell; deps: wpctl/wireplumber, brightnessctl, ddcutil, nmcli) |
| `omarchy-capture-*`, `omarchy-clipboard-*`, `omarchy-transcode*` | screenshot, screenrecording(+webcam), capture-qr | ✅ INCLUIR (grim/slurp/wf-recorder/ffmpeg/zbar) |
| `omarchy-theme-*` | theme-set, bg-set/switcher, theme-refresh | ✅ INCLUIR (deps del generador de temas; auditar referencias a pacman dentro) |
| `omarchy-toggle-*`, `omarchy-system-*`, `omarchy-powerprofiles-*`, `omarchy-monitor-state` | toggle-idle, system-lock/lid-close/sleep-lock | ✅ INCLUIR |
| `omarchy-menu*`, `omarchy-notification-*`, `omarchy-osd` | menu-select, notification-send | ✅ INCLUIR |
| `omarchy-hw-*`, `omarchy-apply-*`, `omarchy-drive-*` | hw-fingerprint, hw-clamshell, apply-lock | ⚠️ SELECTIVO — revisar deps (algunos tocan mkinitcpio/mkinitcpio.conf) |
| `omarchy-install-*`, `omarchy-remove-*`, `omarchy-tui-*` | install-app, install-gaming-steam | ❌ EXCLUIR (gestores de paquetes pacman/paru; en Nix eso lo hacen los módulos) |
| `omarchy-pkg-*`, `omarchy-update*`, `omarchy-migrate*`, `omarchy-upgrade-to-quattro`, `omarchy-channel-*`, `omarchy-reinstall*` | pkg-present, update-system-pkgs | ❌ EXCLUIR (100% pacman/AUR) |
| `omarchy-provision-*`, `omarchy-setup-*`, `omarchy-snapshot`, `omarchy-system-factory-reset*` | provision-first-run | ❌ EXCLUIR (instalador/ISO) |
| `omarchy-plymouth-*`, `omarchy-refresh-{limine,sddm,pacman}`, `omarchy-dev-link/unlink` | | ❌ EXCLUIR (boot splash Arch, dev-mode upstream) |
| `omarchy-webapp-*`, `omarchy-windows-vm`, `omarchy-voxtype-*`, `omarchy-tailscale-*`, `omarchy-agent*`, `omarchy-default-agent` | | ⏭️ LATER (features opt-in; se agregan si interesan) |

Regla práctica: cada script incluido pasa por `makeWrapper` con las deps reales en
PATH. Los excluidos simplemente no se copian a `$out/share/omarchy/bin` — el menú del
shell degrada gracefully las entradas cuyo binario falte (verificar en smoke test).

---

## 3. Configuración del shell: `shell.json`, `shell.toml`, menú JSONC

Tres superficies de configuración de usuario (todas en `~/.config/omarchy/`):

**`shell.json`** — bar, widgets e idle. Default upstream:

```json
{
  "version": 1,
  "idle": { "screensaver": 150, "lock": 300 },
  "bar": {
    "position": "top",
    "transparent": false,
    "centerAnchor": "omarchy.clock",
    "layout": {
      "left":   [ { "id": "omarchy.menu" }, { "id": "omarchy.workspaces" } ],
      "center": [ { "id": "omarchy.indicators" }, { "id": "omarchy.clock", "format": "dddd HH:mm" },
                  { "id": "omarchy.keyboard-layout" }, { "id": "omarchy.weather" }, { "id": "omarchy.system-update" } ],
      "right":  [ { "id": "omarchy.tray" }, { "id": "omarchy.agents" }, { "id": "omarchy.bluetooth" },
                  { "id": "omarchy.network" }, { "id": "omarchy.audio" }, { "id": "omarchy.monitor" },
                  { "id": "omarchy.power" } ]
    }
  },
  "plugins": []
}
```

→ Port: opción HM nueva `omarchy.shell.settings` (attrset → JSON). Para t14 arrancar
con el default y ajustar solo: quitar `system-update` (NixOS no usa ese flujo) y
evaluar `keyboard-layout` (t14 alterna es/latam — el widget muestra código xkb).

**`shell.toml`** — override estético por máquina, *mergeado sobre el tema activo* y
watcheado (re-flow en vivo). Aquí van las fuentes que hoy se fuerzan en
`hosts/t14/home/omarchy.nix` (`Source Sans 3 Semibold` en la bar, `CaskaydiaCove Nerd
Font` en terminales):

```toml
# ~/.config/omarchy/shell.toml (ejemplo t14)
[font]
# familia/tamaño del shell — sobrevive a cambios de tema
```

**`extensions/omarchy-menu.jsonc`** — entradas propias del menú (JSONC comentable).
Reemplazo natural de webapps/launchers custom si se quieren agregar después.

Plugins de terceros: repos git con `manifest.json`; se instalan a
`~/.config/omarchy/plugins/` con `omarchy plugin add <repo>` (LATER).

---

## 4. Sistema de temas: `colors.toml`

Un tema = directorio cuyo archivo esencial es `colors.toml` (paleta semántica). De ahí
el shell/generadores producen configs para foot, alacritty, ghostty, kitty, btop,
chromium, hyprland, neovim, helix, vscode, obsidian y todas las superficies del shell.

Schema real (tomado de `themes/tokyo-night/colors.toml`):

```toml
mode = "dark"

accent = "#7aa2f7"
selection = "#292e42"
muted = "#414868"

background = "#1a1b26"
dark_background = "#13141c"
darker_background = "#0e0e14"
lighter_background = "#24283b"

foreground = "#a9b1d6"
dark_foreground = "#565f89"
light_foreground = "#b4bee6"
bright_foreground = "#c0caf5"

red = "#f7768e"
yellow = "#e0af68"
orange = "#eb927b"
green = "#9ece6a"
cyan = "#449dab"
blue = "#7aa2f7"
magenta = "#ad8ee6"
brown = "#75493d"

bright_red = "#ff7a93"
bright_yellow = "#ff9e64"
bright_green = "#b9f27c"
bright_cyan = "#0db9d7"
bright_blue = "#7da6ff"
bright_magenta = "#bb9af7"
```

Apps no soportadas: drop un `[appname].tpl` en `~/.config/omarchy/themed/` usando
plantillas `{{ accent }}`, `{{ color0 }}`–`{{ color15 }}`.

**Port del tema glats:** mapear la paleta base16 actual
(`modules/custom-base16-schemes.nix`) a este schema. Correspondencia aproximada:
base16 `base00`→`background`, `base01`→`lighter_background`, `base02`→`selection`,
`base03`→`muted`/`dark_foreground`, `base04`→`light_foreground`, `base05`→`foreground`,
`base06`→`bright_foreground`, `base07`+, y `base08`–`base0F` → colores nombrados
(red/green/yellow/blue/magenta/cyan + bright_*). Deploy recomendado: HM a
`~/.config/omarchy/themes/glats/` (la paleta vive en TU repo, no compite con upstream
al sincronizar). Jubilar `theme-generator.nix` + `custom-base16-schemes.nix`
conservando solo lo que el generador de quattro no cubra (GTK Materia override,
Papirus icons — esos siguen siendo locales de t14).

---

## 5. Lock screen y PAM

El shell usa dos servicios PAM propios (creados hoy por `bin/omarchy-apply-lock`):

- `/etc/pam.d/omarchy-lock-password` — auth por contraseña. Contenido upstream:
  ```
  #%PAM-1.0
  auth required pam_faillock.so preauth silent deny=10 unlock_time=120
  -auth [success=2 default=ignore] pam_systemd_home.so
  ...
  ```
- `/etc/pam.d/omarchy-lock-fingerprint` — solo si hay huellas enroladas (t14 tiene
  lector: upstream ofrece enrollment on first run cuando detecta reader).

→ Port NixOS (`modules/nixos/shell-pam.nix`):
```nix
security.pam.services."omarchy-lock-password".text = /* contenido upstream */;
security.pam.services."omarchy-lock-fingerprint".text = lib.mkIf fingerprint /* ... */;
```
Además: el agente Polkit del shell reemplaza cualquier agente previo (no deployar
polkit-gnome). Y el lid-close flow usa inhibidor de logind con
`InhibitDelayMaxSec` elevado (drop-in shipped upstream) — portar ese drop-in de
`logind` para que el lock pre-suspend tenga tiempo de completar.

---

## 6. Hyprland Lua

### 6.1 Layout de configuración upstream

`default/hypr/` contiene los módulos default: `omarchy.lua` (orquestador),
`bootstrap.lua`, `paths.lua`, `envs.lua`, `helpers.lua`, `require_all.lua`,
`require_optional.lua`, `input.lua`, `looknfeel.lua`, `windows.lua`,
`workspace-layouts.lua`, `qconsole.lua`, `nvidia.lua`, `apps.lua` + `apps/`,
`bindings.lua` + `bindings/`, `autostart.lua`, `toggles.lua` + `toggles/`.

El `hyprland.lua` del usuario (generado) encadena:

```lua
dofile("$OMARCHY_PATH/default/hypr/bootstrap.lua")
-- omarchy_default_bindings = false          <- flags opcionales
-- omarchy_preinstalled_bindings = false
require("default.hypr.omarchy")              -- defaults del paquete
require("hypr.monitors")                     -- overrides del usuario
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")
require("default.hypr.toggles")              -- flags dinámicos
```

Los defaults usan la API expresiva: `o.bind("SUPER + SHIFT + W", "Omawrite",
{ launch = "omawrite" })`, `o.window("qemu", { workspace = "5" })`.

### 6.2 Generación vía Home Manager (`configType = "lua"`)

HM master convierte `settings` (Nix) → llamadas `hl.(...)`:

```nix
wayland.windowManager.hyprland = {
  configType = "lua";
  settings = {
    mod = { _var = "SUPER"; };                       # local SUPER = "SUPER"
    bind = [{
      _args = [
        (lib.generators.mkLuaInline ''mod .. " + Q"'')
        (lib.generators.mkLuaInline ''hl.dsp.window.close()'' )
      ];
    }];
  };
  # archivos .lua sueltos con require() automático:
  extraLuaFiles = {
    "monitors"   = { content = ./hypr/monitors.lua; autoLoad = true; };
    "input"      = { content = ./hypr/input.lua; autoLoad = true; };
  };
};
```

Gotchas conocidos (de PR #9307 e issue #9341):
- `exec-once` **no existe** en Lua → usar `hl.on("hyprland.start", function()
  hl.exec_cmd("...") end)`. Con `stateVersion` 26.05 HM ya emite esa forma.
- Valores crudos de Lua requieren `lib.generators.mkLuaInline`; strings planas se
  emiten entrecomilladas.
- HM escribe `.luarc.json` con los stubs de `${hyprland}/share/hypr/stubs` (LSP gratis).

### 6.3 Mapeo de archivos t14

| Hoy (hyprlang vía HM `settings`) | Destino |
|---|---|
| `hosts/t14/home/hypr/monitors.nix` | `hypr/monitors.lua` vía `extraLuaFiles` (HDM gestiona dock/undock; el static queda como fallback) |
| `hosts/t14/home/hypr/input.nix` | `hypr/input.lua` (incluye kb_options grp:alt_shift_toggle) |
| `hosts/t14/home/hypr/looknfeel.nix` | `hypr/looknfeel.lua` (border 2px, gaps, animaciones) |
| `hosts/t14/home/hypr/groups.nix` | `hypr/groups.lua` (changelgroupactive, movegroupwindow…) |
| `hosts/t14/home/hypr/hyprlock.nix` | ❌ ELIMINAR (lock = shell) |
| `hosts/t14/home/hypr/hyprsunset.nix` | conservar (existe `config/hypr/hyprsunset.conf` en quattro) |
| binds wayvnc/recovery en `omarchy.nix` | convertir a `settings.bind` formato `_args` o líneas en un `bindings-extra.lua` |
| `$browser`/`$webapp` mkForce (Edge) | variables → forma Lua (`hl.config` / locals); verificar cómo HM emite variables con `_var` |

⚠️ **Greeter (regreet)**: su Hyprland efímero puede seguir leyendo `.conf` esta pasada
(deprecated ≠ roto en 0.56; solo warning). Migrarlo es trabajo posterior.
⚠️ **HDM (hyprdynamicmonitors)**: sus perfiles hoy son `.conf` cargados por source.
Investigar si soporta emitir/cargar Lua o si funciona el mixto (HDM aplica configs con
`hyprctl` — probablemente siga operativo; validar con `hyprctl configerrors` tras
dock/undock).

---

## 7. NetworkManager

Quattro reemplaza iwd/impala/bluetui/wiremix por NM + paneles del shell. El panel da:
ping, throughput en vivo, packet loss, speed test, selección de DNS, QR de Wi-Fi,
banda 2.4/5 GHz, redes 802.1X empresariales; bluetooth con pairing/forget por dispositivo.

Port t14:
- `omarchy.wifi.backend`: `"standalone-iwd"` → `"networkmanager"` (habilita
  `networking.networkmanager.enable`; DNS sigue por systemd-resolved).
- Remover restos iwd/impala de t14. El viejo comentario «NM ignora wlan0» dejaba de
  aplicar: era porque iwd poseía la interfaz.
- Docker/bridge sin cambio esperado (rog ya opera así con NM).

---

## 8. Atajos nuevos de Quattro (referencia rápida)

| Atajo | Acción |
|---|---|
| `SUPER+SPACE` | Menú Omarchy (paleta única: apps + comandos, fuzzy/acrónimos, extensible JSONC) |
| `SUPER+ALT+SPACE` | Launcher solo-apps |
| `SUPER+CTRL+1..9` | Abrir paneles del lado derecho de la bar (numeración automática) |
| `SUPER+CTRL+A` / `W` | Panel de Audio / Red |
| `SUPER+CTRL+SPACE` | Carrusel de fondos |
| `SUPER+SHIFT+CTRL+SPACE` | Carrusel de temas (previews en vivo) |
| `SUPER+SHIFT+CTRL+A` | Coding agent elegido (LATER) |
| `SUPER+SHIFT+W` / `SUPER+CTRL+Q` | Omawrite / Omacalc (LATER) |
| `SUPER+ALT+[ / ]` | Tweak webcam overlay en grabaciones |
| `SUPER+HOME` / `SUPER+ALT+HOME` | Save/restore anchos de ventana por app/workspace |
| Ambos Shift | Toggle Caps Lock |
| Arrastrar bar vacía / doble-click | Mover borde (vertical) / transparencia |

Barra: widgets con `omarchy bar put/move`; captura de región manejada por teclado
(`RETURN` ventana, `CTRL+RETURN` display completo, `TAB`/flechas mueven selección);
QR capture decodifica a clipboard marcado sensible.

---

## 9. Plan por fases

### Fase 0 — Base unstable *(repo: nixos-hosts)*

1. `flake.nix`: input `nixpkgs.url` → `"github:NixOS/nixpkgs/nixos-unstable"`;
   `nix flake update nixpkgs home-manager`.
2. Verificar: `nix eval nixpkgs#hyprland.version` (≥0.56) y
   `nix eval nixpkgs#quickshell.version` (≥0.3; anotar si <0.3.1 → override en F2).
3. Gate: build de t14, rog, thinkcentre (+ darwin mact2) y `nix flake check --no-build`.
   Si algo rompe, arreglar aquí antes de continuar.
4. Commit: `chore(flake): move nixpkgs to nixos-unstable` (standalone, reversible).

### Fase 1 — Paquete `omarchy-runtime` *(repo: glats/omarchy-nix, branch `quattro`)*

1. `packages/omarchy-runtime/default.nix`: `fetchFromGitHub basecamp/omarchy @ <tag v4.0.x>`
   → instalar `default/ shell/ bin/(whitelist §2) themes/ config/ version` a
   `$out/share/omarchy`.
2. Auditoría según tabla §2; `makeWrapper` por script con deps reales (jq, curl,
   playerctl, brightnessctl, ddcutil, grim, slurp, wf-recorder, ffmpeg, zbar, udiskie,
   gum…). Stub vacío para `omarchy-provision-first-run`.
3. Exponer `packages.x86_64-linux.omarchy-runtime`; gate:
   ```bash
   nix build omarchy-nix#packages.x86_64-linux.omarchy-runtime
   ls result/share/omarchy/{shell,default,bin,themes}
   ```
4. Commit: `feat(runtime): vendor omarchy quattro runtime`.

### Fase 2 — Módulo `omarchy-shell` + jubilación stack v3 *(glats/omarchy-nix)*

1. HM `modules/home-manager/omarchy-shell.nix`: `programs.quickshell`, deploy de
   `~/.config/omarchy/shell.json` desde `omarchy.shell.settings`, autostart cableado en F3.
2. NixOS `modules/nixos/shell-pam.nix`: servicios PAM §5 + drop-in logind
   `InhibitDelayMaxSec`; asegurar polkit daemon presente (el agente es del shell).
3. Eliminar módulos v3 y sus imports: `waybar`, `walker`(+`walker-theme/`), `mako`,
   `swayosd`, `hyprlock`, `hypridle`, `swaybg`, `hyprpaper`.
4. Conservar: terminales, btop, fcitx5, direnv/zsh/starship, desktop-entries, xdph,
   wayvnc, greeter, battery-monitor (re-evaluar: el shell ya reporta batería).
5. Gate: closure sin waybar/walker/mako:
   `nix path-info -r result | grep -E 'waybar|walker|mako'` → vacío.
6. Commit: `feat(shell)! replace waybar/walker/mako/lock stack with omarchy-shell`.

### Fase 3 — Hyprland Lua *(ambos repos)*

1. omarchy-nix: `configType = "lua"` (mkDefault) + defaults como `.lua` espejando §6.1;
   autostart §1.3 incluye `omarchy-launch-shell`.
2. t14: conversión según tabla §6.3; eliminar `hypr/hyprlock.nix`.
3. Investigar HDM↔Lua y validar regreet (queda hyprlang).
4. Gate: `hyprctl configerrors` limpio; `hyprctl binds` correcto; dock/undock con HDM ok.
5. Commit: `feat(hyprland)! convert configuration to lua (quattro layout)`.

### Fase 4 — NetworkManager *(ambos)*

1. omarchy-nix: `wifi.backend` gana `"networkmanager"`; quitar impala condicional.
2. t14: `omarchy-config.nix` cambia backend; remover restos iwd.
3. Gate manual: `nmcli device status` (wlan0 managed/connected), `resolvectl status`.
4. Commit: `feat(network)!: switch t14 wifi backend to NetworkManager`.

### Fase 5 — Tema glats *(glats/omarchy-nix)*

1. Port paleta a `colors.toml` (§4) → deploy HM a `~/.config/omarchy/themes/glats/`
   (+ backgrounds propios si quiere carrusel de fondos glats).
2. Jubilar/reducir `theme-generator.nix` + `custom-base16-schemes.nix`.
3. Fuentes → `~/.config/omarchy/shell.toml` (elimina ~6 overrides `omarchy.fonts.*`).
4. Gate visual: `SUPER+SHIFT+CTRL+SPACE` muestra glats; btop/ghostty/nvim tematizan.
5. Commit: `feat(theme): port glats palette to quattro colors.toml`.

### Fase 6 — Integración final *(nixos-hosts)*

1. `nix flake update omarchy-nix`.
2. Limpieza `hosts/t14/home/omarchy.nix`:
   - ELIMINAR: systemd unit Waybar (~96–120), `omarchy.fonts.{waybar,mako,swayosd,rofi}`
     (→ shell.toml), refs a walker en comentarios.
   - REVISAR: `mouse-wiggle.nix` (idle del shell), `rotate_on_start` (¿sobrevive la
     opción?), `battery-monitor`, `omarchy-post-boot` vs hooks quattro.
   - CONSERVAR: Edge overrides, teams config, gtk.css CSD fix, HDM, wayvnc,
     kb-toggle/kb-layout scripts, GTK Materia/Papirus/Qt.
3. `environment.sessionVariables.OMARCHY_PATH = "${pkgs.omarchy-runtime}/share/omarchy";`
4. Gates: `format-nix && nix flake check --no-build`; build completo t14.
5. Checklist manual post-switch (rollback = generación anterior):
   - [ ] Bar visible/arrastrable; widgets correctos
   - [ ] `SUPER+SPACE` menú lanza apps
   - [ ] Notificaciones en el shell
   - [ ] Lock: contraseña PAM + fingerprint
   - [ ] Idle suspende/lockea según `shell.json`
   - [ ] WiFi conecta; panel de red funcional
   - [ ] Wallpaper persistente entre sesiones
   - [ ] VNC sesión+greeter ok; Teams/Edge/ghostty con tema glats
   - [ ] `omarchy-shell idle status` responde; logs en journal

---

## 10. Estrategia de commits

```
F0 (nixos-hosts)      -> 1 commit standalone, verificable
F1..F5 (omarchy-nix)  -> branch `quattro`, 1 PR/commit por fase, encadenados
F6 (nixos-hosts)      -> bump + cleanup al final, cuando omarchy-nix#main tenga todo
```

Cada fase deja el sistema construible; el único punto de no-retorno es el `switch`
en t14 (protegido por generaciones).

---

## 11. Riesgos abiertos

1. **Quickshell 0.3.0 (unstable) vs 0.3.1+ de Arch** — fix de restart síncrono;
   posible override/pin puntual.
2. **HDM ↔ Lua** — sus perfiles `.conf`: validar interop en sesión Lua.
3. **Scripts bin/ con deps Arch** — alcance exacto sale de la auditoría F1 (§2 acota
   a ~½ del inventario).
4. **regreet** — permanece hyprlang temporalmente (aceptable).
5. **Edge/X11 wrapper** vs `ELECTRON_OZONE_PLATFORM_HINT=wayland` global — probar.
6. **Menú degrade graceful** — verificar comportamiento ante bins excluidos.

---

## 12. Referencias

- Release notes v4.0.0: https://github.com/basecamp/omarchy/releases/tag/v4.0.0
- PR Quattro (descripción exhaustiva): https://github.com/basecamp/omarchy/pull/6231
- Branch quattro: https://github.com/basecamp/omarchy/tree/quattro
  (`shell/README.md`, `shell/plugins/README.md`, `default/hypr/*`, `themes/*/colors.toml`,
  `config/omarchy/shell.json`)
- Hyprland Lua: https://hypr.land/news/26_lua/ · https://wiki.hypr.land/Configuring/Start/
- HM Lua support: https://github.com/nix-community/home-manager/pull/9307
  (gotcha exec-once: issue #9341)
- Análisis de arquitectura: https://shaunli.com/blog/20-omarchy-4-quattro-architecture-study/
