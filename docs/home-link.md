# Enlace privado mact2→rog: arquitectura y uso diario

**Qué es**: tu Mac corporativo (mact2) navega por tu home server (rog) a través de un enlace privado TLS que el agente de seguridad de endpoint no puede inspeccionar. Esto **no es una herramienta solo para OpenAI**: es un egreso privado de **propósito general** para cualquier aplicación — el TUN cubre automáticamente el tráfico IP que el agente de seguridad libera, y el proxy loopback `127.0.0.1:2080` es una puerta per-app para las categorías que el agente de seguridad intercepta a nivel socket (cualquier app que acepte proxy propio; ver la tabla "Mecanismo genérico" más abajo). OpenCode con OpenAI nativo es el consumidor insignia y el ejemplo trabajado de este doc.

## Arquitectura en 30 segundos

```
                        ┌── TUN (automática: tráfico IP que el agente libera) ──┐
                        │                                                       │
mismas reglas ───────►  │    route rules (RFC1918→direct, agente→direct,        │  ──►  VLESS+WS+TLS
mismo fallback          │    final → urltest auto)                              │       tun.glats.org:443
                        │                                                       │
                        └── mixed 127.0.0.1:2080 (manual: CONNECT sin SNI) ─────┘
                                                     │
                                         Cloudflare → nginx rog → sing-box :4011 → internet
```

**Dos puertas de entrada, un mismo enlace.** El TUN captura solo lo que el agente de seguridad libera; el proxy loopback es la puerta manual para las categorías que el agente de seguridad intercepta (lee el SNI a nivel socket, antes de la capa de rutas — el TUN nunca ve esos flujos).

**Para qué sirve cada puerta:**

| Tráfico | Puerta | ¿Configurás algo? |
|---------|--------|-------------------|
| Genérico (Azure, Apple, la web) | TUN automática | No |
| OpenAI / dominios con ruteo por categoría del agente de seguridad | Proxy loopback `127.0.0.1:2080` (per-app) | Sí, una vez por app |
| LAN / rangos privados (172.16.0.0/24, 10.x) | Ninguna — directo por diseño | No |
| Gestión del agente de seguridad (163.116.0.0/16) | Excluida — directo (si el enlace muere, la telemetría corporativa no se apaga) | No |

**Por qué el proxy del sistema (Settings → Proxies) está descartado**: el agente de seguridad es dueño del diccionario de proxy global del sistema (`scutil --proxy` muestra sus keys) — lo que pongas ahí queda shadoweado. Solo funcionan los overrides per-app. El generador de PAC se implementó y se removió por esto.

## Dominios en macOS: cómo enrutar cada uno

### Cómo resuelve dominios el cliente (mecánica)

1. El TUN captura la conexión y la regla `sniff` extrae el dominio real del TLS ClientHello (SNI) — no depende del DNS del sistema
2. Las route rules comparan ese dominio/IP contra las listas de exclusión, en orden
3. Lo que no matchea ninguna regla va a `final` (urltest auto: enlace ↔ directo). Antes de eso, QUIC (UDP/443) está **bloqueado**: el urltest de sing-box solo sondea TCP y su selección UDP no hace failover — bloquear QUIC obliga a los browsers (HTTP-3) a caer a TCP, el único camino que cruza el enlace y el que tiene failover real
4. El hostname viaja cifrado hasta rog — es rog quien resuelve y conecta (por eso el log del server muestra `[mact2] inbound connection to chatgpt.com:443` con el dominio, no la IP)

### Los dos knobs declarativos (hosts/mact2/default.nix)

```nix
# Dominios que NO deben ir por el enlace (van directo, camino corporativo):
link.directDomains = [ "dominio-interno.falabella.cl" ];

# Rangos IP que NO deben ir por el enlace (ya configurado):
link.directCidrs = [ "163.116.0.0/16" ];   # cloud del agente de seguridad
```

Después del cambio: `nixos-build` + `sudo launchctl kickstart -k system/org.nixos.sing-box` (kickstart exige daemon cargado; si estaba apagado, bootstrap).

**¿Cuándo usar cada uno?**

| Situación | Knob |
|----------|------|
| Un servicio corporativo se rompe porque el enlace cambia su ruta de salida | `link.directDomains` |
| Un rango/subred corporativa (NAC, intranet, VPN) inalcanzable vía enlace | `link.directCidrs` |
| Un dominio bloqueado por el agente de seguridad que querés alcanzar | **Ninguno** — usá la puerta proxy per-app (es dominio-agnóstica, lo cubre todo) |

### Lo que NO funciona en macOS (probado — no pierdas tiempo)

| Truco | Por qué muere |
|-------|---------------|
| `/etc/hosts` apuntando dominios a rog | El agente de seguridad filtra por **valor SNI**, no por IP — el ClientHello con SNI prohibido es interceptado igual |
| Proxy PAC del sistema | El agente shadowea el diccionario de proxy global del sistema |
| Proxy manual en Settings → Network | Ídem — seteás, y el agente re-assertea |
| WireGuard / UDP / SSH directo a rog | Bloqueados por el firewall corporativo in-building |

### Cómo verificar por dónde salió un dominio

Después de tocar el dominio en cuestión, en rog:

```bash
journalctl -u sing-box --since "5 min ago" | grep "\[mact2\]" | grep -i dominio
```

- **Aparece** → fue por el enlace (rog lo resolvió y conectó)
- **No aparece** → fue directo (exclusión activa) o lo interceptó el agente (para dominios con ruteo por categoría sin proxy per-app)

## Comandos día a día (en mact2)

### Prender / apagar / estado del enlace

```bash
# APAGAR (TUN desaparece → Mac 100% corporativo):
sudo launchctl bootout system/org.nixos.sing-box

# PRENDER (solo cuando rog está arriba — el daemon NO autostarta;
# tras un reboot queda registrado pero PARADO → kickstart basta):
sudo launchctl kickstart system/org.nixos.sing-box

# si dice "Could not find service" (fue bootout'eado antes):
sudo launchctl bootstrap system /Library/LaunchDaemons/org.nixos.sing-box.plist
sudo launchctl kickstart system/org.nixos.sing-box

# ESTADO (state = running + pid):
launchctl print system/org.nixos.sing-box | grep -E "state|pid"

# REINICIAR — OBLIGATORIO tras cualquier cambio de config del enlace (rebuild que
# toque sing-box-link.nix), porque launchd no reinicia si el plist no cambió.
# kickstart funciona con el daemon cargado (corriendo o parado); -k mata la
# instancia previa si está corriendo:
sudo launchctl kickstart -k system/org.nixos.sing-box
```

⚠️ Daemon de operación manual (`RunAtLoad=false`, `KeepAlive=false`, verificado contra Apple TN2083: "run purely on demand"): nunca autostarta al boot y si el proceso muere, queda caído — esperado, el camino corporativo funciona sin él. Con `bootstrap` a secas el job queda **registrado pero parado** (sin MachServices no hay "demand" que lo despierte) — por eso PRENDER = `kickstart`. APAGAR sobrevive reboots, switches y crashes; PRENDER hay que re-emitirlo tras cada reboot.

### OpenCode con OpenAI nativo

```bash
opencode-home          # NO usar `opencode` a secas: el wrapper scopea el proxy
                       # al proceso y deja los MCPs hijos limpios.
                       # Si el enlace está apagado, arranca igual (sin proxy).
```

### Browser con enlace (para OpenAI y lo que surja)

```bash
# Edge/Chromium — flag por lanzamiento:
open -a "Microsoft Edge" --args --proxy-server=http://127.0.0.1:2080
```

```text
Firefox — configuración UNA sola vez (persiste en el profile):
Settings → Network Settings → Manual proxy → HTTP 127.0.0.1 puerto 2080
(√ "also use for HTTPS") · No proxy for: localhost, 127.0.0.1
```

**Dominios nuevos bloqueados por el agente de seguridad**: no hay lista que mantener — cualquier dominio que accedas **a través del proxy** ya viaja por el enlace. La puerta per-app es dominio-agnóstica. (Las listas `link.directDomains`/`directCidrs` son para lo contrario: excluir dominios DEL enlace.)

### Mecanismo genérico: apuntar CUALQUIER app al enlace

El proxy del sistema está descartado (el agente de seguridad lo shadowea). Para cualquier app bloqueada, la pregunta es: *"¿esta app acepta que le indique un proxy por su propio mecanismo?"*

| Clase de app | Mecanismo | Persistencia |
|--------------|-----------|--------------|
| **Chromium** (Edge, Chrome, Brave, Arc) | Launch flag `--proxy-server=http://127.0.0.1:2080`, o config file: `defaults write com.microsoft.Edge ProxyMode -string fixed_servers` + `defaults write com.microsoft.Edge ProxyServer -string 127.0.0.1:2080` | Flag: cada lanzamiento · defaults: permanente (⚠️ si IT empuja policies Edge por MDM, las managed ganan) · localhost se excluye del proxy automáticamente (OAuth callback OK) |
| **Firefox / Gecko** | Profile → Manual proxy `127.0.0.1:2080` | Permanente en el profile |
| **CLI** (curl, git, npm, pip…) | Env en la invocación o wrapper: `HTTPS_PROXY=http://127.0.0.1:2080 curl …`, `git -c http.proxy=http://127.0.0.1:2080 clone …` | Per-invocación |
| **OpenCode** | `opencode-home` (wrapper del repo — scopea env + MCPs limpios) | Cero (auto-detecta) |
| **Apps nativas CFNetwork** (Mail, App Store…) | Sin puerta per-app confiable — el dict de proxy lo pisa el agente | — |

**Regla general**: si la app tiene config propia de proxy, apuntala a `127.0.0.1:2080` y todo su tráfico (incluidos dominios bloqueados) viaja por el enlace. Si solo lee el proxy del sistema, no hay nada que hacer sin wrapper. Nunca exportes `HTTP(S)_PROXY` en shell profiles — solo wrappers (los MCPs hijos heredan el env y deben seguir limpios).

### Bootstrap OAuth de un dispositivo (el flujo completo)

Cada dispositivo hace su **propio** login OAuth — no se copian auth.json entre hosts (el seed script quedó obsoleto como mecanismo; es fallback dormido).

```bash
# en el dispositivo, CON el enlace corriendo:
opencode-home auth login       # wrapper: el exchange del token viaja por el enlace
```

1. Copiás la URL que imprime opencode
2. La abrís en un browser **con el proxy configurado** (Edge flag/policy o Firefox profile)
3. Login en auth.openai.com (el agente no ve ese flujo — viaja por el enlace)
4. Redirect a `localhost:1455` → Chromium excluye localhost del proxy → opencode captura el código
5. El exchange del token lo hace el propio opencode **por el enlace** (por eso el wrapper)

⚠️ No corras `opencode auth login` a secas: el exchange del token es un flujo OpenAI-bound que el agente interceptaría sin el proxy env del wrapper.

### Prueba de salud (30 segundos)

```bash
# 1. El enlace trae certificados REALES (no el CA corporativo del agente):
curl -x http://127.0.0.1:2080 -sSIv https://auth.openai.com/ 2>&1 | grep "issuer:"
#    esperado: O=Google Trust Services / Cloudflare
#    mal señal: issuer del CA corporativo (el agente interceptó)

# 2. El enlace completo está activo (TUN capturando):
curl -sS https://ipinfo.io/ip        # → 201.188.187.112 (egres por rog)

# 3. Fallback: si rog está caído, el mismo curl sigue devolviendo TU ip
#    corporativa en ≤30 s y todo sigue navegando — degradación automática.
```

### Teléfono (sing-box Android / SFA)

```bash
# en rog — genera link (QR interactivo) o config JSON para SFA:
sudo bin/device-link phone            # link vless:// + QR (v2rayNG-class)
sudo bin/device-link phone --config   # JSON completo → SFA Local profile
```

El `--config` es el que funciona con SFA (no parsea `vless://`). Importar: Profiles → + → Local → clipboard. El perfil del teléfono usa DNS del sistema (`type: local`) — funciona en cualquier red móvil/WiFi.

## Comandos server (en rog)

```bash
systemctl status sing-box --no-pager        # servicio del server
journalctl -u sing-box -f                   # ver conexiones EN VIVO: [mact2], [phone]
journalctl -u sing-box --since "30 min ago" | grep phone
ss -tln | grep 4011                         # loopback inbound escuchando
```

Cada conexión autenticada aparece con el nombre del dispositivo (`[mact2]`, `[phone]`) — así sabés quién está usando el enlace y qué destinos visita (por dominio, el server resuelve).

## Revocar / rotar dispositivos

La revocación es **autoritativa del server**: cambia qué UUIDs acepta rog; lo que el cliente tenga guardado deja de servir.

> Los UUIDs viven en `secrets/shared/link-uuids.yaml` (sops), con declaraciones `link/uuid_*` — renombrados desde el namespace histórico por el change `naming-hygiene`.

```bash
# ROTAR un dispositivo (nuevo UUID, mismo slot):
sops secrets/shared/link-uuids.yaml         # editar uuid_phone: <nuevo>
git add + commit + push
nixos-build                                  # rog ahora espera el nuevo
sudo bin/device-link phone                   # nuevo link → re-importar en el teléfono

# REVOCAR por completo (ejemplo: phone):
#   1. sacar la entry "phone" del array users (linux/system/services/network/sing-box-link.nix)
#   2. sacar la declaración en hosts/rog/secrets.nix
#   3. sacar la key uuid_phone del sops file
#   4. nixos-build en rog
# mact2 no se entera — cada UUID es independiente.
```

## Fallas conocidas y su significado

| Síntoma | Causa | Acción |
|---------|-------|--------|
| Todo el browsing muere | Daemon ON + rog caído aún no degradó (≤30 s) | Esperar el probe del urltest (intervalo 30 s + corte de conexiones existentes) |
| Página "Aplicación No Permitida" de Falabella en el browser | Estás en el camino corporativo para ese dominio (enlace apagado, o navegador sin proxy) | Prender enlace / usar browser con proxy |
| `issuer:` del CA corporativo en un test | El flujo NO pasó por el proxy loopback | Verificar `--proxy-server` / profile |
| Cambiaste la config del enlace y no aplica | launchd no reinicia si el plist no cambió | `sudo launchctl kickstart -k …` (daemon cargado) o `bootstrap` (descargado) |
| `WARN icmp is not supported by outbound` en logs viejos | Config anterior a la regla ICMP→direct | Ya resuelto; si reaparece post-rebuild, kickstart |

> Lección del incidente 2026-08 (rog caído 2 días): el urltest de sing-box sondea **solo TCP** — la selección UDP quedó clavada al enlace muerto (QUIC/HTTP-3 colgando) mientras TCP degradaba bien a directo. Por eso ahora se bloquea UDP/443 (el QUIC cae a TCP: solo TCP cruza el enlace) y el fallback es ≤30 s con corte de conexiones existentes. Además el urltest lista `direct` primero: sin historial de probes (boot/recién configurado) elige la primera de la lista — el default seguro es el camino corporativo, no un enlace posiblemente caído.

## Dónde vive todo

| Pieza | Archivo |
|-------|---------|
| Cliente macOS (TUN + mixed + launchd + urltest) | `darwin/system/sing-box-link.nix` |
| Server rog (VLESS multi-usuario, :4011) | `linux/system/services/network/sing-box-link.nix` |
| Vhost tun.glats.org (cover page + WS path) | `linux/system/services/web/nginx.nix` |
| Launchers | `bin/opencode-home`, `bin/device-link` (empaquetados en `pkgs/nixos-scripts`) |
| Scrub MCP (hosts agnóstico) | `shared/opencode/runtime-config.nix` |
| Credenciales (2 UUIDs) | `secrets/shared/link-uuids.yaml` (sops; regla específica en `.sops.yaml`; declaraciones `link/uuid_*`) |
| Reglas de exclusión del cliente | `hosts/mact2/default.nix` (`link.directCidrs`, `link.mode`) |
| Change SDD de renombre | `openspec/changes/naming-hygiene/` (el change SDD histórico de esta pila conserva su narrativa original y está pendiente de reubicación fuera del repo) |

## Pendiente (no bloquea el uso diario)

- **OFFICE GATES** — validación dentro del edificio: coexistencia con FortiClient, CrowdStrike, firewall corporativo (WS long-lived), SNI observado = `tun.glats.org` only.
- Test de revocación del teléfono y flip runtime a scoped mode — procedimientos en el change SDD histórico.
- Rollback total = revert de los commits en master (todo es declarativo; los UUIDs sobreviven en sops).
