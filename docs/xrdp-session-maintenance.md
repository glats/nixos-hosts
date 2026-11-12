# Preserve XRDP sessions during NixOS activation

Keep the nixpkgs `xrdp-sesman.restartIfChanged = false` policy. Do not force
automatic restarts or add activation hooks to refresh sesman. Restarting it can
leave an existing desktop running without its session manager connection; a new
login can then conflict with the existing `org.gnome.SessionManager` bus owner.

This protects sesman during `switch` and `test` activations. It does not prevent
the separate `xrdp` transport service from restarting when its unit changes, and
does not guarantee uninterrupted RDP transport or repair already orphaned sessions.

## Updates can remain pending in the running session manager

Sesman reads its configuration at startup. After an XRDP package or configuration
update, it may keep the previous executable, configuration and Xorg module paths
until an explicitly scheduled restart. Existing Xorg processes also retain their
original module paths. An activated generation is not proof that a running session
uses the new graphics stack.

Read-only inspection:

```console
systemctl show xrdp-sesman.service -p MainPID -p ExecStart
pgrep -af '[/]bin/xrdp-sesman'
pgrep -a Xorg
```

Compare the running processes' executable and configuration paths with the desired
unit. Do not restart sesman just to make those paths agree while desktops are in use.

## Deliberate maintenance only

1. Announce that refreshing XRDP may disconnect sessions and require a fresh login.
   Obtain explicit approval for a maintenance window and keep an independent SSH
   connection available.
2. Have every affected user save work and explicitly log out of their desktop.
   Disconnecting the RDP client is not a logout. Confirm no desktops or applications
   need to be preserved; if any remain, postpone the restart. Do not kill them or
   clear their session bus as a workaround.
3. Only after those checks, an operator may explicitly restart sesman from the
   independent SSH connection. This is a separate maintenance action, never part of
   an automatic NixOS activation.
4. Reconnect and verify the new session's Xorg module paths and graphics log.

## Configuration regression check

```console
nix eval --raw .#checks.x86_64-linux.xrdp-sesman-no-restart.drvPath
```

This checks the effective policy and generated `X-RestartIfChanged=false` unit flag
for `rog`, `thinkcentre` and `samsung`. It does not activate a configuration, restart
a service, or test live reconnection behavior.
