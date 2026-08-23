# Guía: Soporte MacBook M4/M5 (aarch64-darwin) y jubilación de mact2

> Estado: plan aprobado, pendiente de ejecución. El hardware aún no llegó.
> Repos afectados: solo `nixos-hosts` (este repo). Host nuevo provisional: `macm4`
> (si llega un M5, renombrar = mover directorio + actualizar `flake.nix`, ~2 min).
> Usuario: `jcuzmar` (igual que mact2).

## Contexto

La flake completa está clavada a **nixpkgs 26.05** por una única razón: el mact2 es
Intel (`x86_64-darwin`) y la rama 26.11 la eliminó (`flake.nix:6-7`). La MacBook
nueva es Apple Silicon (`aarch64-darwin`), arquitectura soportada tanto en 26.05
como en canales posteriores.

Consecuencia clave: **la nueva Mac no obliga a migrar de canal**, pero su llegada
es el momento en que se puede jubilar mact2 y desbloquear la migración.

### Decisiones tomadas

| Decisión | Valor | Consecuencia |
|---|---|---|
| Destino de mact2 | Se jubila | Se elimina todo rastro `x86_64-darwin` (Fase 3) |
| Canal nixpkgs | Migrar cuando mact2 muera | Recomendado: esperar 26.11 estable (~nov 2026); alternativa: `unstable` antes |
| Nombre de host | `macm4` (o `macm5`) | Debe coincidir con `scutil --get LocalHostName` |
| Usuario | `jcuzmar` | Hereda patrón de mact2 |
| Pin `nix-vscode-extensions` | Mantener hasta Fase 3 | Des-pinnear antes rompería el eval de mact2 |

---

## Fase 1 — Preparar la flake (sin hardware)

**Objetivo:** que `darwinConfigurations.macm4` evalue correctamente desde Linux.
Todo verificable con `nix flake check --no-build`; no requiere la Mac física.

### 1.1 Crear `hosts/macm4/default.nix`

Copiar el patrón de `hosts/mact2/default.nix`. Contenido base:

```nix
# macOS host configuration for macm4 (Apple Silicon, aarch64-darwin).
{ pkgs
, inputs
, self
, primaryUser
, javaVersion
, lib
, host
, ...
}:
{
  imports = [
    ../../darwin/system/nix.nix
    ../../darwin/system/cachix.nix
    ../../darwin/system/homebrew.nix
    ../../darwin/system/settings.nix
    ../../darwin/system/mise.nix
    ../../darwin/services/wsdd.nix

    inputs.home-manager.darwinModules.home-manager
    inputs.nix-homebrew.darwinModules.nix-homebrew
  ];

  networking.hostName = host;

  # homebrew installation manager
  nix-homebrew = {
    user = primaryUser;
    enable = true;
    autoMigrate = true;
  };

  # home-manager config
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    users.${primaryUser} = {
      imports = [
        ../../darwin/home
      ];
      home.stateVersion = "25.05";
      # TODO(glatz): decidir tier opencode para macm4 (mact2 usa github-copilot-safe).
      home.opencode.activeProviderName = "github-copilot-safe";
    };
    extraSpecialArgs = {
      inherit
        inputs
        self
        primaryUser
        javaVersion
        ;
    };
  };

  system.primaryUser = primaryUser;
  users.users.${primaryUser} = {
    home = "/Users/${primaryUser}";
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      # rog machine (glats)
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMigT6lscyISTW6jbk9c34gMYSaRQIq4tUxMvn7vd6K7 t14"
    ];
  };
  environment = {
    variables = {
      DISPLAY = ":0";
    };
    systemPackages = with pkgs; [ git ];
    # Intel usa /usr/local; Apple Silicon usa /opt/homebrew.
    systemPath = [
      (if pkgs.stdenv.isAarch64 then "/opt/homebrew/bin" else "/usr/local/bin")
    ];
    pathsToLink = [ "/Applications" ];
  };

  services.wsdd.enable = true;
}
```

Notas:

- `lib/mkDarwinHost.nix:6` ya acepta `system ? "x86_64-darwin"` como parámetro —
  **no requiere cambios**; solo se pasa `"aarch64-darwin"` desde flake.nix.
- El condicional `isAarch64` en `systemPath` ya resuelve `/opt/homebrew/bin`.
- `settings.nix` / `homebrew.nix` son agnósticos de arquitectura.

### 1.2 Registrar el host en `flake.nix`

```nix
# --- Darwin configurations ---
darwinConfigurations = {
  mact2 = mkDarwinHost { hostname = "mact2"; };
  macm4 = mkDarwinHost { hostname = "macm4"; system = "aarch64-darwin"; };
};
```

Standalone HM (sección `homeConfigurations`), junto al entry de mact2:

```nix
macm4 = baseHomeConfig "macm4" "aarch64-darwin" "jcuzmar" [
  ./darwin/home
];
```

Outputs de paquetes y formatter:

```nix
packages.aarch64-darwin = aarch64DarwinPackages;
formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixpkgs-fmt;
```

### 1.3 Agregar pkgs aarch64 en `lib/packages.nix`

```nix
let
  linuxPkgs = pkgsFor "x86_64-linux";
  darwinPkgs = pkgsFor "x86_64-darwin";
  darwinPkgsAarch64 = pkgsFor "aarch64-darwin";
  ...
in
{
  inherit linuxPackages darwinPackages aarch64DarwinPackages;
}
# con: aarch64DarwinPackages = commonPackages darwinPkgsAarch64;
```

### 1.4 Paquetes custom que necesitan `aarch64-darwin`

| Paquete | Estado | Cambio requerido |
|---|---|---|
| `pkgs/opencode/default.nix` | OK ya | Ninguno (tiene ambos hashes) |
| `pkgs/leaf/default.nix` | Falta | Agregar entry + platforms |
| `pkgs/gentle-ai/default.nix` | Falta | Solo `meta.platforms` |
| `pkgs/engram/default.nix` | Falta | Solo `meta.platforms` |
| `claude-code-nix` (input) | OK ya | Flake upstream soporta aarch64-darwin |

**leaf** — el release 1.27.0 publica `leaf-macos-arm64`. Entry verificado
(hash derivado del digest del asset GitHub; validar con `nix store prefetch-file`
si falla):

```nix
aarch64-darwin = {
  url = "https://github.com/RivoLink/leaf/releases/download/${version}/leaf-macos-arm64";
  sha256 = "sha256-q+B/PZVZlsR7qX12e9jFwsT9A2W8883En46sYkVFcU0=";
};
```

Y en `meta.platforms` agregar `"aarch64-darwin"`.

**gentle-ai y engram** — `buildGoModule` compila nativo; basta con:

```diff
   platforms = [
     "x86_64-linux"
     "x86_64-darwin"
+    "aarch64-darwin"
   ];
```

### 1.5 Qué NO tocar todavía

- **Pin `nix-vscode-extensions` (`flake.nix:121-124`)**: clavado a `1c7bb95` porque
  después de ese commit upstream eliminó `x86_64-darwin`. Mientras mact2 exista,
  des-pinnear rompería su build. Se libera en Fase 3.
- **Inputs `nixpkgs` / `nix-darwin`**: siguen en 26.05 (ver Fase 3).
- Overlay `overlays/darwin.nix`: ya usa `final.stdenv.hostPlatform.system` — agnóstico.

### Gate de verificación Fase 1

```bash
format-nix
nix flake check --no-build
nix eval --raw .#darwinConfigurations.macm4.config.system.build.toplevel.drvPath && echo
nix eval --raw .#homeConfigurations.macm4.activationPackage.drvPath && echo
```

Los dos últimos prueban evaluación pura de aarch64-darwin (no construyen —
construir darwin desde Linux requeriría remote builder).

Commit sugerido: `feat(darwin): add macm4 host scaffold (aarch64-darwin)`.

---

## Fase 2 — Bootstrap en la Mac nueva (cuando llegue)

**Objetivo:** Mac administrada por nix-darwin con secrets funcionales.
Runbook detallado de sops: `docs/sops-new-host.md`.

### 2.1 Preparación del sistema

1. Completar el setup inicial de macOS (usuario `jcuzmar`, idioma, etc.).
2. Nombrar el equipo: System Settings → General → Sharing → Local hostname =
   `macm4` (debe coincidir con el attr de la flake para `nixos-build`).
3. Instalar Nix con el instalador Determinate (la flake importa el módulo
   `determinate`):

   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://install.determinate.systems/nix | sh -s -- install
   ```

4. Clonar el repo:

   ```bash
   git clone git@github.com:glats/nixos-hosts.git ~/.nixos
   cd ~/.nixos
   ```

### 2.2 Secrets (sops-nix)

Seguir `docs/sops-new-host.md` pasos 1–5, resumen:

1. Generar age key desde la SSH host key del Mac:

   ```bash
   sudo ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ""
   nix shell nixpkgs#ssh-to-age --command ssh-to-age -i /etc/ssh/ssh_host_ed25519_key.pub
   ```

2. Agregar `&host_macm4 <age...>` a `.sops.yaml` (sección `keys:`) e incluirlo en
   las creation rules de `secrets/shared/`, `opencode.yaml`, `identities.yaml`,
   `atlassian.yaml` — o usar `bin/sops-rotate-keys add-host macm4 <archivo>`.
3. Copiar la admin key al Mac (desde rog):

   ```bash
   scp /var/lib/sops-nix/key.txt jcuzmar@macm4.local:/tmp/admin-key.txt
   # en macm4: ubicarla donde shared/sops.nix la espere
   ```

4. Re-encriptar los secrets afectados:

   ```bash
   for f in secrets/shared/*.yaml secrets/user/opencode.yaml secrets/user/identities.yaml secrets/user/atlassian.yaml; do
     sops updatekeys --yes "$f"
   done
   ```

### 2.3 Primera activación

```bash
sudo nix run nix-darwin/nix-darwin-26.05#darwin-rebuild -- \
  switch --flake ~/.nixos#macm4
```

A partir de aquí, cambios diarios con el wrapper estándar del repo:

```bash
nixos-build switch
```

(`bin/nixos-build:99-100` auto-detecta hostname darwin y llama `darwin-rebuild`.)

### 2.4 Verificación post-bootstrap

```bash
which brew                     # /opt/homebrew/bin/brew
darwin-rebuild --list-generations
ls /run/current-system/sw/Applications 2>/dev/null || ls ~/Applications
ssh localhost true             # authorized keys activos
```

Además: verificar wsdd visible desde rog (`mact2.local` → ahora `macm4.local`),
y sincronizar VNC/SSH remotos si se quiere acceder desde Linux antes de Fase 3.

Commit: `chore(sops): add macm4 age key and re-encrypt shared secrets`.

---

## Fase 3 — Jubilar mact2 y migrar canal

**Objetivo:** eliminar `x86_64-darwin` de la flake y subir nixpkgs/nix-darwin.
Ejecutar SOLO cuando macm4 esté verificado y estable en uso diario.

### 3.1 Checklist de eliminación de mact2

| Elemento | Ubicación |
|---|---|
| Directorio del host | `hosts/mact2/` |
| `darwinConfigurations.mact2` | `flake.nix:252` |
| `homeConfigurations.mact2` | `flake.nix:292-298` |
| `packages.x86_64-darwin` | `flake.nix:209` |
| `formatter.x86_64-darwin` | `flake.nix:305` |
| Entry `x86_64-darwin` de leaf | `pkgs/leaf/default.nix:21-24` |
| `darwinPkgs` (x86) en packages.nix | `lib/packages.nix:17` |
| Key `&host_mact2` + rules | `.sops.yaml` (+ re-encriptar con `sops updatekeys`) |
| Código muerto duplicado | `darwin/default.nix` (no importado desde el refactor de homologación) |
| Docs | `docs/sops-new-host.md` (tabla hosts), `AGENTS.md`, `openspec/config.yaml` |

Referencias remotas a actualizar (apuntaban a `mact2.local`):

| Archivo | Qué cambia |
|---|---|
| `linux/home/remote-desktop.nix:258-315` | Entradas remmina/desktop `vnc-mact2` |
| `linux/home/ssh.nix:34-37` | Host SSH `mact2.local` |
| `darwin/home/remote-desktop.nix:194-203` | Bookmarks VNC internos |
| `hosts/t14/default.nix:89-94` | Comentario nscd/avahi (renombrar ejemplo) |

### 3.2 Migración de canal

Decisión pendiente registrada: esperar **26.11 estable (~nov 2026)** vs saltar a
`unstable` antes. En cualquiera de los dos casos:

1. `flake.nix`: `nixpkgs.url` → `github:NixOS/nixpkgs/nixos-26.11` (o unstable),
   `nix-darwin.url` → branch correspondiente (los branches de nix-darwin siguen
   1:1 a las releases de nixpkgs).
2. Actualizar lock: `nix flake update nixpkgs nix-darwin home-manager sops-nix`.
3. **Des-pinnear** `nix-vscode-extensions`: quitar rev `1c7bb95...` y seguir master
   (a partir de aquí solo existe `aarch64-darwin`, ya no hay riesgo x86).
4. Actualizar comentarios de `flake.nix` líneas 6-7, 94, 117-120.
5. Gate completo (toda la flota comparte input):

   ```bash
   nix build .#nixosConfigurations.rog.config.system.build.toplevel
   nix build .#nixosConfigurations.thinkcentre.config.system.build.toplevel
   nix build .#nixosConfigurations.t14.config.system.build.toplevel
   nix flake check --no-build
   ```

   Y en macm4: `nixos-build dry` antes de `switch`.

Commit separado: `chore(flake): drop Intel macOS, migrate to nixpkgs 26.11`.

### 3.3 Rollback

- Cada fase es un commit independiente y reversible (`git revert`).
- La migración de canal es la única fase con riesgo transversal (afecta a los 3
  hosts Linux): hacerla sola, nunca mezclada con cambios funcionales.
- mact2 conserva su última generación local: mientras no se borre, se puede
  reactivar con `darwin-rebuild --rollback` para rescate.

---

## Apéndice: referencias rápidas

- Runbook sops por host: `docs/sops-new-host.md`
- Tooling de rotación: `bin/sops-rotate-keys add-host <host> <file>`
- Builder darwin: `lib/mkDarwinHost.nix` (parámetro `system`)
- Patrón de host darwin: `hosts/mact2/default.nix`
- Bootstrap nix-darwin oficial: https://github.com/nix-darwin/nix-darwin
- Assets leaf: https://github.com/RivoLink/leaf/releases/tag/1.27.0
