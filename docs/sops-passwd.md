# Cambiar contraseña de usuario en NixOS + sops-nix

La contraseña de `glats` está manejada por **sops-nix** a través del secreto
`glats_hashed_password` en `secrets/shared/passwords.yaml`.

Esto significa que:

- `passwd` **funciona**, pero solo hasta el próximo `nixos-rebuild switch`
- `nixos-rebuild switch` **sobrescribe** `/etc/shadow` con el hash de sops

## Opción 1: Cambio temporal (solo para probar)

```bash
passwd
# La contraseña nueva funciona hasta el próximo rebuild
```

## Opción 2: Cambio permanente (actualizar sops)

Necesitás regenerar el hash y encriptarlo en sops.

### 1. Generar el nuevo hash

```bash
mkpasswd -m yescrypt
# Ingresá la nueva contraseña (se pide 2 veces)
# Te devuelve algo como:
# $y$j9T$2JBBjf1Fh4OquLIqSJQtx0$LPfylqWzZuA0Duwa/q6XH/vg3Rr0Tn.XhZkgug4m6B0
```

### 2. Editar el archivo de secretos

```bash
sops secrets/shared/passwords.yaml
```

Buscá la clave `glats_hashed_password` y reemplazá el valor por el hash nuevo.

### 3. Aplicar el cambio

```bash
sudo nixos-rebuild switch --flake /etc/nixos#t14
```

La contraseña nueva es permanente.

## Opción 3: Sacar la contraseña de sops

Si preferís manejar la contraseña localmente (sin depender de sops):

### 1. Editar `modules/base/users.nix`

Reemplazar:

```nix
hashedPasswordFile = lib.mkIf
  (
    config ? sops && config.sops.secrets ? "glats_hashed_password"
  )
  config.sops.secrets."glats_hashed_password".path;
```

Por:

```nix
initialPassword = "tu-contraseña-temporal";
```

> ⚠️ Con `initialPassword`, el primer login te va a pedir cambiarla. Después
> de eso, `passwd` es permanente.

### 2. Aplicar

```bash
sudo nixos-rebuild switch --flake /etc/nixos#t14
```

### 3. (Opcional) Limpiar el secreto de sops

Una vez que no dependés de sops para la contraseña, podés eliminar la entrada
`glats_hashed_password` de `secrets/shared/passwords.yaml`:

```bash
sops secrets/shared/passwords.yaml
# Eliminar la clave glats_hashed_password y guardar
```

## Referencias

- Archivo de secretos: `secrets/shared/passwords.yaml`
- Config de usuario: `modules/base/users.nix`
- Config de sops: `modules/base/sops.nix`
