## Exploration: tmux restore attach

### Current State
- El repo está en modo híbrido. `shared/tmux.nix` activa captura de contenido, guardado cada 15 minutos y `@continuum-restore on`; Linux usa plugins empaquetados y Darwin TPM. No hay alias ni wrapper actual para tmux.
- **(a) Patrón humano común:** `tmux a`/`tmux attach` es la forma normal de volver a una sesión ya existente (elige la usada más recientemente). Para un único espacio de trabajo nombrado, también es muy común un alias como `tmux new-session -As main`, que adjunta o crea `main`.
- **(b) tmux nativo:** `attach` puede arrancar el servidor si falta el socket, pero no crea una sesión y falla si todavía no existe ninguna. `new-session -A` adjunta una sesión objetivo existente o crea una nueva; `start-server` sólo arranca el servidor, sin sesión ni espera.
- **(c) Continuum/Resurrect:** Resurrect guarda/restaura sesiones, ventanas, paneles y layouts; su restauración manual es explícita (`prefix + Ctrl-r` o `restore.sh`). Continuum guarda periódicamente y, con `@continuum-restore on`, lanza Resurrect una vez y en segundo plano al iniciar el servidor (tras ~1 s). No cambia la semántica de `attach` ni hace que éste espere. Por tanto, ver ventanas aparecer tras adjuntar es posible, pero es un efecto incidental de esa carrera asíncrona, no una UX ni garantía documentada.
- En consecuencia, `tmux a` justo después de un reinicio puede exponer transitoriamente `no sessions`; no es una diferencia inherente entre Linux y macOS. `exit-empty off` y `exit-unattached off` ya ayudan a que el servidor sobreviva mientras se restaura.

### Affected Areas
- `shared/tmux.nix` — política compartida de Resurrect/Continuum.
- `linux/home/tmux.nix` — carga de Continuum empaquetado y segundo `run-shell` intencional.
- `darwin/home/tmux.nix` — carga TPM equivalente, pero mutable.
- `shared/shell-aliases.nix` — único sitio común adecuado si se adopta un comando humano `tmux-resume`.
- `linux/home/shell.nix`, `darwin/home/shell.nix` — ambos componen la configuración de zsh compartida.

### Approaches
1. **`tmux a` nativo** — reanudar sólo cuando ya hay una sesión.
   - Pros: idiomático y sin capa local.
   - Cons: en un arranque en frío revela la carrera de Continuum.
   - Effort: Low

2. **`tmux new-session -As main`** — adjuntar o crear un workspace nombrado.
   - Pros: patrón muy usado para una sesión persistente normal.
   - Cons: el bootstrap puede dejar una ventana/sesión extra o interferir visualmente con una restauración de múltiples sesiones.
   - Effort: Low

3. **`tmux start-server` + `tmux a`** — separar servidor y adjunto.
   - Pros: no crea sesión artificial.
   - Cons: sigue sin esperar la restauración asíncrona; no aporta frente a un attach con reintento.
   - Effort: Low

4. **Restauración explícita de Resurrect** — desactivar auto-restore, iniciar servidor y ejecutar restore antes de adjuntar.
   - Pros: orden y progreso controlables.
   - Cons: reemplaza una integración mantenida por upstream por orquestación propia y debe evitar doble restore.
   - Effort: Medium

5. **Wrapper común `tmux-resume`** — conservar Continuum como único restaurador; intentar attach y, sólo durante el arranque frío, reintentar con plazo corto y error claro.
   - Pros: un solo flujo para Linux y mact2, sin bootstrap ni doble restore; `tmux a` queda nativo para uso avanzado.
   - Cons: pequeña política propia que debe distinguir snapshot ausente de fallo real.
   - Effort: Low–Medium

### Recommendation
Homogeneizar con el enfoque 5: mantener `@continuum-restore on` y publicar un único comando humano, por ejemplo `tmux-resume`, que hace attach con reintento acotado durante el cold start. **Lo que el usuario debería escribir normalmente es `tmux-resume`;** `tmux a` sigue siendo la forma nativa y común para readjuntar a un servidor que ya está listo, pero no es el contrato de recuperación tras reinicio.

No hacer de la aparición progresiva de ventanas un objetivo: es incidental, depende del tamaño/velocidad del snapshot y no tiene semántica de progreso. El objetivo UX debe ser «un comando, sin falso `no sessions`, termina adjunto a la restauración». No usar `new-session -A` como recuperador general, ni `start-server` solo, ni un restore manual mientras Continuum siga activo. Mantener la política actual de procesos hasta que se decida explícitamente si se quiere `:all:`.

### Risks
- El wrapper debe tener timeout y comunicar snapshot ausente/corrupto, no ocultar un fallo real como espera infinita.
- Ejecutar Resurrect manualmente junto a auto-restore puede duplicar restauraciones.
- `@resurrect-processes ':all:'` relanzaría comandos con efectos laterales; no debe incorporarse implícitamente.
- TPM en Darwin es mutable, frente a los plugins empaquetados de Linux; la UX propuesta no depende de ello, pero las pruebas deben cubrir ambas rutas.

### Ready for Proposal
Sí. Proponer un contrato `tmux-resume` común que preserve a Continuum como único restaurador, con pruebas de snapshot de varias sesiones en Linux y mact2: sin falso `no sessions`, sin sesión extra y con el comportamiento de procesos decidido explícitamente.
