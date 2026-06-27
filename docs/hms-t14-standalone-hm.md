# `hms` en t14 — Home Manager standalone con omarchy-nix

## Problema

`hms` (alias `home-manager switch --flake .#t14`) fallaba con:

```
error: expected a set but found null: null
error: The option `omarchy.email_address' was accessed but has no value defined.
```

## Causa raíz (3 capas)

### 1. HM settea `osConfig = null` siempre

Home Manager define `_module.args.osConfig = lib.mkDefault null` en
`modules/misc/submodule-support.nix:40`. Esto hace que `osConfig` esté
**siempre presente** como argumento del módulo, con valor `null`.

El módulo HM de omarchy-nix (`flake.nix:52-57`) declara:

```nix
default = { config, lib, pkgs, osConfig ? {}, ... }: {
    config = lib.mkIf (osConfig ? omarchy) {
        omarchy = osConfig.omarchy;
    };
};
```

El `osConfig ? {}` **nunca se usa** porque HM ya pasa `osConfig = null`
explícitamente (los defaults de función en Nix solo aplican cuando el
argumento no se pasa).

### 2. `pushDownProperties` evalúa valores antes de `mkIf`

La función `pushDownProperties` en `lib/modules.nix` usa
`builtins.mapAttrs`, que **fuerza todos los valores** de un attrset
antes de que `mkIf` pueda cortocircuitar.

```nix
# lib/modules.nix:1351
else if cfg._type or "" == "if" then
    map (mapAttrsIfAttrs (n: v: mkIf cfg.condition v))
        (pushDownProperties cfg.content)
```

`builtins.mapAttrs` evalúa `osConfig.omarchy` aún dentro de un
`mkIf`. Como `osConfig = null`, el acceso `osConfig.omarchy` falla
con "expected a set but found null".

### 3. `hyprland/envs.nix` lee `osConfig.services.xserver.videoDrivers`

El archivo `modules/home-manager/hyprland/envs.nix:9` hace:

```nix
hasNvidiaDrivers = builtins.elem "nvidia"
    osConfig.services.xserver.videoDrivers;
```

En HM standalone no existe `services.xserver.videoDrivers`.

## Solución

En el entry de `homeConfigurations.t14` en `flake.nix`, se inyecta un
módulo inline que:

1. **Seed `osConfig`** con los attrs que omarchy espera:
   ```nix
   _module.args.osConfig = nixpkgs.lib.mkForce {
       omarchy = {};
       services.xserver.videoDrivers = [];
   };
   ```
   - `mkForce` vence al `mkDefault null` de HM.
   - `omarchy = {}` hace que `osConfig ? omarchy` sea `true` y
     `osConfig.omarchy` retorne `{}` (descartado después por el merge
     con nuestro `omarchy` real).
   - `services.xserver.videoDrivers = []` evita que envs.nix explote.

2. **Define `omarchy`** con los valores que el NixOS path le pasaría:
   ```nix
   omarchy = {
       theme = "glats";
       username = "glats";
       full_name = "Glats";
       email_address = "glats@local";
       browser = "brave";
       terminal = "ghostty";
       monitors = [ "eDP-1,preferred,auto,1" ];
       scale = 1;
       light_theme_detection.enable = false;
   };
   ```

## Lecciones

- `lib.mkIf` NO cortocircuita la evaluación de su contenido cuando
  este es un attrset — `builtins.mapAttrs` fuerza los valores antes de
  que la condición tenga efecto.
- HM siempre provee `osConfig = null` por defecto, no `{}`.
- El default de función `osConfig ? {}` en la declaración del módulo
  de omarchy-nix nunca se activa porque HM ya pasa `osConfig`.
- Para acceder condicionalmente a atributos dentro de `mkIf`, usar
  `attr or default` en vez de `attr` directo.

## Referencias

- HM `modules/misc/submodule-support.nix` — `_module.args.osConfig`
- nixpkgs `lib/modules.nix:1347-1356` — `pushDownProperties`
- omarchy-nix `flake.nix:55-57` — `osConfig.omarchy`
- omarchy-nix `modules/home-manager/hyprland/envs.nix:9` — `osConfig.services.xserver.videoDrivers`
