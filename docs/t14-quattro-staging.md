# T14 Quattro staging

The t14 entry point imports `hosts/t14/quattro.nix`. The flake pins published fork commit `46ac3fdd57d7dd7c947c832995f66d985045b421` on the fork's `main` branch; no temporary worktree override is required. Verify the locked configuration without activation:

```sh
nix eval --impure --json --expr 'import ./tests/t14-quattro-locked.nix { flake = builtins.getFlake (toString ./.); }'
nix eval --impure --json .#nixosConfigurations.t14 --apply 'host: import ./tests/t14-quattro-shell.nix { inherit host; }'
nix build --no-link .#nixosConfigurations.t14.config.system.build.toplevel
```

This milestone replaces only Waybar with the Quickshell bar and its selected native widgets. Walker remains the launcher; Mako, SwayOSD, background, lock/idle, authentication, HDM monitor/lid handling, greetd/ReGreet, VNC, mouse-wiggle, and personal applications remain owned by their current configuration. Native plugins that duplicate those services or expose unported actions are disabled. The menu bar widget is omitted while Walker keyboard launching remains available.

The shell layout and base style are Nix-owned; interactive layout persistence is not promised. The shell uses the current configured palette and does not provide dynamic native theme switching. The user's writable `~/.config/omarchy/shell.toml` override remains supported by the fork. Configuration and build do not activate the system; live acceptance and saved-network migration require separate authorization.

To roll back the desktop selection before activation, remove the `./quattro.nix` import from `hosts/t14/default.nix`; the fork's default remains the legacy desktop. NetworkManager selection is a separate change in `hosts/t14/omarchy-config.nix` and is not reverted by removing the shell import.
