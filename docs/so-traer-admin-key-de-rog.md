# Cómo traer la admin age key de `rog` a `t14`

> **Propósito**: explicar paso a paso cómo traer la age key privada de
> `admin_glats` desde `rog` hasta `t14`, para poder re-encriptar
> `secrets/shared/passwords.yaml` con la nueva `*host_t14` key.

## Contexto

`sops-nix` re-encripta archivos usando la private key local. La admin
key (`admin_glats`) está guardada en `rog` y `thinkcentre`, **no en
`t14`**. Para rotar la age key de `t14` y que el host pueda descifrar
los secrets compartidos, hay que:

1. Descifrar `secrets/shared/passwords.yaml` con la admin key.
2. Re-encriptar el archivo con la nueva age key pública de `t14`.

Como `t14` no tiene la admin key, no puede hacer el paso 1 por sí
solo. Hay que traer la admin key temporalmente.

## Pre-requisitos

- `t14` con red y capaz de llegar a `rog` (por hostname o IP).
- `rog` encendido y accesible por SSH como `glats`.
- En `rog`, la private key de admin vive en
  `~/.config/sops/age/keys.txt`.

Si `rog` no es alcanzable desde `t14` por red, ver la sección
[Sneakernet](#sneakernet-cuando-no-hay-red) más abajo.

## Procedimiento

### 1. Crear el directorio destino en t14

```bash
mkdir -p ~/.config/sops/age
chmod 700 ~/.config/sops/age
```

### 2. Copiar la admin key desde rog

```bash
scp glats@rog:/home/glats/.config/sops/age/keys.txt \
    ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt
```

### 3. Verificar que `sops` reconoce la key

Desde el repo de configuración (en t14, después de la fase de merge):

```bash
cd ~/.nixos
sops -d secrets/shared/passwords.yaml | head -5
```

Debe mostrar el contenido desencriptado, por ejemplo:

```yaml
glats_hashed_password: $y$j9T$...$
github:
    pat: ghp_...
```

Si tira `Failed to get the data key required to decrypt the SOPS
file` o `no matching key`:

- Confirmar que el archivo se copió bien: `ls -la ~/.config/sops/age/keys.txt`
- Confirmar permisos: `stat -c '%a %n' ~/.config/sops/age/keys.txt` debe dar `600`
- Probar apuntando explícitamente a la key:
  ```bash
  SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt \
      sops -d secrets/shared/passwords.yaml | head -5
  ```
- Si hay caché mala de sops (re-encrypts fallidos previos):
  ```bash
  sudo rm -rf /root/.cache/sops/age ~/.cache/sops/age
  ```

### 4. Re-encriptar con la nueva `*host_t14`

Este paso se hace dentro del flujo del merge (ver plan principal,
Fase 5). Resumen:

```bash
cd ~/.nixos
sops updatekeys -y secrets/shared/passwords.yaml
```

### 5. Verificar que t14 puede descifrar solo con su SSH key

Para confirmar que la nueva age key quedó bien en el archivo y t14 ya
no necesita la admin key:

```bash
mv ~/.config/sops/age/keys.txt ~/.config/sops/age/keys.txt.bak
sops -d secrets/shared/passwords.yaml >/dev/null && echo "t14 OK con SSH key"
mv ~/.config/sops/age/keys.txt.bak ~/.config/sops/age/keys.txt
```

Si imprime `t14 OK con SSH key`, la rotación funcionó.

### 6. Limpieza post-merge (opcional)

Una vez que `t14` puede descifrar con su propia SSH key, la admin
key ya no es necesaria en `t14` para operaciones de runtime. Se
puede borrar:

```bash
rm -f ~/.config/sops/age/keys.txt
```

**Mantenerla** si querés re-encriptar secrets en el futuro desde
`t14` sin tener que ir a `rog`.

## Sneakernet: cuando no hay red

Si `t14` no puede llegar a `rog` por red:

1. En `rog`: copiar la key a un USB encriptado o directo:
   ```bash
   cp ~/.config/sops/age/keys.txt /media/usb/keys.txt
   ```
2. Pasar el USB físicamente a `t14`.
3. En `t14`:
   ```bash
   mkdir -p ~/.config/sops/age && chmod 700 ~/.config/sops/age
   cp /media/usb/keys.txt ~/.config/sops/age/keys.txt
   chmod 600 ~/.config/sops/age/keys.txt
   ```
4. Continuar desde el paso 3 del procedimiento principal.

## Riesgos

- **Permisos**: si la key queda con `644` o peor, `sops` rechaza
  usarla. Siempre `chmod 600`.
- **Key comprometida**: si la USB se pierde o el `scp` se intercepta,
  hay que rotar la admin key (regenerar con `age-keygen`,
  re-encriptar todos los secrets en todos los hosts, distribuir la
  nueva key a `rog` y `thinkcentre`).
- **Caché de sops**: si ya intentaste descifrar antes y falló,
  podés tener un caché malo en `~/.cache/sops/age/`. Borrar y
  reintentar.

## Referencias

- [`sops-new-host.md`](./sops-new-host.md) — agregar un host nuevo
  al círculo de sops.
- [`secrets-migration.md`](./secrets-migration.md) — fusionar
  secrets entre linux y macOS.
- `modules/base/sops.nix` — qué secrets se montan automáticamente.
