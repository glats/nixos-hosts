# SonicDE on rog

## Current status: parked

rog has returned to MATE through the shared XRDP module. SonicDE's input,
lock entries and `linux/system/desktop/sonicde.nix` remain for future use,
but no host imports the module. Keeping the input can fetch sources during
flake operations; it does not add SonicDE packages to rog's system build.
The regression check now verifies MATE on rog and thinkcentre, with SonicDE
disabled. The following notes describe the former SonicDE configuration,
not the currently enabled desktop. To retry it, use commit `ce59744d` as a
reference for the rog-only imports, XRDP command and Home Manager Qt/KConfig
settings; do not blindly revert unrelated changes made since that commit.

## Previous SonicDE configuration

Only `rog` uses SonicDE, through XRDP. Local SDDM and LightDM remain disabled.
`thinkcentre` retains MATE and its existing XRDP session; the shared MATE modules
are not removed. No existing user settings are deleted.

The input pins [sonic-flake 6.6.5](https://github.com/sonicde-nixos/sonic-flake/tree/d779fe69d144f9ef270887e71a16cae4cab7a741),
the release targeting NixOS 26.05. Newer upstream releases require newer nixpkgs.
SonicDE's NixOS packaging is still experimental. Its session is named
`plasmax11` and starts with `startplasma-x11`, not `startsonic`.
The optional wallpaper package is excluded because this release points it at
the workspace-addons source instead of wallpaper sources.

## Declarative settings

SonicDE inherits KDE's **KConfig**, not dconf. Use the existing
`qt.kde.settings` block in `hosts/rog/home/default.nix` for file/group/key values.
Home Manager writes selected keys using `kwriteconfig6`, retaining unspecified
keys and GUI-editable files. No plasma-manager input is necessary. The empty
block deliberately imposes no preferences. Verify individual keys against the
pinned SonicDE version before adding them; `null` deletes a key.

GTK applications still use the shared GTK/dconf configuration. The shared
Home Manager Qt theme override is disabled only on rog so SonicDE controls its
own appearance. MATE settings on disk remain available for rollback.

## Verification and rollout

Run the configuration regression check without staging new files:

```console
nix eval --impure --json --expr 'import ./tests/rog-sonicde.nix { flake = builtins.getFlake ("path:" + toString ./.); }'
nix eval path:.#nixosConfigurations.rog.config.system.build.toplevel.drvPath --no-write-lock-file
nix eval path:.#homeConfigurations.rog.activationPackage.drvPath --no-write-lock-file
nix flake check path:. --no-build --no-write-lock-file
nix build path:.#nixosConfigurations.rog.config.system.build.toplevel --dry-run --no-write-lock-file
```

Evaluation and a dry run do not prove that SonicDE builds or that XRDP works.
Inspect the build forecast before a full build; upstream packages may require
local compilation. Activation and service restarts require separate approval.
Keep the previous NixOS boot generation and an SSH connection for recovery.

After an authorized build and deployment, test remote login, windows/compositing,
clipboard, audio, disconnect/reconnect, and logout. SonicDE uses normal logout,
not the old MATE auto-relaunch/process-cleanup wrapper. An existing user
`~/startwm.sh` can override NixOS's XRDP command; inspect it if MATE still starts,
but do not remove it without permission.

For rollback, select the previous boot generation or explicitly authorize a
system rollback. To revert declaratively, restore rog's shared XRDP import,
`my.desktop.suite = "mate"`, and its two MATE Home Manager imports; remove the
rog SonicDE import, direct XRDP command and Qt override. Do not delete KConfig
or dconf data, and preserve unrelated edits in the same files.
