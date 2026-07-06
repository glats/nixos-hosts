# Multi-GitHub-Identity Setup

## Resumen

Dos identidades GitHub con sus respectivos tokens, GPG keys, y MCP servers:

| Identidad | Cuenta | Hosts | GPG |
|-----------|--------|-------|-----|
| **personal** | github.com/glats | rog, thinkcentre, t14 (default) | key propia (generar) |
| **work** (trabajo) | github.com/jcuzmar | mact2 (default), ~/Work/** en Linux | key propia (B658D64...) |

> **Note**: Real identity values (name, email) are stored in `secrets/user/identities.yaml` (sops-encrypted).
> They are decrypted at Home Manager activation time and written as git include files.

## Prerequisitos

- Branch: `feat/multi-github-identity`
- Todos los cambios Nix ya estan commiteados
- `nix flake check --no-build` pasa en Linux

---

## Paso 1: Generar GPG key personal

```bash
gpg --full-generate-key
```

Opciones:
- Kind: `RSA and RSA`
- Bits: `4096`
- Validez: `2y` (2 anios)
- Name: `your personal name` (from secrets/user/identities.yaml)
- Email: `your personal email` (from secrets/user/identities.yaml)
- Comment: (vacio, Enter)

Anota el **fingerprint** que aparece al final:
```
pub   rsa4096/XXXXXXXXXXXX 2026-07-06 [SC] [expires: 2028-07-05]
      XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX  <-- ESTE es el fingerprint
```

Luego exporta la llave privada:
```bash
gpg --armor --export-secret-keys XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX > /tmp/glats-gpg-key.asc
cat /tmp/glats-gpg-key.asc
# Copia todo el output, desde -----BEGIN PGP PRIVATE KEY BLOCK-----
```

---

## Paso 2: Exportar GPG key de work

```bash
gpg --armor --export-secret-keys B658D64F6FDBCFD1EBA53509A1D4ECB0118566C8 > /tmp/jcuzmar-gpg-key.asc
cat /tmp/jcuzmar-gpg-key.asc
# Copia todo el output
```

---

## Paso 3: Agregar todos los secretos a sops (hacer en cualquier host)

```bash
git checkout feat/multi-github-identity
sops edit secrets/shared/passwords.yaml
```

Bajo `github:`, DEBERIA verse asi (agrega lo que falte):

```yaml
github:
    pat: ENC[...]                                      # personal PAT (ya existe)
    pat_jcuzmar: ENC[...]                              # work PAT (ya deberia estar)
    gpg_key_fingerprint: ENC[...]                      # OBSOLETO — se reemplaza abajo
    gpg_jcuzmar_fingerprint: B658D64F6FDBCFD1EBA53509A1D4ECB0118566C8   # AGREGAR
    gpg_jcuzmar_key: |                                 # AGREGAR (pegar del paso 2)
        -----BEGIN PGP PRIVATE KEY BLOCK-----
        ...
        -----END PGP PRIVATE KEY BLOCK-----
    gpg_glats_fingerprint: XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX     # AGREGAR (del paso 1)
    gpg_glats_key: |                                   # AGREGAR (pegar del paso 1)
        -----BEGIN PGP PRIVATE KEY BLOCK-----
        ...
        -----END PGP PRIVATE KEY BLOCK-----
```

- `gpg_key_fingerprint` (sin prefijo) es el nombre VIEJO — si existe, **dejalo**, el codigo Nix ya no lo usa
- Los valores nuevos se encriptan automaticamente al guardar

Verifica que quedo bien:
```bash
sops -d secrets/shared/passwords.yaml | grep -E "gpg_(jcuzmar|glats)_"
# Deberias ver los 4 keys
```

---

## Paso 4: Deploy en cada host

### Linux (rog, thinkcentre, t14)

```bash
# En cada host:
git checkout feat/multi-github-identity
nixos-build switch    # o nixos-build safe
```

### macOS (mact2)

```bash
git checkout feat/multi-github-identity
nh home switch --hostname mact2 .   # o como deployes normalmente
```

---

## Paso 5: Verificar

### git identity switchea segun directorio

```bash
# Linux — fuera de ~/Work debe mostrar personal identity
cd ~/dev/algun-proyecto-personal
git config user.name    # → value from sops (identities/personal)
git config user.email   # → value from sops (identities/personal)

# Linux — dentro de ~/Work debe mostrar work identity
cd ~/Work/algun-proyecto
git config user.name    # → value from sops (identities/work)
git config user.email   # → value from sops (identities/work)

# macOS — fuera de ~/Personal debe mostrar work identity
cd ~/dev/algun-proyecto
git config user.name    # → value from sops (identities/work)

# macOS — dentro de ~/Personal debe mostrar personal identity
cd ~/Personal/algun-proyecto
git config user.name    # → value from sops (identities/personal)
```

### GPG signing funciona

```bash
# Hacer un commit de prueba en ~/Work/ en Linux
cd ~/Work/proyecto-test
git commit --allow-empty -m "test signing"
git log --show-signature -1
# Deberia mostrar: "Good signature from ... [work email]"

# Hacer un commit de prueba fuera de ~/Work
cd ~/dev/proyecto-test
git commit --allow-empty -m "test signing personal"
git log --show-signature -1
# Si configuraste personal GPG key: "Good signature from ..."
# Si no: debe mostrar que no hay signature configurada (no falla)
```

### MCP servers

Los MCP entries aparecen en OpenCode:
- `github-personal` — opera como personal
- `github-work` — opera como work

Ambos habilitados. Eliges cual usar segun en que repo estes trabajando.

---

## Troubleshooting

### "No secret found" al hacer build

Significa que agregaste la declaracion sops pero no el valor en `passwords.yaml`.
Usa `sops edit secrets/shared/passwords.yaml` y agrega el key faltante.

### GPG signing falla: "secret key not available"

La llave no se importo al keyring. Verifica:
```bash
gpg --list-secret-keys
```
Si la llave no aparece, puedes forzar la importacion:
```bash
gpg --batch --import $(cat ~/.config/sops-nix/secrets/github/gpg_jcuzmar_key)
```

### "gitdir:~/Work/**" no funciona

IncludeIf usa `gitdir:` con patron. Asegurate que `~` se expanda correctamente.
En git, `~` siempre es el home del usuario. El patron `~/Work/**` matchea cualquier
repositorio dentro de `~/Work/` y subdirectorios.
