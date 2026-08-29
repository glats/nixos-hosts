# Túnel mact2→rog: arquitectura y uso diario

**Qué es**: tu Mac corporativo (mact2) navega por tu home server (rog) a través de un túnel TLS que Netskope no puede inspeccionar. Esto **no es una herramienta solo para OpenAI**: es un egreso privado de **propósito general** para cualquier aplicación — el TUN cubre automáticamente el tráfico IP que Netskope libera, y el proxy loopback `127.0.0.1:2080` es una puerta per-app para lo que Netskope secuestra (cualquier app que acepte proxy propio; ver la tabla "Mecanismo genérico" más abajo). OpenCode con OpenAI nativo es el consumidor insignia y el ejemplo trabajado de este doc. El cambio SDD completo vive en `openspec/changes/mact2-openai-tls-tunnel-via-rog/`.

## Arquitectura en 30 segundos

```
                        ┌── TUN (automática: tráfico IP que Netskope libera) ──┐
                        │                                                      │
mismas reglas ───────►  │    route rules (RFC1918→direct, Netskope→direct,     │  ──►  VLESS+WS+TLS
mismo fallback          │    final → urltest auto)                             │       tun.glats.org:443
                        │                                                      │
                        └── mixed 127.0.0.1:2080 (manual: CONNECT sin SNI) ────┘
                                                    │
                                        Cloudflare → nginx rog → sing-box :4011 → internet
```

**Dos puertas de entrada, un mismo túnel.** El TUN captura solo lo que Netskope libera; el proxy loopback es la puerta manual para lo que Netskope secuestra (lee el SNI a nivel socket, antes de la capa de rutas — el TUN nunca ve esos flujos).

**Para qué sirve cada puerta:**

| Tráfico | Puerta | ¿Configurás algo? |
|---------|--------|-------------------|
| Genérico (Azure, Apple, la web) | TUN automática | No |
| OpenAI / dominios steereados por Netskope | Proxy loopback `127.0.0.1:2080` (per-app) | Sí, una vez por app |
| LAN / rangos privados (172.16.0.0/24, 10.x) | Ninguna — directo por diseño | No |
| Gestión Netskope (163.116.0.0/16) | Excluida — directo (si el túnel muere, la telemetría corporativa no se apaga) | No |

**Por qué el proxy del sistema (Settings → Proxies) está descartado**: Netskope es dueño del diccionario de proxy global del sistema (`scutil --proxy` muestra sus keys) — lo que pongas ahí queda shadoweado. Solo funcionan los overrides per-app. El generador de PAC se implementó y se removió por esto (evidencia en `home-evidence.md`, FAIL G12 y design.md addendum 2026-08-29).

## Dominios en macOS: cómo enrutar cada uno

### Cómo resuelve dominios el cliente (mecánica)

1. El TUN captura la conexión y la regla `sniff` extrae el dominio real del TLS ClientHello (SNI) — no depende del DNS del sistema
2. Las route rules comparan ese dominio/IP contra las listas de exclusión, en orden
3. Lo que no matchea ninguna regla va a `final` (urltest auto: túnel ↔ directo)
4. El hostname viaja cifrado hasta rog — es rog quien resuelve y conecta (por eso el log del server muestra `[mact2] inbound connection to chatgpt.com:443` con el dominio, no la IP)

### Los dos knobs declarativos (hosts/mact2/default.nix)

```nix
# Dominios que NO deben ir por el túnel (van directo, camino corporativo):
tunnel.directDomains = [ "dominio-interno.falabella.cl" ];

# Rangos IP que NO deben ir por el túnel (ya configurado):
tunnel.directCidrs = [ "163.116.0.0/16" ];   # Netskope cloud
```

Después del cambio: `nixos-build` + `sudo launchctl kickstart -k system/org.nixos.sing-box-tunnel`.

**¿Cuándo usar cada uno?**

| Situación | Knob |
|----------|------|
| Un servicio corporativo se rompe porque el túnel cambia su ruta de salida | `tunnel.directDomains` |
| Un rango/subred corporativa (NAC, intranet, VPN) inalcanzable vía túnel | `tunnel.directCidrs` |
| Un dominio bloqueado por Netskope que querés alcanzar | **Ninguno** — usá la puerta proxy per-app (es dominio-agnóstica, lo cubre todo) |

### Lo que NO funciona en macOS (probado — no pierdas tiempo)

| Truco | Por qué muere |
|-------|---------------|
| `/etc/hosts` apuntando dominios a rog | Netskope filtra por **valor SNI**, no por IP — el ClientHello con SNI prohibido es interceptado igual (probe A1) |
| Proxy PAC del sistema | Netskope shadowea el diccionario de proxy global (`BypassAllowed: 0`) |
| Proxy manual en Settings → Network | Ídem — seteás, y Netskope re-assertea |
| WireGuard / UDP / SSH directo a rog | Bloqueados por el firewall corporativo in-building |

### Cómo verificar por dónde salió un dominio

Después de tocar el dominio en cuestión, en rog:

```bash
journalctl -u sing-box --since "5 min ago" | grep "\[mact2\]" | grep -i dominio
```

- **Aparece** → fue por el túnel (rog lo resolvió y conectó)
- **No aparece** → fue directo (exclusión activa) o lo interceptó Netskope (para dominios steereados sin proxy per-app)

## Comandos día a día (en mact2)

### Prender / apagar / estado del túnel

```bash
# APAGAR (TUN desaparece → Mac 100% corporativo; sobrevive hasta el próximo reboot/switch):
sudo launchctl bootout system/org.nixos.sing-box-tunnel

# PRENDER:
sudo launchctl bootstrap system /Library/LaunchDaemons/org.nixos.sing-box-tunnel.plist

# ESTADO (state = running + pid):
launchctl print system/org.nixos.sing-box-tunnel | grep -E "state|pid"

# REINICIAR — OBLIGATORIO tras cualquier cambio de config del túnel (rebuild que
# toque sing-box-tunnel.nix), porque launchd no reinicia si el plist no cambió:
sudo launchctl kickstart -k system/org.nixos.sing-box-tunnel
```

⚠️ Con `KeepAlive` activo, `kill` del proceso no sirve — launchd lo revive al instante. Usar `bootout`/`bootstrap`.

### OpenCode con OpenAI nativo

```bash
opencode-tunnel        # NO usar `opencode` a secas: el wrapper scopea el proxy
                       # al proceso y deja los MCPs hijos limpios.
                       # Si el túnel está apagado, arranca igual (sin proxy).
```

### Browser con túnel (para OpenAI y lo que surja)

```bash
# Edge/Chromium — flag por lanzamiento:
open -a "Microsoft Edge" --args --proxy-server=http://127.0.0.1:2080
```

```text
Firefox — configuración UNA sola vez (persiste en el profile):
Settings → Network Settings → Manual proxy → HTTP 127.0.0.1 puerto 2080
(√ "also use for HTTPS") · No proxy for: localhost, 127.0.0.1
```

**Dominios nuevos bloqueados por Netskope**: no hay lista que mantener — cualquier dominio que accedas **a través del proxy** ya viaja por el túnel. La puerta per-app es dominio-agnóstica. (Las listas `tunnel.directDomains`/`directCidrs` son para lo contrario: excluir dominios DEL túnel.)

### Mecanismo genérico: apuntar CUALQUIER app al túnel

El proxy del sistema está descartado (Netskope lo shadowea). Para cualquier app bloqueada, la pregunta es: *"¿esta app acepta que le indique un proxy por su propio mecanismo?"*

| Clase de app | Mecanismo | Persistencia |
|--------------|-----------|--------------|
| **Chromium** (Edge, Chrome, Brave, Arc) | Launch flag `--proxy-server=http://127.0.0.1:2080`, o config file: `defaults write com.microsoft.Edge ProxyMode -string fixed_servers` + `defaults write com.microsoft.Edge ProxyServer -string 127.0.0.1:2080` | Flag: cada lanzamiento · defaults: permanente (⚠️ si IT empuja policies Edge por MDM, las managed ganan) · localhost bypass automático (OAuth callback OK) |
| **Firefox / Gecko** | Profile → Manual proxy `127.0.0.1:2080` | Permanente en el profile |
| **CLI** (curl, git, npm, pip…) | Env en la invocación o wrapper: `HTTPS_PROXY=http://127.0.0.1:2080 curl …`, `git -c http.proxy=http://127.0.0.1:2080 clone …` | Per-invocación |
| **OpenCode** | `opencode-tunnel` (wrapper del repo — scopea env + MCPs limpios) | Cero (auto-detecta) |
| **Apps nativas CFNetwork** (Mail, App Store…) | Sin escape per-app confiable — el dict de proxy lo pisa Netskope | — |

**Regla general**: si la app tiene config propia de proxy, apuntala a `127.0.0.1:2080` y todo su tráfico (incluidos dominios bloqueados) viaja por el túnel. Si solo lee el proxy del sistema, no hay nada que hacer sin wrapper. Nunca exportes `HTTP(S)_PROXY` en shell profiles — solo wrappers (los MCPs hijos heredan el env y deben seguir limpios).

### Bootstrap OAuth de un dispositivo (el flujo completo)

Cada dispositivo hace su **propio** login OAuth — no se copian auth.json entre hosts (el seed script quedó obsoleto como mecanismo; es fallback dormido).

```bash
# en el dispositivo, CON el túnel corriendo:
opencode-tunnel auth login        # wrapper: el exchange del token viaja por el túnel
```

1. Copiás la URL que imprime opencode
2. La abrís en un browser **con el proxy configurado** (Edge flag/policy o Firefox profile)
3. Login en auth.openai.com (Netskope ciego — viaja por el túnel)
4. Redirect a `localhost:1455` → Chromium hace bypass del proxy para localhost → opencode captura el código
5. El exchange del token lo hace el propio opencode **por el túnel** (por eso el wrapper)

⚠️ No corras `opencode auth login` a secas: el exchange del token es un flujo OpenAI-bound que Netskope secuestraría sin el proxy env del wrapper.

### Prueba de salud (30 segundos)

```bash
# 1. El túnel trae certificados REALES (no los de Netskope):
curl -x http://127.0.0.1:2080 -sSIv https://auth.openai.com/ 2>&1 | grep "issuer:"
#    esperado: O=Google Trust Services / Cloudflare
#    mal señal: ca.grupofalabella.goskope.com (Netskope interceptó)

# 2. El full tunnel está activo (TUN capturando):
curl -sS https://ipinfo.io/ip        # → 201.188.187.112 (egres por rog)

# 3. Fallback: si rog está caído, el mismo curl sigue devolviendo TU ip
#    corporativa y todo sigue navegando — degradación automática.
```

### Teléfono (sing-box Android / SFA)

```bash
# en rog — genera link (QR interactivo) o config JSON para SFA:
sudo bin/tunnel-device-link phone            # link vless:// + QR (v2rayNG-class)
sudo bin/tunnel-device-link phone --config   # JSON completo → SFA Local profile
```

El `--config` es el que funciona con SFA (no parsea `vless://`). Importar: Profiles → + → Local → clipboard. El perfil del teléfono usa DNS del sistema (`type: local`) — funciona en cualquier red móvil/WiFi.

## Comandos server (en rog)

```bash
systemctl status sing-box --no-pager        # servicio del server
journalctl -u sing-box -f                   # ver conexiones EN VIVO: [mact2], [phone]
journalctl -u sing-box --since "30 min ago" | grep phone
ss -tln | grep 4011                         # loopback inbound escuchando
```

Cada conexión autenticada aparece con el nombre del dispositivo (`[mact2]`, `[phone]`) — así sabés quién está usando el túnel y qué destinos visita (por dominio, el server resuelve).

## Revocar / rotar dispositivos

La revocación es **autoritativa del server**: cambia qué UUIDs acepta rog; lo que el cliente tenga guardado deja de servir.

> El namespace `opencode-tunnel/` del sops file es **histórico** — no renombrar: forzaría re-encripción de sops sin beneficio funcional.

```bash
# ROTAR un dispositivo (nuevo UUID, mismo slot):
sops secrets/shared/opencode-tunnel.yaml    # editar uuid_phone: <nuevo>
git add + commit + push
nixos-build                                  # rog ahora espera el nuevo
sudo bin/tunnel-device-link phone            # nuevo link → re-importar en el teléfono

# REVOCAR por completo (ejemplo: phone):
#   1. sacar la entry "phone" del array users (linux/system/services/network/sing-box-tunnel.nix)
#   2. sacar la declaración en hosts/rog/secrets.nix
#   3. sacar la key uuid_phone del sops file
#   4. nixos-build en rog
# mact2 no se entera — cada UUID es independiente.
```

## Fallas conocidas y su significado

| Síntoma | Causa | Acción |
|---------|-------|--------|
| Todo el browsing muere | Daemon ON + rog caído aún no degradó (≤1 min) | Esperar el probe del urltest |
| Página "Aplicación No Permitida" de Falabella en el browser | Estás en el camino corporativo para ese dominio (túnel apagado, o navegador sin proxy) | Prender túnel / usar browser con proxy |
| `issuer: ca.grupofalabella...` en un test | El flujo NO pasó por el proxy loopback | Verificar `--proxy-server` / profile |
| Cambiaste la config del túnel y no aplica | launchd no reinicia si el plist no cambió | `sudo launchctl kickstart -k system/org.nixos.sing-box-tunnel` |
| `WARN icmp is not supported by outbound` en logs viejos | Config anterior a la regla ICMP→direct | Ya resuelto; si reaparece post-rebuild, kickstart |

## Dónde vive todo

| Pieza | Archivo |
|-------|---------|
| Cliente macOS (TUN + mixed + launchd + urltest) | `darwin/system/sing-box-tunnel.nix` |
| Server rog (VLESS multi-usuario, :4011) | `linux/system/services/network/sing-box-tunnel.nix` |
| Vhost tun.glats.org (cover page + WS path) | `linux/system/services/web/nginx.nix` |
| Launchers | `bin/opencode-tunnel`, `bin/tunnel-device-link` (empaquetados en `pkgs/nixos-scripts`) |
| Scrub MCP (hosts agnóstico) | `shared/opencode/runtime-config.nix` |
| Credenciales (2 UUIDs) | `secrets/shared/opencode-tunnel.yaml` (sops; regla específica en `.sops.yaml`; namespace `opencode-tunnel` histórico, no renombrar) |
| Reglas de exclusión del cliente | `hosts/mact2/default.nix` (`tunnel.directCidrs`, `tunnel.mode`) |
| Change SDD completo + evidencia | `openspec/changes/mact2-openai-tls-tunnel-via-rog/` |
| Análisis del control Netskope (publicable) | `docs/netskope-bypass-analysis.md` |

## Pendiente (no bloquea el uso diario)

- **OFFICE GATES** — validación dentro del edificio Falabella: coexistencia con FortiClient, CrowdStrike, firewall corporativo (WS long-lived), SNI observado = `tun.glats.org` only. Procedimiento exacto en `openspec/.../tasks.md` fase 5.
- Test de revocación del teléfono (2.5.2) y flip runtime a scoped mode (G9) — procedimientos documentados en `home-evidence.md`.
- Rollback total = revert de los commits del branch en master (todo es declarativo; los UUIDs sobreviven en sops).
